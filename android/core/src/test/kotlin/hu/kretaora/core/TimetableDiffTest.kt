package hu.kretaora.core

import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.TimetableChange
import hu.kretaora.core.timetable.TimetableChange.Kind
import hu.kretaora.core.timetable.TimetableDiff
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Instant

class TimetableDiffTest {
    /** Monday 7:00, before any lesson of the fixture week. */
    private val now = Fixture.date(16, 7)
    private val maths = Fixture.lesson("a", day = 17, index = 1)
    private val physics = Fixture.lesson("b", day = 17, index = 2, name = "fizika")

    private fun diff(old: List<Lesson>?, new: List<Lesson>, at: Instant = now): List<TimetableChange> =
        TimetableDiff.changes(old?.let { Fixture.snapshot(it) }, Fixture.snapshot(new), at)

    @Test
    fun `the first sync is a silent baseline`() {
        assertTrue(diff(null, listOf(maths, physics)).isEmpty())
    }

    @Test
    fun `an unchanged timetable is silent`() {
        assertTrue(diff(listOf(maths, physics), listOf(physics, maths)).isEmpty())
    }

    @Test
    fun `another account's snapshot is not a baseline`() {
        val changes = TimetableDiff.changes(
            Fixture.snapshot(listOf(maths), account = "someone-else"),
            Fixture.snapshot(emptyList()),
            now,
        )
        assertTrue(changes.isEmpty())
    }

    @Test
    fun `a cancellation is reported once`() {
        val cancelled = Fixture.lesson("a", day = 17, index = 1, cancelled = true)
        val changes = diff(listOf(maths, physics), listOf(cancelled, physics))
        assertEquals(listOf(TimetableChange(Kind.CANCELLED, cancelled, maths)), changes)
        assertTrue(diff(listOf(cancelled, physics), listOf(cancelled, physics)).isEmpty())
    }

    @Test
    fun `a cancelled lesson that is held after all is reported`() {
        val cancelled = Fixture.lesson("a", day = 17, index = 1, cancelled = true)
        assertEquals(listOf(Kind.RESTORED), diff(listOf(cancelled), listOf(maths)).map { it.kind })
    }

    @Test
    fun `a substitute teacher is reported, and so is its withdrawal`() {
        val substituted = Fixture.lesson("a", day = 17, index = 1, substitute = "Nagy Anna")
        assertEquals(
            listOf(TimetableChange(Kind.TEACHER, substituted, maths)),
            diff(listOf(maths), listOf(substituted)),
        )
        assertEquals(listOf(Kind.TEACHER), diff(listOf(substituted), listOf(maths)).map { it.kind })
    }

    @Test
    fun `a room change is reported`() {
        val moved = Fixture.lesson("a", day = 17, index = 1, room = "204")
        assertEquals(listOf(Kind.ROOM), diff(listOf(maths), listOf(moved)).map { it.kind })
    }

    @Test
    fun `a time change outranks teacher and room changes`() {
        val later = maths.copy(
            start = maths.start.plusSeconds(600),
            end = maths.end.plusSeconds(600),
            teacher = "Valaki Más",
            room = "204",
        )
        assertEquals(listOf(Kind.TIME), diff(listOf(maths), listOf(later)).map { it.kind })
    }

    @Test
    fun `changes to an already cancelled lesson are ignored`() {
        val before = Fixture.lesson("a", day = 17, index = 1, room = "12", cancelled = true)
        val after = Fixture.lesson("a", day = 17, index = 1, room = "204", cancelled = true)
        assertTrue(diff(listOf(before), listOf(after)).isEmpty())
    }

    @Test
    fun `a topic the teacher filled in is not a change`() {
        val withTopic = Fixture.lesson("a", day = 17, index = 1, topic = "Másodfokú egyenletek")
        assertTrue(diff(listOf(maths), listOf(withTopic)).isEmpty())
    }

    @Test
    fun `lessons that already ended never notify`() {
        val cancelled = Fixture.lesson("a", day = 17, index = 1, cancelled = true)
        assertTrue(diff(listOf(maths), listOf(cancelled), at = maths.end).isEmpty())
        assertTrue(diff(listOf(maths), emptyList(), at = maths.end).isEmpty())
        // Still running: the student may be on the way.
        assertEquals(1, diff(listOf(maths), listOf(cancelled), at = maths.start.plusSeconds(60)).size)
    }

