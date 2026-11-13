import Foundation

/// Date handling for KRÉTA payloads. School time is always Europe/Budapest.
public enum KretaDate {
    /// Gregorian calendar in school time, weeks starting on Monday.
    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = KretaConfig.timeZone
        calendar.locale = Locale(identifier: "hu_HU")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    /// Parses `yyyy-MM-ddTHH:mm:ss` with optional fractional seconds and an
    /// optional `Z` or numeric offset. A value without a zone is school time.
    public static func parse(_ raw: String) -> Date? {
        let bytes = Array(raw.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        guard bytes.count >= 19 else { return nil }

        func number(_ range: Range<Int>) -> Int? {
            let slice = bytes[range]
            guard slice.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else { return nil }
            return Int(String(decoding: slice, as: UTF8.self))
        }
        func isByte(_ index: Int, _ characters: String) -> Bool {
            characters.utf8.contains(bytes[index])
        }

        guard
            let year = number(0..<4), isByte(4, "-"),
            let month = number(5..<7), isByte(7, "-"),
            let day = number(8..<10), isByte(10, "T "),
            let hour = number(11..<13), isByte(13, ":"),
            let minute = number(14..<16), isByte(16, ":"),
            let second = number(17..<19)
        else { return nil }

        var index = 19
        if index < bytes.count, isByte(index, ".") {
            index += 1
            while index < bytes.count, bytes[index] >= 0x30, bytes[index] <= 0x39 { index += 1 }
        }

        var zone = KretaConfig.timeZone
        if index < bytes.count {
            guard let parsed = timeZone(String(decoding: bytes[index...], as: UTF8.self)) else { return nil }
            zone = parsed
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        )
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }

    private static func timeZone(_ suffix: String) -> TimeZone? {
        if suffix == "Z" || suffix == "z" { return TimeZone(secondsFromGMT: 0) }
        let digits = suffix.dropFirst().filter { $0 != ":" }
        guard
            let sign = suffix.first, sign == "+" || sign == "-",
            digits.count == 4, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber),
            let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)),
            hours <= 14, minutes < 60
        else { return nil }
        let seconds = (hours * 60 + minutes) * 60
        return TimeZone(secondsFromGMT: sign == "-" ? -seconds : seconds)
    }

    /// `yyyy-MM-dd` of the school day containing `date`.
    public static func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `H:mm` in school time.
    public static func timeString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    public static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days) * 86_400)
    }

    /// Whole school days from `start` to `end`; negative when `end` is earlier.
    public static func days(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(start), to: startOfDay(end)).day ?? 0
    }

    public static func isSameDay(_ first: Date, _ second: Date) -> Bool {
        calendar.isDate(first, inSameDayAs: second)
    }
}
