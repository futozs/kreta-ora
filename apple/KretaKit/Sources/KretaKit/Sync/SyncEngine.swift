import Foundation

public struct SyncResult: Sendable, Equatable {
    public let snapshot: TimetableSnapshot
    /// What changed since the previous sync. Empty on the first one.
    public let changes: [TimetableChange]
}

/// Fetches the timetable, keeps the session alive, and reports what changed.
///
/// Every trigger goes through `sync()`: opening the app, pull to refresh,
/// background refresh, and later a silent push.
///
/// Operations are queued and run strictly one after another. An actor alone
/// would not guarantee that, because it lets a second call in whenever the
/// first one awaits the network. Without the queue two syncs could spend the
/// same refresh token, and a sync in flight could write a session back after
/// the user signed out.
public actor SyncEngine {
    private let api: KretaAPI
    private let auth: AuthService
    private let sessions: any SessionStore
    private let snapshots: SnapshotStore
    private let clock: @Sendable () -> Date
    /// Survives a failed keychain write: a rotated refresh token must not be
    /// lost, because the old one no longer works.
    private var rotated: Session?
    /// Finishes when the most recently queued operation has finished.
    private var queueTail: Task<Void, Never>?

    public init(
        api: KretaAPI = KretaAPI(),
        sessions: any SessionStore,
        snapshots: SnapshotStore,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.api = api
        self.auth = AuthService(api: api)
        self.sessions = sessions
        self.snapshots = snapshots
        self.clock = clock
    }

    /// Syncs once. `afterwards` runs before the next queued operation starts,
    /// so whatever it publishes cannot be overtaken by a later sign-out.
    @discardableResult
    public func sync(
        afterwards: @escaping @Sendable (SyncResult) async -> Void = { _ in }
    ) async throws -> SyncResult {
        try await enqueue {
            let result = try await self.performSync()
            await afterwards(result)
            return result
        }
    }

    /// Forgets the session and the cached timetable. `afterwards` runs even
    /// when part of the clean-up failed, so other surfaces are always told.
    public func signOut(
        afterwards: @escaping @Sendable () async -> Void = {}
    ) async throws {
        try await enqueue {
            do {
                try await self.performSignOut()
            } catch {
                await afterwards()
                throw error
            }
            await afterwards()
        }
    }

    // MARK: Queue

    private func enqueue<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let previous = queueTail
        let task = Task {
            await previous?.value
            return try await operation()
        }
        queueTail = Task { _ = try? await task.value }
        return try await task.value
    }

    // MARK: Operations

    private func performSync() async throws -> SyncResult {
        let now = clock()
        guard let stored = try rotated ?? sessions.load() else { throw KretaError.notLoggedIn }
        let session = stored.tokens.isFresh(at: now) ? stored : try await renew(stored)

        let range = Schedule.syncRange(containing: now)
        let lessons: [Lesson]
        do {
            lessons = try await fetch(session, range)
        } catch KretaError.authentication {
            // The token was revoked early. Rotate once and retry once.
            lessons = try await fetch(try await renew(session), range)
        }

        let previous = snapshots.load()
        if let previous, isSuspiciouslyEmpty(lessons, comparedTo: previous, account: session.account, now: now) {
            return SyncResult(snapshot: previous, changes: [])
        }

        let snapshot = TimetableSnapshot(
            accountID: session.account.id,
            lessons: lessons,
            rangeStart: range.from,
            rangeEnd: KretaDate.addingDays(1, to: range.to),
            syncedAt: now
        )
        let changes = TimetableDiff.changes(from: previous, to: snapshot, now: now)
        try snapshots.save(snapshot)
        return SyncResult(snapshot: snapshot, changes: changes)
    }

    /// A response without a single lesson, while lessons we already know are
    /// still ahead, is far more likely a server hiccup than a wiped timetable.
    /// Believing it would announce every lesson as removed now and as new on
    /// the next good sync. The known timetable is kept instead; once its
    /// lessons have passed, an empty answer is accepted.
    private func isSuspiciouslyEmpty(
        _ lessons: [Lesson],
        comparedTo previous: TimetableSnapshot,
        account: Account,
        now: Date
    ) -> Bool {
        previous.accountID == account.id
            && !lessons.contains { $0.kind == .lesson }
            && previous.lessons.contains { $0.kind == .lesson && $0.end > now }
    }

    private func performSignOut() throws {
        rotated = nil
        // Try both, so a keychain failure cannot leave the timetable behind.
        let sessionOutcome = Result { try sessions.clear() }
        let snapshotOutcome = Result { try snapshots.clear() }
        try sessionOutcome.get()
        try snapshotOutcome.get()
    }

    private func renew(_ session: Session) async throws -> Session {
        let renewed = try await auth.refresh(session, now: clock())
        rotated = renewed
        try sessions.save(renewed)
        rotated = nil
        return renewed
    }

    private func fetch(_ session: Session, _ range: (from: Date, to: Date)) async throws -> [Lesson] {
        try await api.timetable(
            institution: session.account.institutionCode,
            accessToken: session.tokens.accessToken,
            from: range.from,
            to: range.to
        )
    }
}
