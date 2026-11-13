import Foundation
import KretaKit

/// The live lesson's switch and its one-time offer, shared by the app and the
/// widget extension through the App Group.
enum LivePreferences {
    private static let enabledKey = "liveLesson.enabled"
    private static let offerDismissedKey = "liveLesson.offerDismissed"
    private static let hiddenOnKey = "liveLesson.hiddenOn"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppEnvironment.appGroup) ?? .standard
    }

    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set {
            defaults.set(newValue, forKey: enabledKey)
            // Answering the switch also answers the offer.
            defaults.set(true, forKey: offerDismissedKey)
        }
    }

    /// Whether to suggest turning it on: once, until the user answers.
    static var isOfferDue: Bool {
        !isEnabled && !defaults.bool(forKey: offerDismissedKey)
    }

    static func dismissOffer() {
        defaults.set(true, forKey: offerDismissedKey)
    }

    /// "Elrejtés mára", or the user swiped it away: not again today.
    static func hide(on day: Date) {
        defaults.set(KretaDate.dayString(day), forKey: hiddenOnKey)
    }

    static func isHidden(on day: Date) -> Bool {
        defaults.string(forKey: hiddenOnKey) == KretaDate.dayString(day)
    }
}
