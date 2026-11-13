import Foundation

/// Where a lesson stands relative to now. It decides how much room its block takes.
public enum BlockMode: Equatable, Sendable {
    /// Later today, or on another day.
    case upcoming
    /// Already over: the block gives its colour back and shrinks to one quiet line.
    case past
    /// Being held right now: the block grows and counts down to the bell.
    case running
    /// The next one to start today: slightly larger, says how soon.
    case upNext

    public init(lesson: Lesson, now: Date, nextUp: Lesson?) {
        if lesson.end <= now {
            self = .past
        } else if lesson.contains(now) {
            self = .running
        } else if lesson.id == nextUp?.id {
            self = .upNext
        } else {
            self = .upcoming
        }
    }
}

/// One row of a day: a lesson, or the note that a long gap sits between two lessons.
public enum DayRow: Equatable, Identifiable, Sendable {
    case block(Lesson, BlockMode)
    case gap(minutes: Int, after: String)

    public var id: String {
        switch self {
        case .block(let lesson, _): lesson.id
        case .gap(_, let after): "gap-\(after)"
        }
    }
}

/// The questions a day-by-day timetable asks.
public enum DayPlan {
    /// A break this long gets its own note.
    public static let longBreakMinutes = 20

    /// The day's lessons with their modes, and a gap row wherever the break
    /// is long enough to matter.
    public static func rows(_ schedule: Schedule, day: Date, now: Date) -> [DayRow] {
        let lessons = schedule.lessons(on: day)
        let summary = StatusSummary(schedule: schedule, now: now)
        // Only a lesson that is still to start today is "next up"; tomorrow's first lesson is not.
        let nextUp = !summary.isInLesson && summary.countdownTo != nil ? summary.lesson : nil
        var rows: [DayRow] = []
        for (index, lesson) in lessons.enumerated() {
            if index > 0 {
                let previous = lessons[index - 1]
                let gap = Int(lesson.start.timeIntervalSince(previous.end) / 60)
                if gap >= longBreakMinutes { rows.append(.gap(minutes: gap, after: previous.id)) }
            }
            rows.append(.block(lesson, BlockMode(lesson: lesson, now: now, nextUp: nextUp)))
        }
        return rows
    }

    /// The page to open on: today while lessons remain, otherwise the next school day.
    public static func initialIndex(of days: [Date], schedule: Schedule?, now: Date) -> Int {
        let focus = schedule?.focusDay(at: now)?.day ?? KretaDate.startOfDay(now)
        return days.firstIndex { $0 >= focus } ?? max(days.count - 1, 0)
    }

    /// The days of `days` that share a week with `day`.
    public static func week(of day: Date, in days: [Date]) -> [Date] {
        let monday = KretaDate.startOfWeek(day)
        return days.filter { KretaDate.startOfWeek($0) == monday }
    }

    /// Monday to Friday of the week of `day`, shown before the first timetable arrives.
    public static func schoolWeek(of day: Date) -> [Date] {
        let monday = KretaDate.startOfWeek(day)
        return (0..<5).map { KretaDate.addingDays($0, to: monday) }
    }

    /// A lesson of this day that is still ahead has been cancelled.
    public static func hasCancellationAhead(_ schedule: Schedule?, on day: Date, now: Date) -> Bool {
        schedule?.lessons(on: day).contains { $0.isCancelled && $0.end > now } ?? false
    }

    /// Today while its first lesson is still ahead, otherwise the next school day.
    public static func dayStart(_ schedule: Schedule, now: Date) -> DaySummary? {
        let today = schedule.summary(of: now)
        if let first = today.first, first.start > now { return today }
        return schedule.nextSchoolDay(after: now)
    }
}
