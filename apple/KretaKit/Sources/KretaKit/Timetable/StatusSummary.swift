import Foundation

/// The one thing a glanceable surface shows: which lesson matters now, what
/// to call it, and what to count down to.
public struct StatusSummary: Equatable, Sendable {
    /// "Most", "Következik", "Első óra", "Holnap", "Hétfő", "Nincs több óra".
    public let label: String
    public let lesson: Lesson?
    /// End of the running lesson, or start of the upcoming one today.
    public let countdownTo: Date?
    public let isInLesson: Bool
    /// The lesson after `lesson` on the same day.
    public let following: Lesson?

    public init(schedule: Schedule, now: Date) {
        switch schedule.status(at: now) {
        case .inLesson(let current, let next):
            label = "Most"
            lesson = current
            countdownTo = current.end
            isInLesson = true
            following = next
        case .breakTime(let next):
            label = "Következik"
            lesson = next
            countdownTo = next.start
            isInLesson = false
            following = schedule.lesson(after: next)
        case .beforeFirst(let first):
            label = "Első óra"
            lesson = first
            countdownTo = first.start
            isInLesson = false
            following = schedule.lesson(after: first)
        case .dayOver(let nextFirst?):
            label = Self.dayName(nextFirst.start, relativeTo: now)
            lesson = nextFirst
            countdownTo = nil
            isInLesson = false
            following = schedule.lesson(after: nextFirst)
        case .dayOver(nil):
            label = "Nincs több óra"
            lesson = nil
            countdownTo = nil
            isInLesson = false
            following = nil
        }
    }

    /// "Holnap", "Hétfő", or "Hétfő, nov. 23." once it is a week or more away.
    public static func dayName(_ date: Date, relativeTo now: Date) -> String {
        let days = KretaDate.days(from: now, to: date)
        if days == 1 { return "Holnap" }
        let weekday = KretaDate.weekdayName(date).capitalizedFirst
        return days < 7 ? weekday : "\(weekday), \(KretaDate.shortDate(date))"
    }
}

/// One school day at a glance.
public struct DaySummary: Equatable, Sendable {
    /// Start of the day.
    public let day: Date
    /// Every lesson of the day, cancelled ones included.
    public let lessons: [Lesson]

    public var active: [Lesson] { lessons.filter(\.isActive) }
    public var first: Lesson? { active.first }
    public var last: Lesson? { active.last }
    public var cancelledCount: Int { lessons.filter(\.isCancelled).count }
    public var substitutedCount: Int { active.filter(\.isSubstituted).count }

    /// "8:00–13:35 · 6 óra"
    public var span: String? {
        guard let first, let last else { return nil }
        return "\(KretaDate.timeString(first.start))–\(KretaDate.timeString(last.end)) · \(active.count) óra"
    }
}

extension Schedule {
    /// The next lesson that takes place on the same day, after `lesson`.
    public func lesson(after lesson: Lesson) -> Lesson? {
        activeLessons.first { $0.start >= lesson.end && KretaDate.isSameDay($0.start, lesson.start) }
    }

    public func summary(of day: Date) -> DaySummary {
        DaySummary(day: KretaDate.startOfDay(day), lessons: lessons(on: day))
    }

    /// The next day with at least one lesson, strictly after today.
    public func nextSchoolDay(after now: Date) -> DaySummary? {
        firstLessonOfNextSchoolDay(after: now).map { summary(of: $0.start) }
    }

    /// The day worth listing right now: today while a lesson is still ahead
    /// or running, otherwise the next school day.
    public func focusDay(at now: Date) -> DaySummary? {
        let today = summary(of: now)
        if today.active.contains(where: { $0.end > now }) { return today }
        return nextSchoolDay(after: now)
    }

    /// The days that have lessons, in order, from `now`'s day onwards.
    public func upcomingDays(from now: Date, limit: Int = 14) -> [DaySummary] {
        let today = KretaDate.startOfDay(now)
        let days = lessons
            .filter { $0.start >= today }
            .map { KretaDate.startOfDay($0.start) }
            .reduce(into: [Date]()) { result, day in
                if result.last != day { result.append(day) }
            }
        return days.prefix(limit).map(summary(of:))
    }
}

extension TimetableSnapshot {
    /// The part of the snapshot from today on, for surfaces with a small
    /// transfer budget such as the watch.
    public func window(from now: Date, days: Int) -> TimetableSnapshot {
        let start = max(rangeStart, KretaDate.startOfDay(now))
        let end = min(rangeEnd, KretaDate.addingDays(days, to: KretaDate.startOfDay(now)))
        return TimetableSnapshot(
            accountID: accountID,
            lessons: lessons.filter { $0.start >= start && $0.start < end },
            rangeStart: start,
            rangeEnd: max(start, end),
            syncedAt: syncedAt
        )
    }
}

extension KretaDate {
    private static var style: Date.FormatStyle {
        Date.FormatStyle(locale: Locale(identifier: "hu_HU"), calendar: calendar, timeZone: KretaConfig.timeZone)
    }

    /// "péntek"
    public static func weekdayName(_ date: Date) -> String {
        date.formatted(style.weekday(.wide))
    }

    /// "nov. 20."
    public static func shortDate(_ date: Date) -> String {
        date.formatted(style.month(.abbreviated).day())
    }
}

extension String {
    /// First letter in upper case, using Hungarian casing rules.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased(with: Locale(identifier: "hu_HU")) + dropFirst()
    }
}
