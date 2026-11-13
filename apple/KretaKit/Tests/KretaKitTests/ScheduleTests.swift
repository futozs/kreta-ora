import Foundation
import Testing
@testable import KretaKit

@Suite("Schedule")
struct ScheduleTests {
    // Monday: 1st 8:00–8:45, 2nd 8:55–9:40 (cancelled), 3rd 9:50–10:35.
    // Tuesday: a free-slot placeholder, then the 2nd lesson at 8:55.
    // Wednesday: a holiday event only.
    private let first = Fixture.lesson("mon-1", day: 16, index: 1)
    private let cancelled = Fixture.lesson("mon-2", day: 16, index: 2, name: "fizika", cancelled: true)
    private let third = Fixture.lesson("mon-3", day: 16, index: 3, name: "történelem")
    private let placeholder = Fixture.lesson("tue-1", day: 17, index: 1, kind: .empty)
    private let tuesday = Fixture.lesson("tue-2", day: 17, index: 2, name: "angol nyelv")
    private let holiday = Fixture.lesson("wed-event", day: 18, index: 1, name: "őszi szünet", kind: .event)

    private var schedule: Schedule {
        Schedule(lessons: [tuesday, third, holiday, placeholder, cancelled, first])
    }

    @Test("sorts entries and drops free-slot placeholders")
    func normalizes() {
        #expect(schedule.entries.map(\.id) == ["mon-1", "mon-2", "mon-3", "tue-2", "wed-event"])
        #expect(schedule.lessons.map(\.id) == ["mon-1", "mon-2", "mon-3", "tue-2"])
        #expect(schedule.activeLessons.map(\.id) == ["mon-1", "mon-3", "tue-2"])
    }

    @Test("lists a day with its cancelled lessons, and its events separately")
    func listsDay() {
        #expect(schedule.lessons(on: Fixture.date(16, 12)).map(\.id) == ["mon-1", "mon-2", "mon-3"])
        #expect(schedule.lessons(on: Fixture.date(18)).isEmpty)
        #expect(schedule.events(on: Fixture.date(18, 9)).map(\.id) == ["wed-event"])
        #expect(schedule.firstLesson(on: Fixture.date(16)) == first)
        #expect(schedule.lastLesson(on: Fixture.date(16)) == third)
        #expect(schedule.firstLesson(on: Fixture.date(18)) == nil)
    }

    @Test("before the first lesson")
    func beforeFirst() {
        #expect(schedule.status(at: Fixture.date(16, 7, 30)) == .beforeFirst(first: first))
        #expect(schedule.nextLesson(after: Fixture.date(16, 7, 30)) == first)
        #expect(schedule.currentLesson(at: Fixture.date(16, 7, 30)) == nil)
    }

    @Test("during a lesson, the next one skips the cancelled lesson")
    func inLesson() {
        #expect(schedule.status(at: Fixture.date(16, 8, 0)) == .inLesson(current: first, next: third))
        #expect(schedule.status(at: Fixture.date(16, 8, 44)) == .inLesson(current: first, next: third))
        #expect(schedule.currentLesson(at: Fixture.date(16, 8, 10)) == first)
    }

    @Test("a cancelled lesson turns into a long break")
    func breakTime() {
        #expect(schedule.status(at: Fixture.date(16, 8, 45)) == .breakTime(next: third))
        #expect(schedule.status(at: Fixture.date(16, 9, 10)) == .breakTime(next: third))
        #expect(schedule.currentLesson(at: Fixture.date(16, 9, 10)) == nil)
    }

    @Test("the last lesson of the day has no next")
    func lastLesson() {
        #expect(schedule.status(at: Fixture.date(16, 10, 0)) == .inLesson(current: third, next: nil))
    }

    @Test("after school it points at tomorrow's first real lesson")
    func dayOver() {
        #expect(schedule.status(at: Fixture.date(16, 10, 35)) == .dayOver(nextFirst: tuesday))
        #expect(schedule.firstLessonOfNextSchoolDay(after: Fixture.date(16, 7)) == tuesday)
    }

    @Test("a day without lessons looks ahead, and the end of the data is nil")
    func freeDay() {
        #expect(schedule.status(at: Fixture.date(15, 12)) == .dayOver(nextFirst: first))
        #expect(schedule.status(at: Fixture.date(18, 12)) == .dayOver(nextFirst: nil))
        #expect(schedule.nextLesson(after: Fixture.date(18, 12)) == nil)
        #expect(Schedule(lessons: []).status(at: Fixture.date(16, 9)) == .dayOver(nextFirst: nil))
    }

    @Test("widget refresh moments are now, each boundary, and midnight")
    func refreshDates() {
        let now = Fixture.date(16, 7, 30)
        let dates = schedule.refreshDates(from: now, horizon: 24 * 3600)
        #expect(dates == [
            now,
            first.start, first.end, third.start, third.end,
            Fixture.date(17),
        ])
    }

    @Test("refresh moments respect the limit and never include the past")
    func refreshDatesLimit() {
        let now = Fixture.date(16, 9, 0)
        let dates = schedule.refreshDates(from: now, limit: 3)
        #expect(dates == [now, third.start, third.end])
        #expect(dates.dropFirst().allSatisfy { $0 > now })
    }

    @Test("the sync window is last week through two weeks ahead")
    func syncRange() {
        // Wednesday the 18th belongs to the week starting Monday the 16th.
        let range = Schedule.syncRange(containing: Fixture.date(18, 14))
        #expect(KretaDate.dayString(range.from) == "2026-11-09")
        #expect(KretaDate.dayString(range.to) == "2026-12-06")
        // Sunday still belongs to the week that started the previous Monday.
        #expect(KretaDate.dayString(Schedule.syncRange(containing: Fixture.date(22, 23)).from) == "2026-11-09")
        #expect(KretaDate.dayString(Schedule.syncRange(containing: Fixture.date(23, 0)).from) == "2026-11-16")
    }
}
