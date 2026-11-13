import Foundation

/// The lesson a "next lesson" surface shows, and how it counts.
public struct NextLessonModel: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// Being held: counts down to the bell.
        case running
        /// Starts today within the countdown window: counts down to the start.
        case soon
        /// Further away: shows its start time and day.
        case later
    }

    /// Closer than this, the next lesson counts down; further away it shows its start time.
    public static let countdownWindow: TimeInterval = 60 * 60

    public let lesson: Lesson
    public let phase: Phase
    /// The rest of that day after `lesson`. Cancelled lessons stay in, so a free period is no surprise.
    public let following: [Lesson]

    public init?(schedule: Schedule, now: Date) {
        let summary = StatusSummary(schedule: schedule, now: now)
        guard let lesson = summary.lesson else { return nil }
        self.lesson = lesson
        if summary.isInLesson {
            phase = .running
        } else if KretaDate.isSameDay(lesson.start, now),
                  lesson.start.timeIntervalSince(now) <= Self.countdownWindow {
            phase = .soon
        } else {
            phase = .later
        }
        following = schedule.lessons(on: lesson.start).filter { $0.start >= lesson.end }
    }

    /// The moment the countdown runs to, if it counts at all.
    public var countdownTarget: Date? {
        switch phase {
        case .running: lesson.end
        case .soon: lesson.start
        case .later: nil
        }
    }

    /// Extra redraw moments a widget needs on top of lesson boundaries: when
    /// each lesson enters the countdown window.
    public static func windowOpenings(_ schedule: Schedule, from now: Date, horizon: TimeInterval) -> [Date] {
        let end = now.addingTimeInterval(horizon)
        return schedule.activeLessons
            .map { $0.start.addingTimeInterval(-countdownWindow) }
            .filter { $0 > now && $0 <= end }
    }
}
