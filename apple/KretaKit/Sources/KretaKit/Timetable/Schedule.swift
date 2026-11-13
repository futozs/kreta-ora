import Foundation

/// What a student wants to know right now.
public enum ScheduleStatus: Equatable, Sendable {
    /// A lesson is running. `next` is the following lesson today, if any.
    case inLesson(current: Lesson, next: Lesson?)
    /// Between two lessons today.
    case breakTime(next: Lesson)
    /// Today's first lesson has not started yet.
    case beforeFirst(first: Lesson)
    /// Nothing left today. `nextFirst` opens the next school day.
    case dayOver(nextFirst: Lesson?)
}

/// Read-only questions over a list of lessons. All day math is school time.
public struct Schedule: Sendable, Equatable {
    /// Lessons and events sorted by start.
    public let entries: [Lesson]

    public init(lessons: [Lesson]) {
        entries = lessons.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    /// Real lessons, including cancelled ones.
    public var lessons: [Lesson] { entries.filter { $0.kind == .lesson } }

    /// Lessons that actually take place.
    public var activeLessons: [Lesson] { entries.filter(\.isActive) }

    /// Every lesson of the day, cancelled ones included, so the UI can cross
    /// them out.
    public func lessons(on day: Date) -> [Lesson] {
        lessons.filter { KretaDate.isSameDay($0.start, day) }
    }

    /// School-year events of the day, for example a holiday.
    public func events(on day: Date) -> [Lesson] {
        entries.filter { $0.kind == .event && KretaDate.isSameDay($0.start, day) }
    }

    public func firstLesson(on day: Date) -> Lesson? {
        activeLessons.first { KretaDate.isSameDay($0.start, day) }
    }

    public func lastLesson(on day: Date) -> Lesson? {
        activeLessons.last { KretaDate.isSameDay($0.start, day) }
    }

    public func currentLesson(at now: Date) -> Lesson? {
        activeLessons.first { $0.contains(now) }
    }

    /// The next lesson that has not started yet, today or later.
    public func nextLesson(after now: Date) -> Lesson? {
        activeLessons.first { $0.start > now }
    }

    /// The first lesson of the next day that has any, strictly after `day`.
    public func firstLessonOfNextSchoolDay(after day: Date) -> Lesson? {
        let tomorrow = KretaDate.addingDays(1, to: KretaDate.startOfDay(day))
        return activeLessons.first { $0.start >= tomorrow }
    }

    public func status(at now: Date) -> ScheduleStatus {
        let today = activeLessons.filter { KretaDate.isSameDay($0.start, now) }
        if let current = today.first(where: { $0.contains(now) }) {
            return .inLesson(current: current, next: today.first { $0.start >= current.end })
        }
        guard let next = today.first(where: { $0.start > now }) else {
            return .dayOver(nextFirst: firstLessonOfNextSchoolDay(after: now))
        }
        return today.contains { $0.end <= now } ? .breakTime(next: next) : .beforeFirst(first: next)
    }

    /// Moments when the answer of `status(at:)` or a day label changes, so a
    /// widget can schedule its redraws without touching the network.
    public func refreshDates(
        from now: Date,
        horizon: TimeInterval = 36 * 3600,
        limit: Int = 48
    ) -> [Date] {
        let end = now.addingTimeInterval(horizon)
        let boundaries = activeLessons.flatMap { [$0.start, $0.end] }
        let midnights = (1...2).map { KretaDate.addingDays($0, to: KretaDate.startOfDay(now)) }
        let upcoming = Set(boundaries + midnights).filter { $0 > now && $0 <= end }
        return Array(([now] + upcoming.sorted()).prefix(limit))
    }
}

extension Schedule {
    /// The window every sync asks for: last week through two weeks after the
    /// current one. Both ends are inclusive school days.
    public static func syncRange(containing now: Date) -> (from: Date, to: Date) {
        let weekStart = KretaDate.calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? KretaDate.startOfDay(now)
        return (KretaDate.addingDays(-7, to: weekStart), KretaDate.addingDays(20, to: weekStart))
    }
}
