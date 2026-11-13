import Foundation
import Testing
@testable import KretaKit

@Suite("Lesson decoding and dates")
struct LessonTests {
    private func decode(_ rows: String...) throws -> [Lesson] {
        try Lesson.decodeList(Data("[\(rows.joined(separator: ","))]".utf8))
    }

    @Test("reads a real-shaped timetable row")
    func decodesRow() throws {
        let lesson = try #require(try decode(Fixture.lessonJSON()).first)

        #expect(lesson.id == "101,TanitasiOra,2026-11-16T07:00:00Z")
        #expect(lesson.start == Fixture.date(16, 8, 0))
        #expect(lesson.end == Fixture.date(16, 8, 45))
        #expect(lesson.name == "matematika")
        #expect(lesson.displayName == "Matematika")
        #expect(lesson.index == 1)
        #expect(lesson.teacher == "Kiss Béla")
        #expect(lesson.substituteTeacher == nil)
        #expect(lesson.room == "12")
        #expect(lesson.topic == nil)
        #expect(lesson.group == "10.A")
        #expect(lesson.kind == .lesson)
        #expect(!lesson.isCancelled)
        #expect(lesson.isActive)
        #expect(lesson.hasTest)
        #expect(!lesson.hasHomework)
    }

    @Test("recognises cancelled and substituted lessons")
    func decodesCancelledAndSubstituted() throws {
        let cancelled = try #require(try decode(Fixture.lessonJSON(state: "Elmaradt")).first)
        #expect(cancelled.isCancelled)
        #expect(!cancelled.isActive)

        let substituted = try #require(try decode(Fixture.lessonJSON(substitute: #""Nagy Anna""#)).first)
        #expect(substituted.isSubstituted)
        #expect(substituted.effectiveTeacher == "Nagy Anna")
    }

    @Test("an UresOra row is a cancelled lesson, whatever its state says")
    func decodesCancelledType() throws {
        let cancelled = try #require(try decode(Fixture.lessonJSON(type: "UresOra")).first)
        #expect(cancelled.kind == .lesson)
        #expect(cancelled.isCancelled)
        #expect(!cancelled.isActive)
        #expect(cancelled.name == "matematika")
    }

    @Test("maps school-year events")
    func decodesEvents() throws {
        #expect(try decode(Fixture.lessonJSON(type: "TanevRendjeEsemeny")).first?.kind == .event)
    }

    @Test("accepts a state sent as plain text and a numeric identifier")
    func decodesLooseShapes() throws {
        let row = """
        {"Uid": 77, "KezdetIdopont": "2026-11-16T08:00:00", "VegIdopont": "2026-11-16T08:45:00",
         "Tantargy": {"Nev": "fizika"}, "Oraszam": "2", "Allapot": "Elmaradt"}
        """
        let lesson = try #require(try decode(row).first)
        #expect(lesson.id == "77")
        #expect(lesson.name == "fizika")
        #expect(lesson.index == 2)
        #expect(lesson.isCancelled)
        #expect(lesson.start == Fixture.date(16, 8))
    }

    @Test("skips rows it cannot understand and sorts the rest")
    func skipsBrokenRows() throws {
        let lessons = try decode(
            Fixture.lessonJSON(uid: "late", start: "2026-11-16T09:00:00Z", end: "2026-11-16T09:45:00Z"),
            #"{"Uid": "no-times"}"#,
            #"{"Uid": "backwards", "KezdetIdopont": "2026-11-16T09:00:00Z", "VegIdopont": "2026-11-16T08:00:00Z"}"#,
            "42",
            Fixture.lessonJSON(uid: "early")
        )
        #expect(lessons.map(\.id) == ["early", "late"])
    }

    @Test("a body that is not an array is a bad response", arguments: ["{}", "null", "<html/>", ""])
    func rejectsNonArray(body: String) {
        #expect(throws: KretaError.badResponse) {
            try Lesson.decodeList(Data(body.utf8))
        }
    }

    @Test("parses the timestamp shapes KRÉTA uses")
    func parsesDates() {
        let winter = Fixture.date(16, 8)
        #expect(KretaDate.parse("2026-11-16T07:00:00Z") == winter)
        #expect(KretaDate.parse("2026-11-16T07:00:00.000Z") == winter)
        #expect(KretaDate.parse("2026-11-16T08:00:00+01:00") == winter)
        #expect(KretaDate.parse("2026-11-16T08:00:00+0100") == winter)
        #expect(KretaDate.parse("2026-11-16T02:00:00-05:00") == winter)
        #expect(KretaDate.parse("2026-11-16T08:00:00") == winter)
        #expect(KretaDate.parse(" 2026-11-16 08:00:00 ") == winter)
        // Summer time: Budapest is two hours ahead of UTC.
        #expect(KretaDate.timeString(KretaDate.parse("2026-06-01T06:00:00Z")!) == "8:00")
    }

    @Test(
        "rejects malformed timestamps",
        arguments: ["", "2026-11-16", "2026-13-16T08:00:00Z", "2026-11-31T08:00:00Z", "2026-11-16T25:00:00Z",
                    "2026-11-16T08:00:00X", "2026-11-16T08:00:00+1", "2026-11-16T08:00:00+99:00",
                    "20261116T080000Z", "+026-11-16T08:00:00Z"]
    )
    func rejectsMalformedDate(raw: String) {
        #expect(KretaDate.parse(raw) == nil)
    }

    @Test("day helpers work in school time")
    func dayHelpers() {
        // 23:30 UTC on the 15th is already the 16th in Budapest.
        let lateEvening = KretaDate.parse("2026-11-15T23:30:00Z")!
        #expect(KretaDate.dayString(lateEvening) == "2026-11-16")
        #expect(KretaDate.timeString(lateEvening) == "0:30")
        #expect(KretaDate.isSameDay(lateEvening, Fixture.date(16, 12)))
        #expect(KretaDate.days(from: Fixture.date(16, 23), to: Fixture.date(17, 1)) == 1)
        #expect(KretaDate.days(from: Fixture.date(17), to: Fixture.date(16)) == -1)
        #expect(KretaDate.addingDays(2, to: Fixture.date(16)) == Fixture.date(18))
    }
}
