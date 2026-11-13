package hu.kretaora.presentation

import android.content.Context
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.DaySummary
import hu.kretaora.core.timetable.StatusSummary
import hu.kretaora.core.timetable.nextSchoolDay
import hu.kretaora.core.timetable.summaryOf
import java.time.Instant

/** When the next school day starts, for the "Mikor kezdünk?" widget. */
data class DayStartCard(
    val label: String,
    val time: String,
    val title: String,
    val detail: String?,
    val footnote: String?,
    val alert: String?,
)

/** Turns the core's summaries into the texts the widgets show. */
object Presenter {
    /** Today while its first lesson is still ahead, otherwise the next school day. */
    fun dayStartSummary(schedule: Schedule, now: Instant): DaySummary? {
        val today = schedule.summaryOf(now)
        return if (today.first?.let { it.start > now } == true) today else schedule.nextSchoolDay(now)
    }

    fun dayStart(context: Context, schedule: Schedule, now: Instant): DayStartCard? {
        val day = dayStartSummary(schedule, now) ?: return null
        val first = day.first ?: return null
        val startsLaterToday = KretaDate.isSameDay(first.start, now)
        val notes = listOfNotNull(
            day.cancelledCount.takeIf { it > 0 }?.let { context.getString(R.string.day_cancelled_count, it) },
            day.substitutedCount.takeIf { it > 0 }?.let { context.getString(R.string.day_substituted_count, it) },
        )
        return DayStartCard(
            label = if (startsLaterToday) context.getString(R.string.day_today) else StatusSummary.dayName(first.start, now),
            time = KretaDate.timeString(first.start),
            title = listOfNotNull(first.displayName, first.room).joinToString(" · "),
            detail = first.substituteTeacher?.let { context.getString(R.string.lesson_substitute, it) } ?: first.teacher,
            footnote = day.span,
            alert = notes.joinToString(" · ").ifEmpty { null },
        )
    }

    fun timeRange(lesson: Lesson): String =
        "${KretaDate.timeString(lesson.start)}–${KretaDate.timeString(lesson.end)}"

    /** Room and whoever teaches, or null when neither is known. */
    fun place(context: Context, lesson: Lesson): String? {
        val teacher = lesson.substituteTeacher?.let { context.getString(R.string.lesson_substitute, it) }
            ?: lesson.teacher
        return listOfNotNull(lesson.room, teacher).joinToString(" · ").ifEmpty { null }
    }
}
