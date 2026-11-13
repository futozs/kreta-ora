import Foundation

/// The school day as the live surface sees it at one moment: what to show,
/// and what it counts down to. It exists from an hour before the first
/// lesson until the last one ends.
public struct LiveDay: Equatable, Sendable {
    /// Shown this long before the day's first lesson, the same window in which
    /// the widget starts counting down.
    public static let lead: TimeInterval = 60 * 60

    /// Every lesson of the day, cancelled ones included.
    public let lessons: [Lesson]
    public let focus: Lesson
    public let isRunning: Bool
    public let target: Date

    public var start: Date { lessons.first?.start ?? focus.start }
    public var end: Date { lessons.last?.end ?? focus.end }

    public init?(schedule: Schedule, now: Date) {
        let lessons = schedule.lessons(on: now)
        let active = lessons.filter(\.isActive)
        guard let first = active.first, let last = active.last else { return nil }
        guard now >= first.start.addingTimeInterval(-Self.lead), now < last.end else { return nil }
        self.lessons = lessons
        if let running = active.first(where: { $0.contains(now) }) {
            focus = running
            isRunning = true
            target = running.end
        } else if let next = active.first(where: { $0.start > now }) {
            focus = next
            isRunning = false
            target = next.start
        } else {
            return nil
        }
    }

    /// When the live surface of the day containing `day` should appear and go.
    public static func window(_ schedule: Schedule, on day: Date) -> ClosedRange<Date>? {
        let active = schedule.lessons(on: day).filter(\.isActive)
        guard let first = active.first, let last = active.last else { return nil }
        return first.start.addingTimeInterval(-lead)...last.end
    }
}
