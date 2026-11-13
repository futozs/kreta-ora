import Foundation
import KretaKit
import os
import WidgetKit

/// The single path from "something asked for a sync" to "every surface is up
/// to date": foreground refresh, background refresh, and later a silent push
/// all call `sync()`.
final class SyncCoordinator: Sendable {
    static let shared = SyncCoordinator()

    let sessions: KeychainSessionStore
    let snapshots: SnapshotStore
    private let engine: SyncEngine
    private let logger = Logger(subsystem: "hu.kretaora", category: "sync")

    private init() {
        sessions = KeychainSessionStore(service: Bundle.main.bundleIdentifier ?? "hu.kretaora.app")
        snapshots = AppEnvironment.snapshots
        engine = SyncEngine(sessions: sessions, snapshots: snapshots)
    }

    /// True once the refresh token has been rejected. Until the next login
    /// there is nothing a background run could do, so they stop, and the
    /// user is told once instead of on every attempt.
    private(set) var needsLogin: Bool {
        get { UserDefaults.standard.bool(forKey: Self.needsLoginKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.needsLoginKey) }
    }

    private static let needsLoginKey = "needsLogin"

    /// Fetches the timetable, then updates widgets, the watch, and posts a
    /// notification for every change. Publishing happens inside the engine's
    /// queue, so a sign-out that follows cannot be overtaken by it.
    @discardableResult
    func sync() async throws -> SyncResult {
        do {
            let result = try await engine.sync { result in
                await self.publish(result.snapshot)
                await Notifier.post(result.changes, now: result.snapshot.syncedAt)
            }
            logger.info("Sync finished with \(result.changes.count) change(s)")
            return result
        } catch KretaError.sessionExpired {
            if !needsLogin {
                needsLogin = true
                await Notifier.postSessionExpired()
            }
            throw KretaError.sessionExpired
        }
    }

    /// Stores a fresh session after login.
    func signIn(_ session: Session) throws {
        try sessions.save(session)
        needsLogin = false
        Notifier.clearSessionExpired()
    }

    /// Widgets and the watch are cleared even if part of the clean-up fails.
    func signOut() async throws {
        needsLogin = false
        try await engine.signOut {
            await self.publish(nil)
        }
    }

    private func publish(_ snapshot: TimetableSnapshot?) async {
        WidgetCenter.shared.reloadAllTimelines()
        await WatchLink.shared.send(snapshot)
        LiveLessonController.shared.update(snapshot: snapshot)
    }
}
