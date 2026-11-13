import Foundation
import Testing
@testable import KretaKit

@Suite("Day plan, next lesson and live day")
struct DayPlanTests {
    // Monday: 1st, 2nd (cancelled), 3rd, then 5th after a long gap.
    private let first = Fixture.lesson("mon-1", day: 16, index: 1)
    private let cancelled = Fixture.lesson("mon-2", day: 16, index: 2, name: "fizika", cancelled: true)
    private let third = Fixture.lesson("mon-3", day: 16, index: 3, name: "történelem")
    private let fifth = Fixture.lesson("mon-5", day: 16, index: 5, name: "kémia")
    private let tuesday = Fixture.lesson("tue-1", day: 17, index: 1, name: "angol nyelv")

    private var schedule: Schedule { Schedule(lessons: [first, cancelled, third, fifth, tuesday]) }

    @Test("rows carry modes and a gap note for long breaks only")
    func rows() {
        let rows = DayPlan.rows(schedule, day: Fixture.date(16), now: Fixture.date(16, 8, 10))
        #expect(rows == [
            .block(first, .running),
            .block(cancelled, .upcoming),
            .block(third, .upcoming),
            .gap(minutes: 65, after: "mon-3"),
            .block(fifth, .upcoming),
        ])
    }

    @Test("in a break the next lesson today is up next, earlier ones are past")
    func upNext() {
        let rows = DayPlan.rows(schedule, day: Fixture.date(16), now: Fixture.date(16, 9, 0))
        #expect(rows.first == .block(first, .past))
        #expect(rows.contains(.block(third, .upNext)))
        // Tomorrow's first lesson is never "up next" from today.
        let evening = DayPlan.rows(schedule, day: Fixture.date(17), now: Fixture.date(16, 18))
        #expect(evening == [.block(tuesday, .upcoming)])
    }

    @Test("the pager opens on today until the last bell, then on the next school day")
    func initialIndex() {
        let days = (16...20).map { Fixture.date($0) }
        #expect(DayPlan.initialIndex(of: days, schedule: schedule, now: Fixture.date(16, 7)) == 0)
        #expect(DayPlan.initialIndex(of: days, schedule: schedule, now: Fixture.date(16, 18)) == 1)
        #expect(DayPlan.initialIndex(of: days, schedule: nil, now: Fixture.date(18, 9)) == 2)
    }

    @Test("a cancelled lesson only warns while it is ahead")
    func cancellationAhead() {
        #expect(DayPlan.hasCancellationAhead(schedule, on: Fixture.date(16), now: Fixture.date(16, 7)))
        #expect(!DayPlan.hasCancellationAhead(schedule, on: Fixture.date(16), now: Fixture.date(16, 12)))
    }

    @Test("the next lesson counts down within an hour of its start, the same day only")
    func nextLessonPhase() {
        #expect(NextLessonModel(schedule: schedule, now: Fixture.date(16, 8, 10))?.phase == .running)
        let soon = NextLessonModel(schedule: schedule, now: Fixture.date(16, 7, 10))
        #expect(soon?.phase == .soon)
        #expect(soon?.countdownTarget == first.start)
        #expect(soon?.following.map(\.id) == ["mon-2", "mon-3", "mon-5"])
        #expect(NextLessonModel(schedule: schedule, now: Fixture.date(16, 6, 30))?.phase == .later)
        #expect(NextLessonModel(schedule: schedule, now: Fixture.date(16, 23))?.phase == .later)
        #expect(NextLessonModel(schedule: schedule, now: Fixture.date(17, 12)) == nil)
    }

    @Test("the live day starts an hour before the first lesson and ends with the last")
    func liveDay() {
        #expect(LiveDay(schedule: schedule, now: Fixture.date(16, 6, 59)) == nil)
        let early = LiveDay(schedule: schedule, now: Fixture.date(16, 7, 0))
        #expect(early?.focus == first)
        #expect(early?.isRunning == false)
        #expect(early?.lessons.count == 4)
        let running = LiveDay(schedule: schedule, now: Fixture.date(16, 10, 0))
        #expect(running?.focus == third)
        #expect(running?.target == third.end)
        #expect(LiveDay(schedule: schedule, now: fifth.end) == nil)
        #expect(LiveDay.window(schedule, on: Fixture.date(16))?.lowerBound == Fixture.date(16, 7))
    }

    @Test("the day start is today before the first bell, otherwise the next school day")
    func dayStart() {
        #expect(DayPlan.dayStart(schedule, now: Fixture.date(16, 7))?.day == Fixture.date(16))
        #expect(DayPlan.dayStart(schedule, now: Fixture.date(16, 8, 1))?.day == Fixture.date(17))
    }
}
