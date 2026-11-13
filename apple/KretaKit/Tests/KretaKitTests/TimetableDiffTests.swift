import Foundation
import Testing
@testable import KretaKit

@Suite("Timetable diff")
struct TimetableDiffTests {
    /// Monday 7:00, before any lesson of the fixture week.
    private let now = Fixture.date(16, 7)
    private let maths = Fixture.lesson("a", day: 17, index: 1)
    private let physics = Fixture.lesson("b", day: 17, index: 2, name: "fizika")

    private func diff(_ old: [Lesson]?, _ new: [Lesson], at time: Date? = nil) -> [TimetableChange] {
        TimetableDiff.changes(
            from: old.map { Fixture.snapshot($0) },
            to: Fixture.snapshot(new),
            now: time ?? now
        )
    }

    @Test("the first sync is a silent baseline")
    func firstSyncSilent() {
        #expect(diff(nil, [maths, physics]).isEmpty)
    }

    @Test("an unchanged timetable is silent")
    func unchangedSilent() {
        #expect(diff([maths, physics], [physics, maths]).isEmpty)
    }

    @Test("another account's snapshot is not a baseline")
    func otherAccountSilent() {
        let changes = TimetableDiff.changes(
            from: Fixture.snapshot([maths], account: "someone-else"),
            to: Fixture.snapshot([]),
            now: now
        )
        #expect(changes.isEmpty)
    }

    @Test("a cancellation is reported once")
    func cancellation() {
        let cancelled = Fixture.lesson("a", day: 17, index: 1, cancelled: true)
        let changes = diff([maths, physics], [cancelled, physics])
        #expect(changes == [TimetableChange(kind: .cancelled, lesson: cancelled, previous: maths)])
        #expect(diff([cancelled, physics], [cancelled, physics]).isEmpty)
    }

    @Test("a cancelled lesson that is held after all is reported")
    func restored() {
        let cancelled = Fixture.lesson("a", day: 17, index: 1, cancelled: true)
        #expect(diff([cancelled], [maths]).map(\.kind) == [.restored])
    }

    @Test("a substitute teacher is reported, and so is its withdrawal")
    func substitution() {
        let substituted = Fixture.lesson("a", day: 17, index: 1, substitute: "Nagy Anna")
        #expect(diff([maths], [substituted]) == [
            TimetableChange(kind: .teacher, lesson: substituted, previous: maths)
        ])
        #expect(diff([substituted], [maths]).map(\.kind) == [.teacher])
    }

    @Test("a room change is reported")
    func roomChange() {
        let moved = Fixture.lesson("a", day: 17, index: 1, room: "204")
        #expect(diff([maths], [moved]).map(\.kind) == [.room])
    }

    @Test("a time change outranks teacher and room changes")
    func timeChange() {
        let later = Lesson(
            id: "a", start: maths.start.addingTimeInterval(600), end: maths.end.addingTimeInterval(600),
            name: maths.name, index: 1, teacher: "Valaki Más", room: "204"
        )
        #expect(diff([maths], [later]).map(\.kind) == [.time])
    }

    @Test("changes to an already cancelled lesson are ignored")
    func cancelledStaysQuiet() {
        let before = Fixture.lesson("a", day: 17, index: 1, room: "12", cancelled: true)
        let after = Fixture.lesson("a", day: 17, index: 1, room: "204", cancelled: true)
        #expect(diff([before], [after]).isEmpty)
    }

    @Test("a topic the teacher filled in is not a change")
    func topicIgnored() {
        let withTopic = Fixture.lesson("a", day: 17, index: 1, topic: "Másodfokú egyenletek")
        #expect(diff([maths], [withTopic]).isEmpty)
    }

    @Test("lessons that already ended never notify")
    func pastIgnored() {
        let cancelled = Fixture.lesson("a", day: 17, index: 1, cancelled: true)
        #expect(diff([maths], [cancelled], at: maths.end).isEmpty)
        #expect(diff([maths], [], at: maths.end).isEmpty)
        // Still running: the student may be on the way.
        #expect(diff([maths], [cancelled], at: maths.start.addingTimeInterval(60)).count == 1)
    }

    @Test("a lesson added inside the known window is reported")
    func added() {
        let extra = Fixture.lesson("c", day: 18, index: 5, name: "kémia")
        #expect(diff([maths], [maths, extra]) == [TimetableChange(kind: .added, lesson: extra)])
    }

    @Test("a week rolling into view is silent")
    func rollingWindowSilent() {
        let nextWeek = Fixture.lesson("z", day: 26, index: 1)
        let changes = TimetableDiff.changes(
            from: Fixture.snapshot([maths], from: 16, to: 23),
            to: Fixture.snapshot([maths, nextWeek], from: 16, to: 30),
            now: now
        )
        #expect(changes.isEmpty)
    }

    @Test("a lesson removed from the timetable is reported")
    func removed() {
        #expect(diff([maths, physics], [physics]) == [TimetableChange(kind: .removed, lesson: maths)])
    }

    @Test("a lesson that fell out of the fetched window is not removed")
    func outOfWindowNotRemoved() {
        let far = Fixture.lesson("far", day: 27, index: 1)
        let changes = TimetableDiff.changes(
            from: Fixture.snapshot([maths, far], from: 16, to: 30),
            to: Fixture.snapshot([maths], from: 16, to: 23),
            now: now
        )
        #expect(changes.isEmpty)
    }

    @Test("an identifier change in the same slot is compared as one lesson")
    func identifierChurn() {
        let reissued = Fixture.lesson("a-new", day: 17, index: 1)
        #expect(diff([maths], [reissued]).isEmpty)

        let reissuedWithSubstitute = Fixture.lesson("a-new", day: 17, index: 1, substitute: "Nagy Anna")
        #expect(diff([maths], [reissuedWithSubstitute]) == [
            TimetableChange(kind: .teacher, lesson: reissuedWithSubstitute, previous: maths)
        ])
    }

    @Test("a different subject in the same slot is a removal and an addition")
    func replacedSubject() {
        let replacement = Fixture.lesson("c", day: 17, index: 1, name: "kémia")
        #expect(diff([maths], [replacement]).map(\.kind).sorted { $0.rawValue < $1.rawValue } == [.added, .removed])
    }

    @Test("free-slot placeholders and cancelled leftovers do not notify")
    func placeholdersIgnored() {
        let placeholder = Fixture.lesson("p", day: 17, index: 3, kind: .empty)
        let cancelledExtra = Fixture.lesson("x", day: 17, index: 4, cancelled: true)
        #expect(diff([maths], [maths, placeholder, cancelledExtra]).isEmpty)
        #expect(diff([maths, placeholder, cancelledExtra], [maths]).isEmpty)
    }

    @Test("changes come back in timetable order")
    func ordering() {
        let cancelledPhysics = Fixture.lesson("b", day: 17, index: 2, name: "fizika", cancelled: true)
        let movedMaths = Fixture.lesson("a", day: 17, index: 1, room: "204")
        let extra = Fixture.lesson("c", day: 16, index: 6, name: "kémia")
        let changes = diff([maths, physics], [cancelledPhysics, movedMaths, extra])
        #expect(changes.map(\.lesson.id) == ["c", "a", "b"])
        #expect(Set(changes.map(\.id)).count == 3)
    }
}
