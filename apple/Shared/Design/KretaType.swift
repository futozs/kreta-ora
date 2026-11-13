import SwiftUI

/// The type scale, point for point the Android one.
enum KretaType {
    /// The question on the first screen.
    static let display = KretaTextStyle(
        family: .bricolageDisplay, weight: 800, size: 50, lineHeight: 50, tracking: -1.4
    )

    /// The day name above the timetable.
    static let dayTitle = KretaTextStyle(
        family: .bricolageDisplay, weight: 800, size: 42, lineHeight: 44, tracking: -1.1
    )

    /// The lesson that is running or comes next.
    static let blockTitleLarge = KretaTextStyle(
        family: .bricolageDisplay, weight: 800, size: 27, lineHeight: 29, tracking: -0.5
    )

    static let blockTitle = KretaTextStyle(
        family: .bricolageText, weight: 700, size: 19, lineHeight: 22, tracking: -0.2
    )

    /// "3." in front of a lesson.
    static let number = KretaTextStyle(family: .bricolageText, weight: 800, size: 24, lineHeight: 26)

    static let headline = KretaTextStyle(
        family: .bricolageText, weight: 700, size: 24, lineHeight: 28, tracking: -0.3
    )

    /// The live countdown inside the running lesson.
    static let countdown = KretaTextStyle(
        family: .hanken, weight: 800, size: 46, lineHeight: 46, tracking: -1.2, isTabular: true
    )

    static let time = KretaTextStyle(family: .hanken, weight: 700, size: 15, lineHeight: 19, isTabular: true)

    // The quiet text is set at regular weight, so it stays apart from the bold
    // text even when the "bold text" setting adds weight to everything.
    static let body = KretaTextStyle(family: .hanken, weight: 400, size: 16, lineHeight: 23)

    static let small = KretaTextStyle(family: .hanken, weight: 400, size: 13.5, lineHeight: 18)

    static let strong = KretaTextStyle(family: .hanken, weight: 700, size: 13.5, lineHeight: 18)

    static let button = KretaTextStyle(family: .hanken, weight: 800, size: 16, lineHeight: 20)
}
