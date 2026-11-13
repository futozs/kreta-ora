import Foundation

extension TimetableSnapshot {
    /// The days a day-by-day view pages through: every weekday of the window,
    /// and a weekend day only when it has a lesson. A weekday without lessons
    /// stays in, so the week keeps its shape. Each day is its start in school
    /// time.
    public func pagerDays() -> [Date] {
        let withLessons = Set(lessons.filter { $0.kind == .lesson }.map { KretaDate.startOfDay($0.start) })
        let end = KretaDate.startOfDay(rangeEnd)
        var days: [Date] = []
        var day = KretaDate.startOfDay(rangeStart)
        while day < end {
            if !KretaDate.isWeekend(day) || withLessons.contains(day) { days.append(day) }
            day = KretaDate.addingDays(1, to: day)
        }
        return days
    }
}

extension KretaDate {
    /// Saturday or Sunday in school time.
    public static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// Monday of the week that contains `date`, at the start of the day.
    public static func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(date)
    }

    /// Day of the month, 1–31.
    public static func dayOfMonth(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    /// 0 for Monday … 6 for Sunday.
    public static func weekdayIndex(_ date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }
}
