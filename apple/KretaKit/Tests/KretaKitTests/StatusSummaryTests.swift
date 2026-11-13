import Foundation
import Testing
@testable import KretaKit

@Suite("Status and day summaries")
struct StatusSummaryTests {
    // Monday: 1st and 3rd take place, the 2nd is cancelled.
    // Tuesday: two lessons, the second with a substitute. Next Monday: one lesson.
    private let first = Fixture.lesson("mon-1", day: 16, index: 1)
    private let cancelled = Fixture.lesson("mon-2", day: 16, index: 2, name: "fizika", cancelled: true)
    private let third = Fixture.lesson("mon-3", day: 16, index: 3, name: "történelem")
    private let tuesdayFirst = Fixture.lesson("tue-1", day: 17, index: 1, name: "angol nyelv")
    private let tuesdaySecond = Fixture.lesson("tue-2", day: 17, index: 2, name: "kémia", substitute: "Nagy Anna")
    private let nextMonday = Fixture.lesson("next-mon", day: 23, index: 1)

    private var schedule: Schedule {
        Schedule(lessons: [first, cancelled, third, tuesdayFirst, tuesdaySecond, nextMonday])
    }

    private func summary(_ day: Int, _ hour: Int, _ minute: Int = 0) -> StatusSummary {
        StatusSummary(schedule: schedule, now: Fixture.date(day, hour, minute))
    }

    @Test("before school it counts down to the first lesson")
    func beforeFirst() {
        let summary = summary(16, 7, 30)
        #expect(summary.label == "Első óra")
        #expect(summary.lesson == first)
        #expect(summary.countdownTo == first.start)
        #expect(!summary.isInLesson)
        #expect(summary.following == third)
    }

    @Test("during a lesson it counts down to the bell")
    func inLesson() {
        let summary = summary(16, 8, 10)
        #expect(summary.label == "Most")
        #expect(summary.lesson == first)
        #expect(summary.countdownTo == first.end)
        #expect(summary.isInLesson)
        #expect(summary.following == third)
    }

    @Test("in a break it shows what comes next")
    func breakTime() {
        let summary = summary(16, 9, 0)
        #expect(summary.label == "Következik")
        #expect(summary.lesson == third)
        #expect(summary.countdownTo == third.start)
        #expect(summary.following == nil)
    }

    @Test("after school it names the next school day")
    func dayOver() {
        let evening = summary(16, 18)
        #expect(evening.label == "Holnap")
        #expect(evening.lesson == tuesdayFirst)
        #expect(evening.countdownTo == nil)
        #expect(evening.following == tuesdaySecond)

        #expect(summary(17, 18).label == "Hétfő")
        #expect(summary(14, 10).label == "Hétfő")
        #expect(summary(10, 10).label == "Hétfő")
        #expect(StatusSummary.dayName(nextMonday.start, relativeTo: Fixture.date(16, 7)) == "Hétfő, nov. 23.")
    }

    @Test("with nothing ahead it says so")
    func nothingAhead() {
        let summary = summary(23, 12)
        #expect(summary.label == "Nincs több óra")
        #expect(summary.lesson == nil)
        #expect(summary.countdownTo == nil)
        #expect(summary.following == nil)
    }

    @Test("a day summary counts what takes place and what does not")
    func daySummary() {
        let monday = schedule.summary(of: Fixture.date(16, 12))
        #expect(monday.day == Fixture.date(16))
        #expect(monday.lessons.count == 3)
        #expect(monday.active.map(\.id) == ["mon-1", "mon-3"])
        #expect(monday.first == first)
        #expect(monday.last == third)
        #expect(monday.cancelledCount == 1)
        #expect(monday.substitutedCount == 0)
        #expect(monday.span == "8:00–10:35 · 2 óra")

        let tuesday = schedule.summary(of: Fixture.date(17))
        #expect(tuesday.substitutedCount == 1)

        let empty = schedule.summary(of: Fixture.date(18))
        #expect(empty.first == nil)
        #expect(empty.span == nil)
    }

    @Test("the next school day skips days without lessons")
    func nextSchoolDay() {
        #expect(schedule.nextSchoolDay(after: Fixture.date(16, 7))?.day == Fixture.date(17))
        #expect(schedule.nextSchoolDay(after: Fixture.date(17, 7))?.day == Fixture.date(23))
        #expect(schedule.nextSchoolDay(after: Fixture.date(23, 7)) == nil)
    }

    @Test("the focus day is today until the last bell, then the next school day")
    func focusDay() {
        #expect(schedule.focusDay(at: Fixture.date(16, 7))?.day == Fixture.date(16))
        #expect(schedule.focusDay(at: Fixture.date(16, 10, 34))?.day == Fixture.date(16))
        #expect(schedule.focusDay(at: Fixture.date(16, 10, 35))?.day == Fixture.date(17))
        #expect(schedule.focusDay(at: Fixture.date(18, 9))?.day == Fixture.date(23))
        #expect(schedule.focusDay(at: Fixture.date(23, 9)) == nil)
    }

    @Test("upcoming days start today and honour the limit")
    func upcomingDays() {
        let days = schedule.upcomingDays(from: Fixture.date(16, 20))
        #expect(days.map(\.day) == [Fixture.date(16), Fixture.date(17), Fixture.date(23)])
        #expect(schedule.upcomingDays(from: Fixture.date(17, 0), limit: 1).map(\.day) == [Fixture.date(17)])
        #expect(schedule.upcomingDays(from: Fixture.date(24)).isEmpty)
    }

    @Test("the watch window keeps only the coming days")
    func window() {
        let snapshot = Fixture.snapshot([first, cancelled, third, tuesdayFirst, tuesdaySecond, nextMonday], from: 9, to: 30)
        let window = snapshot.window(from: Fixture.date(17, 9), days: 3)
        #expect(window.lessons.map(\.id) == ["tue-1", "tue-2"])
        #expect(window.rangeStart == Fixture.date(17))
        #expect(window.rangeEnd == Fixture.date(20))
        #expect(window.accountID == snapshot.accountID)
        #expect(window.syncedAt == snapshot.syncedAt)

        // A window beyond the data is empty, not inverted.
        let beyond = snapshot.window(from: Fixture.date(30, 9), days: 3)
        #expect(beyond.lessons.isEmpty)
        #expect(beyond.rangeStart <= beyond.rangeEnd)
    }

    @Test("date names are Hungarian")
    func dateNames() {
        #expect(KretaDate.weekdayName(Fixture.date(16)) == "hétfő")
        #expect(KretaDate.shortDate(Fixture.date(16)) == "nov. 16.")
        #expect("ének-zene".capitalizedFirst == "Ének-zene")
        #expect("".capitalizedFirst == "")
    }
}
