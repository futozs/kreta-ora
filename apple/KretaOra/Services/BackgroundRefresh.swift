import BackgroundTasks
import Foundation
import os

/// Keeps the timetable fresh while the app is closed.
///
/// iOS decides when a background refresh actually runs, based on how the
/// phone is used. It is usually several times a day, never on a fixed clock.
/// A silent push from a server could trigger the same `run()` sooner.
enum BackgroundRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let taskID = "\(Bundle.main.bundleIdentifier ?? "hu.kretaora.app").refresh"

    private static let earliestInterval: TimeInterval = 15 * 60
    private static let logger = Logger(subsystem: "hu.kretaora", category: "background")

    static func schedule() {
        // A rejected session cannot recover in the background.
        guard !SyncCoordinator.shared.needsLogin else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected in the simulator and when Background App Refresh is off.
            logger.notice("Could not schedule background refresh: \(error.localizedDescription)")
        }
    }

    static func run() async {
        // Queue the next one first, so a failure here does not break the chain.
        schedule()
        do {
            try await SyncCoordinator.shared.sync()
        } catch {
            logger.error("Background sync failed: \(error.localizedDescription)")
        }
    }
}
