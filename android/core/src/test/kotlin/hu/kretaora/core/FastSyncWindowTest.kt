package hu.kretaora.core

import hu.kretaora.core.timetable.FastSyncWindow
import hu.kretaora.core.timetable.Schedule
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class FastSyncWindowTest {
    // Monday the 16th: 1st lesson 8:00, 3rd lesson ends 10:35 (the 2nd is cancelled).
    // Tuesday the 17th: only the 2nd lesson, 8:55–9:40.
    private val monday = listOf(
        Fixture.lesson("mon-1", day = 16, index = 1),
        Fixture.lesson("mon-2", day = 16, index = 2, cancelled = true),
        Fixture.lesson("mon-3", day = 16, index = 3),
    )
    private val tuesday = Fixture.lesson("tue-2", day = 17, index = 2)
    private val schedule = Schedule(monday + tuesday)

    @Test
    fun `before the school day it waits for the window to open, two hours before the first lesson`() {
        assertEquals(Fixture.date(16, 6, 0), FastSyncWindow.next(schedule, Fixture.date(16, 1, 30)))
    }

    @Test
    fun `inside the window it syncs again five minutes later`() {
        assertEquals(Fixture.date(16, 6, 5), FastSyncWindow.next(schedule, Fixture.date(16, 6, 0)))
        assertEquals(Fixture.date(16, 9, 17), FastSyncWindow.next(schedule, Fixture.date(16, 9, 12)))
    }

    @Test
    fun `the window closes with the last lesson that takes place`() {
        // 10:30 is inside; 10:35 is the end of the 3rd lesson.
        assertEquals(Fixture.date(16, 10, 35), FastSyncWindow.next(schedule, Fixture.date(16, 10, 30)))
    }

    @Test
    fun `after school it waits for the next school day's window`() {
        assertEquals(Fixture.date(17, 6, 55), FastSyncWindow.next(schedule, Fixture.date(16, 10, 35)))
        assertEquals(Fixture.date(17, 6, 55), FastSyncWindow.next(schedule, Fixture.date(16, 22, 0)))
    }

    @Test
    fun `with no school day ahead there is nothing to schedule`() {
        assertNull(FastSyncWindow.next(schedule, Fixture.date(17, 9, 40)))
        assertNull(FastSyncWindow.next(Schedule(emptyList()), Fixture.date(16, 9, 0)))
    }

    @Test
    fun `a day of cancelled lessons has no window`() {
        val cancelledDay = Schedule(listOf(Fixture.lesson("x", day = 18, index = 1, cancelled = true), tuesday))
        assertEquals(Fixture.date(17, 6, 55), FastSyncWindow.next(cancelledDay, Fixture.date(16, 12, 0)))
        assertNull(FastSyncWindow.next(cancelledDay, Fixture.date(17, 12, 0)))
    }
}
