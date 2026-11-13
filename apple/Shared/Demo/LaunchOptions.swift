import Foundation

/// Debug-only launch arguments that show every screen without signing in:
/// `-DemoData` loads the invented timetable, `-Landing` shows the first
/// screen, `-DemoPage <days from today>` opens another day, `-DemoAccount`
/// opens the account sheet, `-WidgetGallery` renders the widgets in the app.
/// In release builds every option is off.
enum LaunchOptions {
    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    static let usesDemoData = arguments.contains("-DemoData")
    static let showsLanding = arguments.contains("-Landing")
    static let opensAccount = arguments.contains("-DemoAccount")
    static let showsWidgetGallery = arguments.contains("-WidgetGallery")
    static let pageOffset: Int? = arguments.firstIndex(of: "-DemoPage")
        .flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil }
    #else
    static let usesDemoData = false
    static let showsLanding = false
    static let opensAccount = false
    static let showsWidgetGallery = false
    static let pageOffset: Int? = nil
    #endif
}
