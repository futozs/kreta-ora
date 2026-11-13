import Foundation
import KretaKit

/// When the next school day starts, for the "Mikor kezdünk?" widget.
struct DayStartCard: Equatable {
    /// "Ma", "Holnap", "Hétfő".
    let label: String
    let time: String
    let start: Date
    /// "Matematika · 12"
    let title: String
    /// Teacher, or the substitute.
    let detail: String?
    /// "8:00–13:35 · 6 óra"
    let footnote: String?
    /// A cancelled lesson or a substitute matters more than the length of the day.
    let alert: String?
    /// Every lesson of the day for the bar, cancelled ones included.
    let lessons: [Lesson]

    init?(schedule: Schedule, now: Date) {
        guard let day = DayPlan.dayStart(schedule, now: now), let first = day.first else { return nil }
        let startsLaterToday = KretaDate.isSameDay(first.start, now)
        label = startsLaterToday ? L10n.today : StatusSummary.dayName(first.start, relativeTo: now)
        time = KretaDate.timeString(first.start)
        start = first.start
        title = [first.displayName, first.room].compactMap { $0 }.joined(separator: Formatting.separator)
        detail = first.substituteTeacher.map(L10n.substitute) ?? first.teacher
        footnote = day.span
        let notes = [
            day.cancelledCount > 0 ? L10n.cancelledCount(day.cancelledCount) : nil,
            day.substitutedCount > 0 ? L10n.substitutedCount(day.substitutedCount) : nil,
        ].compactMap { $0 }
        alert = notes.isEmpty ? nil : notes.joined(separator: Formatting.separator)
        lessons = day.lessons
    }
}
