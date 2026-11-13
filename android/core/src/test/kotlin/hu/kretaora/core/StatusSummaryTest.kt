package hu.kretaora.core

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.model.capitalizedFirst
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.StatusSummary
import hu.kretaora.core.timetable.focusDay
import hu.kretaora.core.timetable.nextSchoolDay
import hu.kretaora.core.timetable.pagerDays
import hu.kretaora.core.timetable.summaryOf
import hu.kretaora.core.timetable.upcomingDays
import hu.kretaora.core.timetable.window
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDate

class StatusSummaryTest {
    // Monday: 1st and 3rd take place, the 2nd is cancelled.
    // Tuesday: two lessons, the second with a substitute. Next Monday: one lesson.
    private val first = Fixture.lesson("mon-1", day = 16, index = 1)
    private val cancelled = Fixture.lesson("mon-2", day = 16, index = 2, name = "fizika", cancelled = true)
    private val third = Fixture.lesson("mon-3", day = 16, index = 3, name = "történelem")
    private val tuesdayFirst = Fixture.lesson("tue-1", day = 17, index = 1, name = "angol nyelv")
    private val tuesdaySecond = Fixture.lesson("tue-2", day = 17, index = 2, name = "kémia", substitute = "Nagy Anna")
    private val nextMonday = Fixture.lesson("next-mon", day = 23, index = 1)
    private val all = listOf(first, cancelled, third, tuesdayFirst, tuesdaySecond, nextMonday)

    private val schedule = Schedule(all)

    private fun summary(day: Int, hour: Int, minute: Int = 0) =
        StatusSummary.of(schedule, Fixture.date(day, hour, minute))

    @Test
    fun `before school it counts down to the first lesson`() {
        val summary = summary(16, 7, 30)
        assertEquals("Első óra", summary.label)
        assertEquals(first, summary.lesson)
        assertEquals(first.start, summary.countdownTo)
        assertFalse(summary.isInLesson)
        assertEquals(third, summary.following)
    }

    @Test
    fun `during a lesson it counts down to the bell`() {
        val summary = summary(16, 8, 10)
        assertEquals("Most", summary.label)
        assertEquals(first, summary.lesson)
        assertEquals(first.end, summary.countdownTo)
        assertTrue(summary.isInLesson)
        assertEquals(third, summary.following)
    }

    @Test
    fun `in a break it shows what comes next`() {
        val summary = summary(16, 9, 0)
        assertEquals("Következik", summary.label)
        assertEquals(third, summary.lesson)
        assertEquals(third.start, summary.countdownTo)
        assertNull(summary.following)
    }

    @Test
    fun `after school it names the next school day`() {
        val evening = summary(16, 18)
        assertEquals("Holnap", evening.label)
        assertEquals(tuesdayFirst, evening.lesson)
        assertNull(evening.countdownTo)
        assertEquals(tuesdaySecond, evening.following)

        assertEquals("Hétfő", summary(17, 18).label)
        assertEquals("Hétfő", summary(14, 10).label)
        assertEquals("Hétfő", summary(10, 10).label)
        assertEquals("Hétfő, nov. 23.", StatusSummary.dayName(nextMonday.start, Fixture.date(16, 7)))
    }

    @Test
    fun `with nothing ahead it says so`() {
        val summary = summary(23, 12)
        assertEquals("Nincs több óra", summary.label)
        assertNull(summary.lesson)
        assertNull(summary.countdownTo)
        assertNull(summary.following)
    }

    @Test
    fun `a day summary counts what takes place and what does not`() {
        val monday = schedule.summaryOf(Fixture.date(16, 12))
        assertEquals(Fixture.date(16), monday.day)
        assertEquals(3, monday.lessons.size)
        assertEquals(listOf("mon-1", "mon-3"), monday.active.map { it.id })
        assertEquals(first, monday.first)
        assertEquals(third, monday.last)
        assertEquals(1, monday.cancelledCount)
        assertEquals(0, monday.substitutedCount)
        assertEquals("8:00–10:35 · 2 óra", monday.span)

        assertEquals(1, schedule.summaryOf(Fixture.date(17)).substitutedCount)

        val empty = schedule.summaryOf(Fixture.date(18))
        assertNull(empty.first)
        assertNull(empty.span)
    }