    @Test
    fun `a lesson added inside the known window is reported`() {
        val extra = Fixture.lesson("c", day = 18, index = 5, name = "kémia")
        assertEquals(listOf(TimetableChange(Kind.ADDED, extra)), diff(listOf(maths), listOf(maths, extra)))
    }

    @Test
    fun `a week rolling into view is silent`() {
        val nextWeek = Fixture.lesson("z", day = 26, index = 1)
        val changes = TimetableDiff.changes(
            Fixture.snapshot(listOf(maths), from = 16, to = 23),
            Fixture.snapshot(listOf(maths, nextWeek), from = 16, to = 30),
            now,
        )
        assertTrue(changes.isEmpty())
    }

    @Test
    fun `a lesson removed from the timetable is reported`() {
        assertEquals(listOf(TimetableChange(Kind.REMOVED, maths)), diff(listOf(maths, physics), listOf(physics)))
    }

    @Test
    fun `a lesson that fell out of the fetched window is not removed`() {
        val far = Fixture.lesson("far", day = 27, index = 1)
        val changes = TimetableDiff.changes(
            Fixture.snapshot(listOf(maths, far), from = 16, to = 30),
            Fixture.snapshot(listOf(maths), from = 16, to = 23),
            now,
        )
        assertTrue(changes.isEmpty())
    }

    @Test
    fun `an identifier change in the same slot is compared as one lesson`() {
        val reissued = Fixture.lesson("a-new", day = 17, index = 1)
        assertTrue(diff(listOf(maths), listOf(reissued)).isEmpty())

        val reissuedWithSubstitute = Fixture.lesson("a-new", day = 17, index = 1, substitute = "Nagy Anna")
        assertEquals(
            listOf(TimetableChange(Kind.TEACHER, reissuedWithSubstitute, maths)),
            diff(listOf(maths), listOf(reissuedWithSubstitute)),
        )
    }

    @Test
    fun `a different subject in the same slot is a removal and an addition`() {
        val replacement = Fixture.lesson("c", day = 17, index = 1, name = "kémia")
        assertEquals(
            setOf(Kind.ADDED, Kind.REMOVED),
            diff(listOf(maths), listOf(replacement)).map { it.kind }.toSet(),
        )
        assertEquals(2, diff(listOf(maths), listOf(replacement)).size)
    }

    @Test
    fun `free-slot placeholders and cancelled leftovers do not notify`() {
        val placeholder = Fixture.lesson("p", day = 17, index = 3, kind = Lesson.Kind.EMPTY)
        val cancelledExtra = Fixture.lesson("x", day = 17, index = 4, cancelled = true)
        assertTrue(diff(listOf(maths), listOf(maths, placeholder, cancelledExtra)).isEmpty())
        assertTrue(diff(listOf(maths, placeholder, cancelledExtra), listOf(maths)).isEmpty())
    }

    @Test
    fun `school-year events are not lessons, so they never notify`() {
        val dayOff = Fixture.lesson("event", day = 18, index = 1, name = "tanítás nélküli munkanap", kind = Lesson.Kind.EVENT)
        assertTrue(diff(listOf(maths), listOf(maths, dayOff)).isEmpty())
        assertTrue(diff(listOf(maths, dayOff), listOf(maths)).isEmpty())
        // An event sharing a slot and a name with a lesson is not that lesson.
        val lookalike = Fixture.lesson("a-event", day = 17, index = 1, kind = Lesson.Kind.EVENT)
        assertEquals(listOf(Kind.REMOVED), diff(listOf(maths), listOf(lookalike)).map { it.kind })
    }

    @Test
    fun `changes come back in timetable order`() {
        val cancelledPhysics = Fixture.lesson("b", day = 17, index = 2, name = "fizika", cancelled = true)
        val movedMaths = Fixture.lesson("a", day = 17, index = 1, room = "204")
        val extra = Fixture.lesson("c", day = 16, index = 6, name = "kémia")
        val changes = diff(listOf(maths, physics), listOf(cancelledPhysics, movedMaths, extra))
        assertEquals(listOf("c", "a", "b"), changes.map { it.lesson.id })
        assertEquals(3, changes.map { it.id }.toSet().size)
    }
}
