import Foundation
import Testing
@testable import KretaKit

@Suite("Change formatter")
struct ChangeFormatterTests {
    /// Monday 7:00.
    private let now = Fixture.date(16, 7)
    private var formatter: ChangeFormatter { ChangeFormatter(now: now) }
    private let today = Fixture.lesson("t", day: 16, index: 3)
    private let tomorrow = Fixture.lesson("m", day: 17, index: 1)
    private let friday = Fixture.lesson("f", day: 20, index: 2, name: "angol nyelv")

    @Test("cancellation")
    func cancellation() {
        let change = TimetableChange(kind: .cancelled, lesson: tomorrow, previous: tomorrow)
        #expect(formatter.title(for: change) == "Elmarad: Matematika")
        #expect(formatter.body(for: change) == "Holnap, 1. óra, 8:00–8:45")
    }

    @Test("day labels: today, tomorrow, then weekday with date")
    func dayLabels() {
        #expect(ChangeFormatter.dayLabel(today.start, relativeTo: now) == "Ma")
        #expect(ChangeFormatter.dayLabel(tomorrow.start, relativeTo: now) == "Holnap")
        #expect(ChangeFormatter.dayLabel(friday.start, relativeTo: now) == "péntek (nov. 20.)")
        #expect(ChangeFormatter.when(friday, relativeTo: now) == "péntek (nov. 20.), 2. óra, 8:55–9:40")
    }

    @Test("a lesson without a number shows only the time")
    func unnumbered() {
        let lesson = Lesson(id: "u", start: Fixture.date(16, 14), end: Fixture.date(16, 15, 30), name: "szakkör")
        #expect(ChangeFormatter.when(lesson, relativeTo: now) == "Ma, 14:00–15:30")
    }

    @Test("substitution names the substitute and the room")
    func substitution() {
        let substituted = Fixture.lesson("m", day: 17, index: 1, substitute: "Nagy Anna")
        let change = TimetableChange(kind: .teacher, lesson: substituted, previous: tomorrow)
        #expect(formatter.title(for: change) == "Helyettesítés: Matematika")
        #expect(formatter.body(for: change) == "Holnap, 1. óra, 8:00–8:45 · helyettesít: Nagy Anna · terem: 12")
    }

    @Test("withdrawn substitution and plain teacher change have their own titles")
    func teacherVariants() {
        let substituted = Fixture.lesson("m", day: 17, index: 1, substitute: "Nagy Anna")
        let withdrawn = TimetableChange(kind: .teacher, lesson: tomorrow, previous: substituted)
        #expect(formatter.title(for: withdrawn) == "Helyettesítés visszavonva: Matematika")
        #expect(formatter.body(for: withdrawn).contains("tanár: Kiss Béla"))

        let other = Fixture.lesson("m", day: 17, index: 1, teacher: "Szabó Pál")
        let changed = TimetableChange(kind: .teacher, lesson: other, previous: tomorrow)
        #expect(formatter.title(for: changed) == "Tanárváltozás: Matematika")
    }

    @Test("room change shows both rooms")
    func room() {
        let moved = Fixture.lesson("m", day: 17, index: 1, room: "204")
        let change = TimetableChange(kind: .room, lesson: moved, previous: tomorrow)
        #expect(formatter.title(for: change) == "Teremcsere: Matematika")
        #expect(formatter.body(for: change) == "Holnap, 1. óra, 8:00–8:45 · terem: 204 (eddig: 12)")

        let roomless = Fixture.lesson("m", day: 17, index: 1, room: nil)
        let assigned = TimetableChange(kind: .room, lesson: moved, previous: roomless)
        #expect(formatter.body(for: assigned).hasSuffix("terem: 204"))
        let unassigned = TimetableChange(kind: .room, lesson: roomless, previous: tomorrow)
        #expect(formatter.body(for: unassigned).hasSuffix("terem: nincs megadva (eddig: 12)"))
    }

    @Test("time change shows the old slot")
    func time() {
        let moved = Fixture.lesson("m", day: 17, index: 3)
        let change = TimetableChange(kind: .time, lesson: moved, previous: tomorrow)
        #expect(formatter.title(for: change) == "Időpont változott: Matematika")
        #expect(formatter.body(for: change) == "Holnap, 3. óra, 9:50–10:35 · eddig: Holnap, 1. óra, 8:00–8:45")
    }

    @Test("added, removed and restored")
    func others() {
        let added = TimetableChange(kind: .added, lesson: friday)
        #expect(formatter.title(for: added) == "Új óra: Angol nyelv")
        #expect(formatter.body(for: added) == "péntek (nov. 20.), 2. óra, 8:55–9:40 · terem: 12 · Kiss Béla")
        #expect(formatter.title(for: TimetableChange(kind: .removed, lesson: today)) == "Törölt óra: Matematika")
        #expect(formatter.title(for: TimetableChange(kind: .restored, lesson: today)) == "Mégis megtartják: Matematika")
        #expect(formatter.body(for: TimetableChange(kind: .restored, lesson: today)) == "Ma, 3. óra, 9:50–10:35")
    }

    @Test("many changes collapse into one summary")
    func summary() {
        let sameDay = [today, Fixture.lesson("t2", day: 16, index: 4)]
            .map { TimetableChange(kind: .cancelled, lesson: $0) }
        #expect(formatter.summary(for: sameDay).title == "2 órarendváltozás")
        #expect(formatter.summary(for: sameDay).body == "Ma: nyisd meg a részletekért.")

        let mixed = [today, tomorrow, friday, today].map { TimetableChange(kind: .cancelled, lesson: $0) }
        #expect(formatter.summary(for: mixed).title == "4 órarendváltozás")
        #expect(formatter.summary(for: mixed).body == "Ma, Holnap, péntek (nov. 20.)")
    }
}
