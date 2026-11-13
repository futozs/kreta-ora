import Foundation
import KretaKit

/// Texts derived from lessons and days, shared by the app, widgets and watch.
enum Formatting {
    static let separator = " · "
    private static let hungarian = Locale(identifier: "hu_HU")

    /// "8:00–8:45"
    static func timeRange(_ lesson: Lesson) -> String {
        "\(KretaDate.timeString(lesson.start))–\(KretaDate.timeString(lesson.end))"
    }

    static func number(_ lesson: Lesson) -> String {
        lesson.index.map(L10n.lessonNumber) ?? ""
    }

    /// "november 13."
    static func longDate(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: hungarian, calendar: KretaDate.calendar, timeZone: KretaDate.calendar.timeZone)
                .month(.wide).day()
        )
    }

    /// "Ma, november 13." for the three days around today, the plain date otherwise.
    static func dateLine(_ day: Date, today: Date) -> String {
        let date = longDate(day)
        let relative: String? = switch KretaDate.days(from: today, to: day) {
        case 0: L10n.today
        case 1: L10n.tomorrow
        case -1: L10n.yesterday
        default: nil
        }
        return relative.map { "\($0), \(date)" } ?? date
    }

    /// "Péntek"
    static func weekdayTitle(_ day: Date) -> String {
        let name = KretaDate.weekdayName(day)
        return name.prefix(1).uppercased(with: hungarian) + name.dropFirst()
    }

    /// "7:55–14:10, 6 óra" and, apart so it can be red, "1 óra elmarad".
    static func summary(_ schedule: Schedule, day: Date) -> (span: String?, cancelled: String?)? {
        let summary = schedule.summary(of: day)
        guard !summary.lessons.isEmpty else { return nil }
        let span = summary.span?.replacingOccurrences(of: separator, with: ", ")
        let cancelled = summary.cancelledCount > 0 ? L10n.cancelledCount(summary.cancelledCount) : nil
        return (span, cancelled)
    }

    /// Minutes, not a clock: "15:40 múlva" would read as a time of day.
    static func startsIn(minutes: Int) -> String {
        if minutes < 60 { return L10n.startsInMinutes(minutes) }
        if minutes % 60 == 0 { return L10n.startsInHours(minutes / 60) }
        return L10n.startsInHoursMinutes(minutes / 60, minutes % 60)
    }

    static func minutesRoundedUp(_ interval: TimeInterval) -> Int {
        Int((max(interval, 0) / 60).rounded(.up))
    }

    /// "Teszt Elek" becomes "TE".
    static func initials(_ name: String) -> String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased(with: hungarian) }
            .joined()
    }

    /// "ma", "holnap", or the weekday, next to a start time that is still far away.
    static func dayWord(_ start: Date, now: Date) -> String {
        switch KretaDate.days(from: now, to: start) {
        case 0: L10n.widgetToday
        case 1: L10n.widgetTomorrow
        default: KretaDate.weekdayName(start)
        }
    }
}

/// The detail line under a lesson name: room, then who teaches. A substitute
/// and an announced test are the news, so they are marked to be set in bold.
struct LessonDetail: Equatable {
    struct Part: Equatable {
        let text: String
        let isNews: Bool
    }

    let parts: [Part]

    init(_ lesson: Lesson, withTime: Bool = false) {
        var parts: [Part] = []
        func add(_ text: String?, isNews: Bool = false) {
            guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            parts.append(Part(text: text, isNews: isNews))
        }
        if withTime { add(Formatting.timeRange(lesson)) }
        add(lesson.room)
        if let substitute = lesson.substituteTeacher {
            add(L10n.substitute(substitute), isNews: true)
        } else {
            add(lesson.teacher)
        }
        if lesson.hasTest { add(L10n.test, isNews: true) }
        self.parts = parts
    }

    var plain: String { parts.map(\.text).joined(separator: Formatting.separator) }
}
