package hu.kretaora.core

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.ScheduleStatus
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Duration
import java.time.LocalDate

class ScheduleTest {
    // Monday: 1st 8:00–8:45, 2nd 8:55–9:40 (cancelled), 3rd 9:50–10:35.
    // Tuesday: one lesson, the 2nd, at 8:55.
    // Wednesday: a holiday event only.
    private val first = Fixture.lesson("mon-1", day = 16, index = 1)
    private val cancelled = Fixture.lesson("mon-2", day = 16, index = 2, name = "fizika", cancelled = true)
    private val third = Fixture.lesson("mon-3", day = 16, index = 3, name = "történelem")
    private val tuesday = Fixture.lesson("tue-2", day = 17, index = 2, name = "angol nyelv")
    private val holiday = Fixture.lesson("wed-event", day = 18, index = 1, name = "őszi szünet", kind = Lesson.Kind.EVENT)

    private val schedule = Schedule(listOf(tuesday, third, holiday, cancelled, first))

    @Test
    fun `sorts entries and tells lessons from events`() {
        assertEquals(listOf("mon-1", "mon-2", "mon-3", "tue-2", "wed-event"), schedule.entries.map { it.id })
        assertEquals(listOf("mon-1", "mon-2", "mon-3", "tue-2"), schedule.lessons.map { it.id })
        assertEquals(listOf("mon-1", "mon-3", "tue-2"), schedule.activeLessons.map { it.id })
    }

    @Test
    fun `lists a day with its cancelled lessons, and its events separately`() {
        assertEquals(listOf("mon-1", "mon-2", "mon-3"), schedule.lessonsOn(Fixture.date(16, 12)).map { it.id })
        assertEquals(listOf("mon-1", "mon-2", "mon-3"), schedule.lessonsOn(LocalDate.of(2026, 11, 16)).map { it.id })
        assertTrue(schedule.lessonsOn(Fixture.date(18)).isEmpty())
        assertEquals(listOf("wed-event"), schedule.eventsOn(Fixture.date(18, 9)).map { it.id })
        assertEquals(first, schedule.firstLessonOn(Fixture.date(16)))
        assertEquals(third, schedule.lastLessonOn(Fixture.date(16)))
        assertNull(schedule.firstLessonOn(Fixture.date(18)))
    }

    @Test
    fun `before the first lesson`() {
        assertEquals(ScheduleStatus.BeforeFirst(first), schedule.status(Fixture.date(16, 7, 30)))
        assertEquals(first, schedule.nextLesson(Fixture.date(16, 7, 30)))
        assertNull(schedule.currentLesson(Fixture.date(16, 7, 30)))
    }

    @Test
    fun `during a lesson, the next one skips the cancelled lesson`() {
        assertEquals(ScheduleStatus.InLesson(first, third), schedule.status(Fixture.date(16, 8, 0)))
        assertEquals(ScheduleStatus.InLesson(first, third), schedule.status(Fixture.date(16, 8, 44)))
        assertEquals(first, schedule.currentLesson(Fixture.date(16, 8, 10)))
    }

    @Test
    fun `a cancelled lesson turns into a long break`() {
        assertEquals(ScheduleStatus.BreakTime(third), schedule.status(Fixture.date(16, 8, 45)))
        assertEquals(ScheduleStatus.BreakTime(third), schedule.status(Fixture.date(16, 9, 10)))
        assertNull(schedule.currentLesson(Fixture.date(16, 9, 10)))
    }

    @Test
    fun `the last lesson of the day has no next`() {
        assertEquals(ScheduleStatus.InLesson(third, null), schedule.status(Fixture.date(16, 10, 0)))
    }

    @Test
    fun `after school it points at tomorrow's first real lesson`() {
        assertEquals(ScheduleStatus.DayOver(tuesday), schedule.status(Fixture.date(16, 10, 35)))
        assertEquals(tuesday, schedule.firstLessonOfNextSchoolDay(Fixture.date(16, 7)))
    }

    @Test
    fun `a day without lessons looks ahead, and the end of the data is null`() {
        assertEquals(ScheduleStatus.DayOver(first), schedule.status(Fixture.date(15, 12)))
        assertEquals(ScheduleStatus.DayOver(null), schedule.status(Fixture.date(18, 12)))
        assertNull(schedule.nextLesson(Fixture.date(18, 12)))
        assertEquals(ScheduleStatus.DayOver(null), Schedule(emptyList()).status(Fixture.date(16, 9)))
    }

    @Test
    fun `widget refresh moments are now, each boundary, and midnight`() {
        val now = Fixture.date(16, 7, 30)
        val dates = schedule.refreshDates(now, horizon = Duration.ofHours(24))
        assertEquals(
            listOf(now, first.start, first.end, third.start, third.end, Fixture.date(17)),
            dates,
        )
    }

    @Test
    fun `refresh moments respect the limit and never include the past`() {
        val now = Fixture.date(16, 9, 0)
        val dates = schedule.refreshDates(now, limit = 3)
        assertEquals(listOf(now, third.start, third.end), dates)
        assertTrue(dates.drop(1).all { it > now })
    }

    @Test
    fun `the sync window is last week through two weeks ahead`() {
        // Wednesday the 18th belongs to the week starting Monday the 16th.
        val (from, to) = Schedule.syncRange(Fixture.date(18, 14))
        assertEquals("2026-11-09", from.toString())
        assertEquals("2026-12-06", to.toString())
        assertEquals("2026-11-09", KretaDate.dayString(KretaDate.startOfDay(from)))
        // Sunday still belongs to the week that started the previous Monday.
        assertEquals("2026-11-09", Schedule.syncRange(Fixture.date(22, 23)).first.toString())
        assertEquals("2026-11-16", Schedule.syncRange(Fixture.date(23, 0)).first.toString())
    }
}
