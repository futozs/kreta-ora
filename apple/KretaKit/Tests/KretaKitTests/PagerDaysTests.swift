import Foundation
import Testing
@testable import KretaKit

@Suite("Pager days")
struct PagerDaysTests {
    private let first = Fixture.lesson("mon-1", day: 16, index: 1)

    @Test("the pager lists every weekday and only the weekend days that have a lesson")
    func weekendOnlyWithLessons() {
        // Monday the 16th to Sunday the 22nd. Lessons on Monday and on Saturday;
        // Sunday holds only an event.
        let saturday = Fixture.lesson("sat", day: 21, index: 1)
        let sundayEvent = Fixture.lesson("sun", day: 22, index: 1, kind: .event)
        let days = Fixture.snapshot([first, saturday, sundayEvent], from: 16, to: 23).pagerDays()

        #expect(days == (16...21).map { Fixture.date($0) })
    }

    @Test("a weekday without lessons stays in the pager, and an empty window is empty")
    func emptyWeekdaysStay() {
        let days = Fixture.snapshot([], from: 16, to: 23).pagerDays()
        #expect(days == (16...20).map { Fixture.date($0) })
        #expect(Fixture.snapshot([], from: 16, to: 16).pagerDays().isEmpty)
    }
}
