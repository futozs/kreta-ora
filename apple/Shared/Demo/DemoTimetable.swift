import Foundation
import KretaKit

/// An invented timetable around the current moment. It fills the widget
/// gallery, and in debug builds the `-DemoData` launch argument shows every
/// screen with it. No real people or schools: every name is made up.
enum DemoTimetable {
    static let account = Account(
        id: "demo", institutionCode: "minta-iskola", userName: "demo", displayName: "Teszt Elek"
    )

    private struct Slot {
        let name: String
        var teacher: String? = "Példa Éva"
        var room: String? = "204"
        var substitute: String?
        var isCancelled = false
        var hasTest = false
    }

    /// Minutes from the first bell: 45-minute lessons, the last one after a long break.
    private static let offsets = [0, 55, 110, 170, 225, 280, 345]
    private static let lessonLength: TimeInterval = 45 * 60

    private static let today: [Slot] = [
        Slot(name: "matematika", teacher: "Próba Kálmán", room: "12"),
        Slot(name: "magyar irodalom", room: "108"),
        Slot(name: "fizika", teacher: "Minta Péter", room: "Labor"),
        Slot(name: "angol nyelv", teacher: "Példa Éva", room: "21", substitute: "Teszt Ilona", hasTest: true),
        Slot(name: "történelem", teacher: "Próba Kálmán", room: "12"),
        Slot(name: "informatika", teacher: "Minta Péter", room: "I/3", isCancelled: true),
        Slot(name: "testnevelés", teacher: "Teszt Ilona", room: "Tornaterem"),
    ]

    private static let week: [[Slot]] = [
        [
            Slot(name: "kémia", room: "Labor"),
            Slot(name: "matematika", teacher: "Próba Kálmán", room: "12"),
            Slot(name: "német nyelv", teacher: "Minta Péter", room: "33", isCancelled: true),
            Slot(name: "biológia", substitute: "Teszt Ilona"),
            Slot(name: "magyar nyelvtan", room: "108", hasTest: true),
            Slot(name: "földrajz"),
        ],
        [
            Slot(name: "angol nyelv", room: "21"),
            Slot(name: "történelem", teacher: "Próba Kálmán", room: "12"),
            Slot(name: "ének-zene", room: "Zeneterem"),
            Slot(name: "matematika", teacher: "Próba Kálmán", room: "12"),
            Slot(name: "osztályfőnöki", room: "12"),
        ],
        [
            Slot(name: "informatika", teacher: "Minta Péter", room: "I/3"),
            Slot(name: "informatika", teacher: "Minta Péter", room: "I/3"),
            Slot(name: "fizika", teacher: "Minta Péter", room: "Labor"),
            Slot(name: "vizuális kultúra", room: "Rajzterem"),
            Slot(name: "testnevelés", teacher: "Teszt Ilona", room: "Tornaterem"),
            Slot(name: "etika"),
        ],
        [
            Slot(name: "matematika", teacher: "Próba Kálmán", room: "12"),
            Slot(name: "angol nyelv", room: "21", hasTest: true),
            Slot(name: "kémia", room: "Labor", substitute: "Teszt Ilona"),
            Slot(name: "magyar irodalom", room: "108"),
            Slot(name: "drámajáték", teacher: "Teszt Ilona", room: "Aula"),
        ],
        [
            Slot(name: "biológia"),
            Slot(name: "matematika", teacher: "Próba Kálmán", room: "12"),
            Slot(name: "történelem", teacher: "Próba Kálmán", room: "12"),
            Slot(name: "angol nyelv", room: "21"),
            Slot(name: "testnevelés", teacher: "Teszt Ilona", room: "Tornaterem"),
        ],
    ]

    /// This week and the next, Monday to Friday, with today's lessons placed
    /// so that one of them is running now.
    static func snapshot(now: Date = Date()) -> TimetableSnapshot {
        let monday = KretaDate.startOfWeek(now)
        let todayStart = KretaDate.startOfDay(now)
        var lessons: [Lesson] = []
        for offset in 0..<14 {
            let day = KretaDate.addingDays(offset, to: monday)
            if day == todayStart {
                lessons += build(today, firstBell: todayFirstBell(now: now), tag: "today")
            } else if !KretaDate.isWeekend(day) {
                let slots = week[KretaDate.weekdayIndex(day) % week.count]
                lessons += build(slots, firstBell: day.addingTimeInterval(8 * 3600), tag: "d\(offset)")
            }
        }
        lessons.append(event(on: KretaDate.addingDays(9, to: monday)))
        return TimetableSnapshot(
            accountID: account.id,
            lessons: lessons,
            rangeStart: monday,
            rangeEnd: KretaDate.addingDays(14, to: monday),
            syncedAt: now.addingTimeInterval(-6 * 60)
        )
    }

    /// The third lesson started 21 minutes ago, unless that would push the day
    /// outside sensible hours; then the day starts at 8:00 as usual.
    private static func todayFirstBell(now: Date) -> Date {
        let anchored = now.addingTimeInterval(-TimeInterval(offsets[2] + 21) * 60)
        let dayStart = KretaDate.startOfDay(now)
        let lastEnd = anchored.addingTimeInterval(TimeInterval(offsets[6]) * 60 + lessonLength)
        let earliest = dayStart.addingTimeInterval(6 * 3600)
        let latest = dayStart.addingTimeInterval(22 * 3600)
        return anchored >= earliest && lastEnd <= latest ? anchored : dayStart.addingTimeInterval(8 * 3600)
    }

    private static func build(_ slots: [Slot], firstBell: Date, tag: String) -> [Lesson] {
        slots.enumerated().map { index, slot in
            let start = firstBell.addingTimeInterval(TimeInterval(offsets[index]) * 60)
            return Lesson(
                id: "demo-\(tag)-\(index + 1)",
                start: start,
                end: start.addingTimeInterval(lessonLength),
                name: slot.name,
                index: index + 1,
                teacher: slot.teacher,
                substituteTeacher: slot.substitute,
                room: slot.room,
                isCancelled: slot.isCancelled,
                hasTest: slot.hasTest
            )
        }
    }

    private static func event(on day: Date) -> Lesson {
        Lesson(
            id: "demo-event",
            start: day.addingTimeInterval(7 * 3600),
            end: day.addingTimeInterval(16 * 3600),
            name: "pályaorientációs nap",
            kind: .event
        )
    }
}
