import Foundation

public struct SyncResult: Sendable, Equatable {
    public let snapshot: TimetableSnapshot
    /// What changed since the previous sync. Empty on the first one.
    public let changes: [TimetableChange]
}

/// Fetches the timetable, keeps the session alive, and reports what changed.
///
/// Every trigger goes through `sync()`: opening the app, pull to refresh,
/// background refresh, and later a silent push. The actor makes concurrent
/// triggers run one after another, so a rotated refresh token is never used
/// twice.
public actor SyncEngine {
    private let api: KretaAPI
    private let auth: AuthService
    private let sessions: any SessionStore
    private let snapshots: SnapshotStore
    private let clock: @Sendable () -> Date
    /// Survives a failed keychain write: a rotated refresh token must not be
    /// lost, because the old one no longer works.
    private var rotated: Session?

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

    public func sync() async throws -> SyncResult {
        let now = clock()
        guard let stored = try currentSession() else { throw KretaError.notLoggedIn }
        let session = stored.tokens.isFresh(at: now) ? stored : try await renew(stored)

        let range = Schedule.syncRange(containing: now)
        let lessons: [Lesson]
        do {
            lessons = try await fetch(session, range)
        } catch KretaError.authentication {
            // The token was revoked early. Rotate once and retry once.
            lessons = try await fetch(try await renew(session), range)
        }

        let snapshot = TimetableSnapshot(
            accountID: session.account.id,
            lessons: lessons,
            rangeStart: range.from,
            rangeEnd: KretaDate.addingDays(1, to: range.to),
            syncedAt: now
        )
        let changes = TimetableDiff.changes(from: snapshots.load(), to: snapshot, now: now)
        try snapshots.save(snapshot)
        return SyncResult(snapshot: snapshot, changes: changes)
    }

    /// Forgets the session and the cached timetable.
    public func signOut() throws {
        rotated = nil
        try sessions.clear()
        try snapshots.clear()
    }

    private func currentSession() throws -> Session? {
        try rotated ?? sessions.load()
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