    @Test
    fun `the next school day skips days without lessons`() {
        assertEquals(Fixture.date(17), schedule.nextSchoolDay(Fixture.date(16, 7))?.day)
        assertEquals(Fixture.date(23), schedule.nextSchoolDay(Fixture.date(17, 7))?.day)
        assertNull(schedule.nextSchoolDay(Fixture.date(23, 7)))
    }

    @Test
    fun `the focus day is today until the last bell, then the next school day`() {
        assertEquals(Fixture.date(16), schedule.focusDay(Fixture.date(16, 7))?.day)
        assertEquals(Fixture.date(16), schedule.focusDay(Fixture.date(16, 10, 34))?.day)
        assertEquals(Fixture.date(17), schedule.focusDay(Fixture.date(16, 10, 35))?.day)
        assertEquals(Fixture.date(23), schedule.focusDay(Fixture.date(18, 9))?.day)
        assertNull(schedule.focusDay(Fixture.date(23, 9)))
    }

    @Test
    fun `upcoming days start today and honour the limit`() {
        val days = schedule.upcomingDays(Fixture.date(16, 20))
        assertEquals(listOf(Fixture.date(16), Fixture.date(17), Fixture.date(23)), days.map { it.day })
        assertEquals(listOf(Fixture.date(17)), schedule.upcomingDays(Fixture.date(17, 0), limit = 1).map { it.day })
        assertTrue(schedule.upcomingDays(Fixture.date(24)).isEmpty())
    }

    @Test
    fun `the window keeps only the coming days`() {
        val snapshot = Fixture.snapshot(all, from = 9, to = 30)
        val window = snapshot.window(Fixture.date(17, 9), days = 3)
        assertEquals(listOf("tue-1", "tue-2"), window.lessons.map { it.id })
        assertEquals(Fixture.date(17), window.rangeStart)
        assertEquals(Fixture.date(20), window.rangeEnd)
        assertEquals(snapshot.accountId, window.accountId)
        assertEquals(snapshot.syncedAt, window.syncedAt)

        // A window beyond the data is empty, not inverted.
        val beyond = snapshot.window(Fixture.date(30, 9), days = 3)
        assertTrue(beyond.lessons.isEmpty())
        assertTrue(beyond.rangeStart <= beyond.rangeEnd)
    }

    @Test
    fun `date names are Hungarian`() {
        assertEquals("hétfő", KretaDate.weekdayName(KretaDate.localDate(Fixture.date(16))))
        assertEquals("nov. 16.", KretaDate.shortDate(KretaDate.localDate(Fixture.date(16))))
        assertEquals("Ének-zene", "ének-zene".capitalizedFirst())
        assertEquals("", "".capitalizedFirst())
    }

    @Test
    fun `the pager lists every weekday and only the weekend days that have a lesson`() {
        // Monday the 16th to Sunday the 22nd. Lessons on Monday and on Saturday;
        // Sunday holds only an event.
        val saturday = Fixture.lesson("sat", day = 21, index = 1)
        val sundayEvent = Fixture.lesson("sun", day = 22, index = 1, kind = Lesson.Kind.EVENT)
        val days = Fixture.snapshot(listOf(first, saturday, sundayEvent), from = 16, to = 23).pagerDays()

        assertEquals((16..21).map { LocalDate.of(2026, 11, it) }, days)
    }

    @Test
    fun `a weekday without lessons stays in the pager, and an empty window is empty`() {
        val days = Fixture.snapshot(emptyList(), from = 16, to = 23).pagerDays()
        assertEquals((16..20).map { LocalDate.of(2026, 11, it) }, days)
        assertTrue(Fixture.snapshot(emptyList(), from = 16, to = 16).pagerDays().isEmpty())
    }
}
