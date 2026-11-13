#if os(iOS)
import ActivityKit
import AppIntents
import Foundation

/// "Elrejtés mára" on the lock screen: ends the live lesson for the rest of the day.
struct HideLiveLessonIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Élő óra elrejtése mára"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        LivePreferences.hide(on: Date())
        for activity in Activity<LiveLessonAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
#endif
