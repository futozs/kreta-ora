package hu.kretaora.core

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import java.time.LocalDate

class LessonTest {
    private fun decode(vararg rows: String): List<Lesson> =
        Lesson.decodeList(rows.joinToString(",", prefix = "[", postfix = "]").toByteArray())

    @Test
    fun `reads a real-shaped timetable row`() {
        val lesson = decode(Fixture.lessonJson()).first()

        assertEquals("101,TanitasiOra,2026-11-16T07:00:00Z", lesson.id)
        assertEquals(Fixture.date(16, 8, 0), lesson.start)
        assertEquals(Fixture.date(16, 8, 45), lesson.end)
        assertEquals("matematika", lesson.name)
        assertEquals("Matematika", lesson.displayName)
        assertEquals(1, lesson.index)
        assertEquals("Kiss Béla", lesson.teacher)
        assertNull(lesson.substituteTeacher)
        assertEquals("12", lesson.room)
        assertNull(lesson.topic)
        assertEquals("10.A", lesson.group)
        assertEquals(Lesson.Kind.LESSON, lesson.kind)
        assertFalse(lesson.isCancelled)
        assertTrue(lesson.isActive)
        assertTrue(lesson.hasTest)
        assertFalse(lesson.hasHomework)
    }

    @Test
    fun `recognises cancelled and substituted lessons`() {
        val cancelled = decode(Fixture.lessonJson(state = "Elmaradt")).first()
        assertTrue(cancelled.isCancelled)
        assertFalse(cancelled.isActive)

        val substituted = decode(Fixture.lessonJson(substitute = "\"Nagy Anna\"")).first()
        assertTrue(substituted.isSubstituted)
        assertEquals("Nagy Anna", substituted.effectiveTeacher)
    }

    @Test
    fun `an UresOra row is a cancelled lesson, whatever its state says`() {
        val cancelled = decode(Fixture.lessonJson(type = "UresOra")).first()
        assertEquals(Lesson.Kind.LESSON, cancelled.kind)
        assertTrue(cancelled.isCancelled)
        assertEquals("matematika", cancelled.name)
    }

    @Test
    fun `maps school-year events`() {
        assertEquals(Lesson.Kind.EVENT, decode(Fixture.lessonJson(type = "TanevRendjeEsemeny")).first().kind)
    }

    @Test
    fun `accepts a state sent as plain text and a numeric identifier`() {
        val row = """
            {"Uid": 77, "KezdetIdopont": "2026-11-16T08:00:00", "VegIdopont": "2026-11-16T08:45:00",
             "Tantargy": {"Nev": "fizika"}, "Oraszam": "2", "Allapot": "Elmaradt"}
        """.trimIndent()
        val lesson = decode(row).first()
        assertEquals("77", lesson.id)
        assertEquals("fizika", lesson.name)
        assertEquals(2, lesson.index)
        assertTrue(lesson.isCancelled)
        assertEquals(Fixture.date(16, 8), lesson.start)
    }

    @Test
    fun `skips rows it cannot understand and sorts the rest`() {
        val lessons = decode(
            Fixture.lessonJson(uid = "late", start = "2026-11-16T09:00:00Z", end = "2026-11-16T09:45:00Z"),
            """{"Uid": "no-times"}""",
            """{"Uid": "backwards", "KezdetIdopont": "2026-11-16T09:00:00Z", "VegIdopont": "2026-11-16T08:00:00Z"}""",
            "42",
            Fixture.lessonJson(uid = "early"),
        )
        assertEquals(listOf("early", "late"), lessons.map { it.id })
    }

    @ParameterizedTest
    @ValueSource(strings = ["{}", "null", "<html/>", ""])
    fun `a body that is not an array is a bad response`(body: String) {
        expectThrows<KretaException.BadResponse> { Lesson.decodeList(body.toByteArray()) }
    }

    @Test
    fun `a lesson survives being stored and read back`() {
        val store = hu.kretaora.core.timetable.SnapshotStore(temporaryDirectory())
        val snapshot = Fixture.snapshot(decode(Fixture.lessonJson(substitute = "\"Nagy Anna\"")))
        store.save(snapshot)
        assertEquals(snapshot, store.load())
    }

    @Test
    fun `parses the timestamp shapes KRETA uses`() {
        val winter = Fixture.date(16, 8)
        assertEquals(winter, KretaDate.parse("2026-11-16T07:00:00Z"))
        assertEquals(winter, KretaDate.parse("2026-11-16T07:00:00.000Z"))
        assertEquals(winter, KretaDate.parse("2026-11-16T08:00:00+01:00"))
        assertEquals(winter, KretaDate.parse("2026-11-16T08:00:00+0100"))
        assertEquals(winter, KretaDate.parse("2026-11-16T02:00:00-05:00"))
        assertEquals(winter, KretaDate.parse("2026-11-16T08:00:00"))
        assertEquals(winter, KretaDate.parse(" 2026-11-16 08:00:00 "))
        // Summer time: Budapest is two hours ahead of UTC.
        assertEquals("8:00", KretaDate.parse("2026-06-01T06:00:00Z")?.let(KretaDate::timeString))
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            "", "2026-11-16", "2026-13-16T08:00:00Z", "2026-11-31T08:00:00Z", "2026-11-16T25:00:00Z",
            "2026-11-16T08:00:00X", "2026-11-16T08:00:00+1", "2026-11-16T08:00:00+99:00",
            "20261116T080000Z", "+026-11-16T08:00:00Z",
        ],
    )
    fun `rejects malformed timestamps`(raw: String) {
        assertNull(KretaDate.parse(raw))
    }

    @Test
    fun `day helpers work in school time`() {
        // 23:30 UTC on the 15th is already the 16th in Budapest.
        val lateEvening = checkNotNull(KretaDate.parse("2026-11-15T23:30:00Z"))
        assertEquals("2026-11-16", KretaDate.dayString(lateEvening))
        assertEquals("0:30", KretaDate.timeString(lateEvening))
        assertTrue(KretaDate.isSameDay(lateEvening, Fixture.date(16, 12)))
        assertEquals(1, KretaDate.days(Fixture.date(16, 23), Fixture.date(17, 1)))
        assertEquals(-1, KretaDate.days(Fixture.date(17), Fixture.date(16)))
        assertEquals(Fixture.date(18), KretaDate.addingDays(2, Fixture.date(16)))
        assertEquals(Fixture.date(16), KretaDate.startOfDay(Fixture.date(16, 12)))
    }

    @Test
    fun `Hungarian weekday and month names`() {
        assertEquals("hétfő", KretaDate.weekdayName(LocalDate.of(2026, 11, 16)))
        assertEquals("vasárnap", KretaDate.weekdayName(LocalDate.of(2026, 11, 22)))
        assertEquals("nov. 20.", KretaDate.shortDate(LocalDate.of(2026, 11, 20)))
        assertEquals("márc. 5.", KretaDate.shortDate(LocalDate.of(2027, 3, 5)))
    }
}
