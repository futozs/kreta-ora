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
    static let shared = WatchModel()

    private(set) var snapshot: TimetableSnapshot?

    @ObservationIgnored private let store = AppEnvironment.snapshots
    @ObservationIgnored private let logger = Logger(subsystem: "hu.kretaora", category: "watch")

    var schedule: Schedule? { snapshot?.schedule }

    /// Call once at launch. The phone can wake the watch app in the
    /// background to refresh a complication, and no view exists then, so the
    /// link has to be up before any view is built.
    func start() {
        #if DEBUG
        if LaunchOptions.usesDemoData {
            snapshot = DemoTimetable.snapshot()
            return
        }
        #endif
        snapshot = store.load()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// A message from the phone, read out of its untyped dictionary.
    fileprivate enum PhoneMessage: Sendable {
        case signedOut
        case snapshot(Data)

        init?(_ payload: [String: Any]) {
            if payload[WatchPayload.signedOut] as? Bool == true {
                self = .signedOut
            } else if let data = payload[WatchPayload.snapshot] as? Data {
                self = .snapshot(data)
            } else {
                return nil
            }
        }
    }

    /// Applies a message from the phone: a fresh timetable or a sign-out.
    fileprivate func apply(_ message: PhoneMessage) {
        do {
            switch message {
            case .signedOut:
                try store.clear()
                snapshot = nil
            case .snapshot(let data):
                let received = try JSONDecoder().decode(TimetableSnapshot.self, from: data)
                // Messages can arrive out of order; never go back in time.
                if let current = snapshot, current.syncedAt > received.syncedAt { return }
                try store.save(received)
                snapshot = received
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
        guard let message = PhoneMessage(session.receivedApplicationContext) else { return }
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let message = PhoneMessage(applicationContext) else { return }
        Task { @MainActor in self.apply(message) }
    }

    /// Complication pushes arrive here and wake the app in the background.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let message = PhoneMessage(userInfo) else { return }
        Task { @MainActor in self.apply(message) }
    }
}
