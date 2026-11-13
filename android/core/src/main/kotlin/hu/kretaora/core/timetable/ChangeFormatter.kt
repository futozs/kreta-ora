package hu.kretaora.core.timetable

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import java.time.Instant

/** Hungarian notification texts for timetable changes. */
class ChangeFormatter(private val now: Instant) {
    data class Summary(val title: String, val body: String)

    fun title(change: TimetableChange): String = "${prefix(change)}: ${change.lesson.displayName}"

    fun body(change: TimetableChange): String {
        val lesson = change.lesson
        val details: List<String?> = when (change.kind) {
            TimetableChange.Kind.CANCELLED,
            TimetableChange.Kind.REMOVED,
            TimetableChange.Kind.RESTORED,
            -> emptyList()
            TimetableChange.Kind.ADDED -> listOf(lesson.room?.let { "terem: $it" }, lesson.effectiveTeacher)
            TimetableChange.Kind.TEACHER -> listOf(teacherDetail(lesson), lesson.room?.let { "terem: $it" })
            TimetableChange.Kind.TIME -> listOf(change.previous?.let { "eddig: ${timing(it, now)}" })
            TimetableChange.Kind.ROOM -> listOf(roomDetail(lesson, change.previous))
        }
        return (listOf(timing(lesson, now)) + details.filterNotNull()).joinToString(" · ")
    }

    /** One line for a sync that changed many lessons at once. */
    fun summary(changes: List<TimetableChange>): Summary {
        val days = changes.map { dayLabel(it.lesson.start, now) }.distinct()
        val body = if (days.size == 1) "${days[0]}: nyisd meg a részletekért." else days.joinToString(", ")
        return Summary("${changes.size} órarendváltozás", body)
    }

    private fun prefix(change: TimetableChange): String =
        when (change.kind) {
            TimetableChange.Kind.CANCELLED -> "Elmarad"
            TimetableChange.Kind.RESTORED -> "Mégis megtartják"
            TimetableChange.Kind.TIME -> "Időpont változott"
            TimetableChange.Kind.ROOM -> "Teremcsere"
            TimetableChange.Kind.ADDED -> "Új óra"
            TimetableChange.Kind.REMOVED -> "Törölt óra"
            TimetableChange.Kind.TEACHER -> when {
                change.lesson.isSubstituted -> "Helyettesítés"
                change.previous?.isSubstituted == true -> "Helyettesítés visszavonva"
                else -> "Tanárváltozás"
            }
        }

    private fun teacherDetail(lesson: Lesson): String? =
        lesson.substituteTeacher?.let { "helyettesít: $it" } ?: lesson.teacher?.let { "tanár: $it" }

    private fun roomDetail(lesson: Lesson, previous: Lesson?): String {
        val current = lesson.room ?: "nincs megadva"
        val old = previous?.room ?: return "terem: $current"
        return "terem: $current (eddig: $old)"
    }

    companion object {
        /** More changes than this in one sync are announced as one summary. */
        const val INDIVIDUAL_LIMIT = 3

        /** "Holnap, 3. óra, 9:55–10:40" */
        fun timing(lesson: Lesson, now: Instant): String {
            val time = "${KretaDate.timeString(lesson.start)}–${KretaDate.timeString(lesson.end)}"
            val position = lesson.index?.let { "$it. óra" }
            return listOfNotNull(dayLabel(lesson.start, now), position, time).joinToString(", ")
        }

        /** "Ma", "Holnap", or "péntek (nov. 15.)". */
        fun dayLabel(instant: Instant, now: Instant): String =
            when (KretaDate.days(now, instant)) {
                0 -> "Ma"
                1 -> "Holnap"
                else -> {
                    val date = KretaDate.localDate(instant)
                    "${KretaDate.weekdayName(date)} (${KretaDate.shortDate(date)})"
                }
            }
    }
}
