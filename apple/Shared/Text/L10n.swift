import Foundation

/// Every user-facing text, verbatim from the Android app's strings.xml.
/// Hungarian keeps a noun singular after a number, so counted texts need no plural rules.
enum L10n {
    static let appName = "Kréta Óra"

    // Landing and login
    static let landingHeadline = "Mi a következő órád?"
    static let landingBody = "Lapozható órarend, widget a kezdőképernyőre, és értesítés, ha elmarad egy óra vagy helyettesítés van."
    static let landingButton = "Belépés KRÉTA-fiókkal"
    static let landingPrivacy = "A jelszavadat a KRÉTA saját oldalán adod meg, az alkalmazás nem látja. Nem hivatalos alkalmazás."
    static let loginWebTitle = "KRÉTA bejelentkezés"
    static let loginWebHost = "idp.e-kreta.hu"
    static let loginCancel = "Mégse"

    // Timetable
    static let backToToday = "Vissza mára"
    static let refresh = "Frissítés"
    static let signOut = "Kijelentkezés"
    static let signInAgain = "Bejelentkezés újra"
    static func syncedAt(_ day: String, _ time: String) -> String { "Frissítve: \(day), \(time)" }
    static let accountNote = "Nem hivatalos alkalmazás. Az adataid a telefonodon maradnak, az app csak a KRÉTA szervereivel beszél."
    static let account = "Fiók"

    // Lessons
    static func lessonNumber(_ index: Int) -> String { "\(index)." }
    static let lessonCancelled = "Elmarad"
    static func substitute(_ name: String) -> String { "helyettesít: \(name)" }
    static let test = "számonkérés"
    static let left = "van hátra"
    static func minutesLeft(_ minutes: Int) -> String { "még \(minutes) perc" }
    static func startsInMinutes(_ minutes: Int) -> String { "\(minutes) perc múlva kezdődik" }
    static func startsInHours(_ hours: Int) -> String { "\(hours) óra múlva kezdődik" }
    static func startsInHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        "\(hours) óra \(minutes) perc múlva kezdődik"
    }
    static let nothingLeft = "A következő hetekre nincs óra az órarendben."

    // Days
    static let today = "Ma"
    static let tomorrow = "Holnap"
    static let yesterday = "Tegnap"
    static func cancelledCount(_ count: Int) -> String { "\(count) óra elmarad" }
    static func substitutedCount(_ count: Int) -> String { "\(count) helyettesítés" }
    static func gap(_ minutes: Int) -> String { "\(minutes) perc szünet" }
    static let emptyTitle = "Nincs órád."
    static func emptyNext(_ weekday: String, _ time: String, _ name: String) -> String {
        "Legközelebb \(weekday), \(time): \(name)."
    }
    static let emptyBody = "A következő hetekre sincs óra az órarendben."

    // Errors
    static let errorOffline = "Nincs kapcsolat a KRÉTA szerverével. A legutóbb mentett órarendet látod."
    static let errorSessionExpired = "A KRÉTA munkamenet lejárt. A legutóbb mentett órarendet látod."
    static let errorUnexpected = "Váratlan hiba történt. Próbáld újra."

    // Notifications
    static let notificationSessionTitle = "Jelentkezz be újra"
    static let notificationSessionBody = "A KRÉTA munkamenet lejárt, ezért az órarend figyelése szünetel."

    // Widgets
    static let widgetNextName = "Következő óra"
    static let widgetNextDescription = "A most tartó vagy a következő órád, a tantárgy színében."
    static let widgetDayStartName = "Mikor kezdünk?"
    static let widgetDayStartDescription = "A következő tanítási nap első órája és a nap hossza."
    static let widgetSignedOut = "Jelentkezz be az alkalmazásban."
    static let widgetStartsIn = "múlva kezdődik"
    static let widgetToday = "ma"
    static let widgetTomorrow = "holnap"

    // Live lesson
    static func liveNextTitle(_ name: String) -> String { "Következik: \(name)" }
    static let liveHideToday = "Elrejtés mára"
    static let liveToggleTitle = "Élő óra a zárolási képernyőn"
    static let liveToggleBody = "Tanítási időben egy élő tevékenység mutatja a futó órát és a hátralévő időt, a nap óráival egy színes sávban."
    static let liveOfferBody = "Kérsz élő visszaszámlálást a zárolási képernyőre és a Dynamic Islandre tanítási időben? Az első óra előtt egy órával jelenik meg, az utolsó után eltűnik."
    static let liveOfferAllow = "Bekapcsolás"
    static let later = "Most nem"
    static let liveDayOver = "Vége a napnak"
    static func liveStartAlertTitle(_ time: String) -> String { "\(time)-kor kezdődik a nap" }

    // Watch
    static let watchSignedOut = "Jelentkezz be a telefonon."
    static let watchSignedOutBody = "Az órarendet a Kréta Óra küldi át az iPhone-odról."
}
