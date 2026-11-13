package hu.kretaora.core

import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.ChangeFormatter
import hu.kretaora.core.timetable.TimetableChange
import hu.kretaora.core.timetable.TimetableChange.Kind
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ChangeFormatterTest {
    /** Monday 7:00. */
    private val now = Fixture.date(16, 7)
    private val formatter = ChangeFormatter(now)
    private val today = Fixture.lesson("t", day = 16, index = 3)
    private val tomorrow = Fixture.lesson("m", day = 17, index = 1)
    private val friday = Fixture.lesson("f", day = 20, index = 2, name = "angol nyelv")

    @Test
    fun cancellation() {
        val change = TimetableChange(Kind.CANCELLED, tomorrow, tomorrow)
        assertEquals("Elmarad: Matematika", formatter.title(change))
        assertEquals("Holnap, 1. óra, 8:00–8:45", formatter.body(change))
    }

    @Test
    fun `day labels are today, tomorrow, then weekday with date`() {
        assertEquals("Ma", ChangeFormatter.dayLabel(today.start, now))
        assertEquals("Holnap", ChangeFormatter.dayLabel(tomorrow.start, now))
        assertEquals("péntek (nov. 20.)", ChangeFormatter.dayLabel(friday.start, now))
        assertEquals("péntek (nov. 20.), 2. óra, 8:55–9:40", ChangeFormatter.timing(friday, now))
    }

    @Test
    fun `a lesson without a number shows only the time`() {
        val lesson = Lesson(id = "u", start = Fixture.date(16, 14), end = Fixture.date(16, 15, 30), name = "szakkör")
        assertEquals("Ma, 14:00–15:30", ChangeFormatter.timing(lesson, now))
    }

    @Test
    fun `substitution names the substitute and the room`() {
        val substituted = Fixture.lesson("m", day = 17, index = 1, substitute = "Nagy Anna")
        val change = TimetableChange(Kind.TEACHER, substituted, tomorrow)
        assertEquals("Helyettesítés: Matematika", formatter.title(change))
        assertEquals("Holnap, 1. óra, 8:00–8:45 · helyettesít: Nagy Anna · terem: 12", formatter.body(change))
    }

    @Test
    fun `withdrawn substitution and plain teacher change have their own titles`() {
        val substituted = Fixture.lesson("m", day = 17, index = 1, substitute = "Nagy Anna")
        val withdrawn = TimetableChange(Kind.TEACHER, tomorrow, substituted)
        assertEquals("Helyettesítés visszavonva: Matematika", formatter.title(withdrawn))
        assertTrue(formatter.body(withdrawn).contains("tanár: Kiss Béla"))

        val other = Fixture.lesson("m", day = 17, index = 1, teacher = "Szabó Pál")
        val changed = TimetableChange(Kind.TEACHER, other, tomorrow)
        assertEquals("Tanárváltozás: Matematika", formatter.title(changed))
    }

    @Test
    fun `room change shows both rooms`() {
        val moved = Fixture.lesson("m", day = 17, index = 1, room = "204")
        val change = TimetableChange(Kind.ROOM, moved, tomorrow)
        assertEquals("Teremcsere: Matematika", formatter.title(change))
        assertEquals("Holnap, 1. óra, 8:00–8:45 · terem: 204 (eddig: 12)", formatter.body(change))

        val roomless = Fixture.lesson("m", day = 17, index = 1, room = null)
        val assigned = TimetableChange(Kind.ROOM, moved, roomless)
        assertTrue(formatter.body(assigned).endsWith("terem: 204"))
        val unassigned = TimetableChange(Kind.ROOM, roomless, tomorrow)
        assertTrue(formatter.body(unassigned).endsWith("terem: nincs megadva (eddig: 12)"))
    }

    @Test
    fun `time change shows the old slot`() {
        val moved = Fixture.lesson("m", day = 17, index = 3)
        val change = TimetableChange(Kind.TIME, moved, tomorrow)
        assertEquals("Időpont változott: Matematika", formatter.title(change))
        assertEquals("Holnap, 3. óra, 9:50–10:35 · eddig: Holnap, 1. óra, 8:00–8:45", formatter.body(change))
    }

    @Test
    fun `added, removed and restored`() {
        val added = TimetableChange(Kind.ADDED, friday)
        assertEquals("Új óra: Angol nyelv", formatter.title(added))
        assertEquals("péntek (nov. 20.), 2. óra, 8:55–9:40 · terem: 12 · Kiss Béla", formatter.body(added))
        assertEquals("Törölt óra: Matematika", formatter.title(TimetableChange(Kind.REMOVED, today)))
        assertEquals("Mégis megtartják: Matematika", formatter.title(TimetableChange(Kind.RESTORED, today)))
        assertEquals("Ma, 3. óra, 9:50–10:35", formatter.body(TimetableChange(Kind.RESTORED, today)))
    }

    @Test
    fun `many changes collapse into one summary`() {
        val sameDay = listOf(today, Fixture.lesson("t2", day = 16, index = 4))
            .map { TimetableChange(Kind.CANCELLED, it) }
        assertEquals("2 órarendváltozás", formatter.summary(sameDay).title)
        assertEquals("Ma: nyisd meg a részletekért.", formatter.summary(sameDay).body)

        val mixed = listOf(today, tomorrow, friday, today).map { TimetableChange(Kind.CANCELLED, it) }
        assertEquals("4 órarendváltozás", formatter.summary(mixed).title)
        assertEquals("Ma, Holnap, péntek (nov. 20.)", formatter.summary(mixed).body)
    }
}
