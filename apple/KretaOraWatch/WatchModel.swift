import Foundation
import KretaKit
import Observation
import os
import WatchConnectivity
import WidgetKit

/// The watch side of the link. It stores what the phone sends and redraws the
/// app and the complications from it. It holds no KRÉTA token.
@MainActor
@Observable
final class WatchModel: NSObject {
    private(set) var snapshot: TimetableSnapshot?

    @ObservationIgnored private let store = AppEnvironment.snapshots
    @ObservationIgnored private let logger = Logger(subsystem: "hu.kretaora", category: "watch")

    var schedule: Schedule? { snapshot?.schedule }

    func start() {
        snapshot = store.load()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Applies a message from the phone: a fresh timetable or a sign-out.
    private func apply(_ payload: [String: Any]) {
        do {
            if payload[WatchPayload.signedOut] as? Bool == true {
                try store.clear()
                snapshot = nil
            } else if let data = payload[WatchPayload.snapshot] as? Data {
                let received = try JSONDecoder().decode(TimetableSnapshot.self, from: data)
                // Messages can arrive out of order; never go back in time.
                if let current = snapshot, current.syncedAt > received.syncedAt { return }
                try store.save(received)
                snapshot = received
            } else {
                return
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            logger.error("Could not apply the timetable from the phone: \(error.localizedDescription)")
        }
    }
}

extension WatchModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Whatever the phone sent while the watch app was not running.
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    /// Complication pushes arrive here and wake the app in the background.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.apply(userInfo) }
    }
}
