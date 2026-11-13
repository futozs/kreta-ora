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

    /// Fetches the timetable, then updates widgets, the watch, and posts a
    /// notification for every change.
    @discardableResult
    func sync() async throws -> SyncResult {
        do {
            let result = try await engine.sync()
            await publish(result.snapshot)
            await Notifier.post(result.changes, now: result.snapshot.syncedAt)
            logger.info("Sync finished with \(result.changes.count) change(s)")
            return result
        } catch KretaError.sessionExpired {
            await Notifier.postSessionExpired()
            throw KretaError.sessionExpired
        }
    }

    /// Stores a fresh session after login.
    func signIn(_ session: Session) throws {
        try sessions.save(session)
    }

    func signOut() async throws {
        try await engine.signOut()
        await publish(nil)
    }

    private func publish(_ snapshot: TimetableSnapshot?) async {
        WidgetCenter.shared.reloadAllTimelines()
        await WatchLink.shared.send(snapshot)
    }
}
