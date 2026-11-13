import Foundation
import KretaKit
import os
import WatchConnectivity

/// Sends the timetable to the paired watch. The watch never holds a KRÉTA
/// token: it only renders what the phone hands over.
@MainActor
final class WatchLink: NSObject {
    static let shared = WatchLink()

    private let logger = Logger(subsystem: "hu.kretaora", category: "watch")
    /// Held until the session finishes activating.
    private var pending: [String: Any]?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Pass nil after signing out, so the watch clears its copy.
    func send(_ snapshot: TimetableSnapshot?) {
        guard WCSession.isSupported() else { return }
        guard let payload = payload(for: snapshot) else { return }
        guard WCSession.default.activationState == .activated else {
            pending = payload
            return
        }
        deliver(payload)
    }

    private func payload(for snapshot: TimetableSnapshot?) -> [String: Any]? {
        let now = Date()
        guard let snapshot else {
            return [WatchPayload.signedOut: true, WatchPayload.sentAt: now]
        }
        do {
            let data = try JSONEncoder().encode(snapshot.window(from: now, days: WatchPayload.days))
            return [WatchPayload.snapshot: data, WatchPayload.sentAt: now]
        } catch {
            logger.error("Could not encode the timetable for the watch: \(error.localizedDescription)")
            return nil
        }
    }

    private func deliver(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.isPaired, session.isWatchAppInstalled else { return }
        do {
            // Latest state wins; the watch reads it the next time it wakes.
            try session.updateApplicationContext(payload)
        } catch {
            logger.error("Could not update the watch: \(error.localizedDescription)")
        }
        // Wakes the watch to redraw the complication now, within a daily budget.
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(payload)
        }
    }

    private func flushPending() {
        guard let payload = pending, WCSession.default.activationState == .activated else { return }
        pending = nil
        deliver(payload)
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.flushPending() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Happens when the user switches to another watch.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
