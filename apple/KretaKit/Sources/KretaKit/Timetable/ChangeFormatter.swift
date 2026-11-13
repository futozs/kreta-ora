import Foundation

/// Hungarian notification texts for timetable changes.
public struct ChangeFormatter: Sendable {
    /// More changes than this in one sync are announced as one summary.
    public static let individualLimit = 3

    private let now: Date

    public init(now: Date) {
        self.now = now
    }

    public func title(for change: TimetableChange) -> String {
        "\(prefix(for: change)): \(change.lesson.displayName)"
    }

    public func body(for change: TimetableChange) -> String {
        let lesson = change.lesson
        let details: [String?] =
            switch change.kind {
            case .cancelled, .removed, .restored:
                []
            case .added:
                [lesson.room.map { "terem: \($0)" }, lesson.effectiveTeacher]
            case .teacher:
                [teacherDetail(lesson), lesson.room.map { "terem: \($0)" }]
            case .time:
                [change.previous.map { "eddig: \(Self.when($0, relativeTo: now))" }]
            case .room:
                [roomDetail(lesson, previous: change.previous)]
            }
        return ([Self.when(lesson, relativeTo: now)] + details.compactMap { $0 }).joined(separator: " · ")
    }

    /// One line for a sync that changed many lessons at once.
    public func summary(for changes: [TimetableChange]) -> (title: String, body: String) {
        let days = Set(changes.map { Self.dayLabel($0.lesson.start, relativeTo: now) })
        let ordered = changes.map { Self.dayLabel($0.lesson.start, relativeTo: now) }
            .reduce(into: [String]()) { result, day in
                if !result.contains(day) { result.append(day) }
            }
        return (
            "\(changes.count) órarendváltozás",
            days.count == 1 ? "\(ordered[0]): nyisd meg a részletekért." : ordered.joined(separator: ", ")
        )
    }

    private func prefix(for change: TimetableChange) -> String {
        switch change.kind {
        case .cancelled: "Elmarad"
        case .restored: "Mégis megtartják"
        case .time: "Időpont változott"
        case .room: "Teremcsere"
        case .added: "Új óra"
        case .removed: "Törölt óra"
        case .teacher:
            if change.lesson.isSubstituted {
                "Helyettesítés"
            } else if change.previous?.isSubstituted == true {
                "Helyettesítés visszavonva"
            } else {
                "Tanárváltozás"
            }
        }
    }

    private func teacherDetail(_ lesson: Lesson) -> String? {
        if let substitute = lesson.substituteTeacher { return "helyettesít: \(substitute)" }
        return lesson.teacher.map { "tanár: \($0)" }
    }

    private func roomDetail(_ lesson: Lesson, previous: Lesson?) -> String {
        let current = lesson.room ?? "nincs megadva"
        guard let old = previous?.room else { return "terem: \(current)" }
        return "terem: \(current) (eddig: \(old))"
    }
}

extension ChangeFormatter {
    /// "Holnap, 3. óra, 9:55–10:40"
    public static func when(_ lesson: Lesson, relativeTo now: Date) -> String {
        let time = "\(KretaDate.timeString(lesson.start))–\(KretaDate.timeString(lesson.end))"
        let position = lesson.index.map { "\($0). óra" }
        return ([dayLabel(lesson.start, relativeTo: now), position, time] as [String?])
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// "Ma", "Holnap", or "péntek (nov. 15.)".
    public static func dayLabel(_ date: Date, relativeTo now: Date) -> String {
        switch KretaDate.days(from: now, to: date) {
        case 0: return "Ma"
        case 1: return "Holnap"
        default:
            let weekday = KretaDate.weekdayName(date)
            let day = KretaDate.shortDate(date)
            return "\(weekday) (\(day))"
        }
    }
}
