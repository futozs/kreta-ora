package hu.kretaora.presentation

import android.content.Context
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.StatusSummary
import hu.kretaora.core.timetable.nextSchoolDay
import hu.kretaora.core.timetable.summaryOf
import java.time.Duration
import java.time.Instant

/** The "now / next" card of the app and of the widget, already in words. */
data class StatusCard(
    val label: String,
    val title: String,
    val detail: String? = null,
    val footnote: String? = null,
    /** Lessons of that day that will not take place. */
    val alert: String? = null,
    /** Minutes to the next bell. Only the app shows it, because a widget cannot tick. */
    val countdown: String? = null,
)

/** When the next school day starts, for the "Mikor kezdünk?" widget. */
data class DayStartCard(
    val label: String,
    val time: String,
    val title: String,
    val detail: String?,
    val footnote: String?,
    val alert: String?,
)

/** Turns the core's summaries into the texts the app and the widgets share. */
object Presenter {
    private const val MAX_COUNTDOWN_MINUTES = 120L
    private const val SECONDS_PER_MINUTE = 60L

    fun status(context: Context, schedule: Schedule, now: Instant): StatusCard {
        val summary = StatusSummary.of(schedule, now)
        val lesson = summary.lesson
            ?: return StatusCard(label = summary.label, title = context.getString(R.string.status_nothing_left))
        val following = summary.following
        val footnote = when {
            following != null ->
                context.getString(R.string.status_then, following.displayName, KretaDate.timeString(following.start))
            summary.isInLesson -> context.getString(R.string.status_last_of_day)
            else -> null
        }
        return StatusCard(
            label = summary.label,
            title = lesson.displayName,
            detail = lessonDetail(context, lesson),
            footnote = footnote,
            alert = cancelledAlert(context, schedule, lesson.start, now),
            countdown = countdown(context, summary, now),
        )
    }

    fun dayStart(context: Context, schedule: Schedule, now: Instant): DayStartCard? {
        val today = schedule.summaryOf(now)
        val startsLaterToday = today.first?.let { it.start > now } == true
        val day = if (startsLaterToday) today else schedule.nextSchoolDay(now) ?: return null
        val first = day.first ?: return null
        val notes = listOfNotNull(
            day.cancelledCount.takeIf { it > 0 }?.let { context.getString(R.string.day_cancelled_count, it) },
            day.substitutedCount.takeIf { it > 0 }?.let { context.getString(R.string.day_substituted_count, it) },
        )
        return DayStartCard(
            label = if (startsLaterToday) context.getString(R.string.day_today) else StatusSummary.dayName(first.start, now),
            time = KretaDate.timeString(first.start),
            title = first.displayName,
            detail = place(context, first),
            footnote = day.span,
            alert = notes.joinToString(" · ").ifEmpty { null },
        )
    }

    /** "8:00–8:45 · 12 · Kiss Béla" */
    fun lessonDetail(context: Context, lesson: Lesson): String =
        listOfNotNull(timeRange(lesson), place(context, lesson)).joinToString(" · ")

    fun timeRange(lesson: Lesson): String =
        "${KretaDate.timeString(lesson.start)}–${KretaDate.timeString(lesson.end)}"

    /** Room and whoever teaches, or null when neither is known. */
    fun place(context: Context, lesson: Lesson): String? {
        val teacher = lesson.substituteTeacher?.let { context.getString(R.string.lesson_substitute, it) }
            ?: lesson.teacher
        return listOfNotNull(lesson.room, teacher).joinToString(" · ").ifEmpty { null }
    }

    private fun countdown(context: Context, summary: StatusSummary, now: Instant): String? {
        val target = summary.countdownTo ?: return null
        val seconds = Duration.between(now, target).seconds
        val minutes = (seconds + SECONDS_PER_MINUTE - 1) / SECONDS_PER_MINUTE
        if (minutes !in 1..MAX_COUNTDOWN_MINUTES) return null
        val text = if (summary.isInLesson) R.string.status_minutes_left else R.string.status_starts_in
        return context.getString(text, minutes.toInt())
    }

    private fun cancelledAlert(context: Context, schedule: Schedule, day: Instant, now: Instant): String? {
        val cancelled = schedule.lessonsOn(day).filter { it.isCancelled && it.end > now }
        if (cancelled.isEmpty()) return null
        val names = cancelled.joinToString(", ") { lesson ->
            lesson.index?.let { context.getString(R.string.status_alert_lesson, lesson.displayName, it) }
                ?: lesson.displayName
        }
        return context.getString(R.string.status_alert_cancelled, names)
    }
}
