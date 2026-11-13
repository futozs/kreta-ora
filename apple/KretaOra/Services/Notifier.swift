import Foundation
import KretaKit
import os
import UserNotifications

/// Local notifications for timetable changes.
enum Notifier {
    private static let logger = Logger(subsystem: "hu.kretaora", category: "notifications")
    private static let sessionExpiredID = "session-expired"

    /// Asks once; later calls return the stored answer without a prompt.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// One notification per change, or a single summary when a sync changed
    /// many lessons at once.
    static func post(_ changes: [TimetableChange], now: Date) async {
        guard !changes.isEmpty else { return }
        let formatter = ChangeFormatter(now: now)

        if changes.count > ChangeFormatter.individualLimit {
            let summary = formatter.summary(for: changes)
            await add(id: "summary-\(Int(now.timeIntervalSince1970))", title: summary.title, body: summary.body)
            return
        }
        for change in changes {
            // The same change to the same lesson replaces its earlier banner.
            await add(
                id: "\(change.id)@\(Int(change.lesson.start.timeIntervalSince1970))",
                title: formatter.title(for: change),
                body: formatter.body(for: change)
            )
        }
    }

    /// Background refresh cannot continue without a new login, so say so once.
    static func postSessionExpired() async {
        await add(
            id: sessionExpiredID,
            title: "Jelentkezz be újra",
            body: "A KRÉTA munkamenet lejárt, addig nem tudom figyelni az órarendváltozásokat."
        )
    }

    static func clearSessionExpired() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [sessionExpiredID])
    }

    private static func add(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "timetable"
        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: id, content: content, trigger: nil)
            )
        } catch {
            logger.error("Could not post notification: \(error.localizedDescription)")
        }
    }
}

/// Shows banners even while the app is open.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
