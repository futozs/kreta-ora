import Foundation
import KretaKit

/// Values every target (app, widgets, watch app, complications) agrees on.
enum AppEnvironment {
    /// Set per target in Info.plist from the `KRETA_APP_GROUP` build setting.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "KretaAppGroup") as? String
        ?? "group.hu.kretaora.app"

    /// The timetable shared between an app and its widget extension.
    static let snapshots: SnapshotStore = {
        if let shared = SnapshotStore.appGroup(appGroup) { return shared }
        // Without the App Group the app still works; only the widgets stay empty.
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return SnapshotStore(directory: fallback)
    }()
}

enum WidgetKind {
    static let nextLesson = "NextLessonWidget"
    static let dayStart = "DayStartWidget"
    static let liveLesson = "LiveLessonActivity"
}

/// Keys of the dictionary the phone sends to the watch.
enum WatchPayload {
    static let snapshot = "snapshot"
    static let signedOut = "signedOut"
    static let sentAt = "sentAt"
    /// How many days of timetable the watch receives.
    static let days = 8
}
