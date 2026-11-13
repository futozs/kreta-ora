package hu.kretaora.core.timetable

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.model.capitalizedFirst
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate

private const val DAYS_IN_WEEK = 7
private const val DEFAULT_UPCOMING_DAYS = 14

/**
 * The one thing a glanceable surface shows: which lesson matters now, what
 * to call it, and what to count down to.
 */
data class StatusSummary(
    /** "Most", "Következik", "Első óra", "Holnap", "Hétfő", "Nincs több óra". */
    val label: String,
    val lesson: Lesson?,
    /** End of the running lesson, or start of the upcoming one today. */
    val countdownTo: Instant?,
    val isInLesson: Boolean,
    /** The lesson after `lesson` on the same day. */
    val following: Lesson?,
) {
    companion object {
        fun of(schedule: Schedule, now: Instant): StatusSummary =
            when (val status = schedule.status(now)) {
                is ScheduleStatus.InLesson -> StatusSummary(
                    label = "Most",
                    lesson = status.current,
                    countdownTo = status.current.end,
                    isInLesson = true,
                    following = status.next,
                )
                is ScheduleStatus.BreakTime -> upcoming("Következik", status.next, status.next.start, schedule)
                is ScheduleStatus.BeforeFirst -> upcoming("Első óra", status.first, status.first.start, schedule)
                is ScheduleStatus.DayOver -> status.nextFirst
                    ?.let { upcoming(dayName(it.start, now), it, countdownTo = null, schedule) }
                    ?: StatusSummary("Nincs több óra", lesson = null, countdownTo = null, isInLesson = false, following = null)
            }

        private fun upcoming(label: String, lesson: Lesson, countdownTo: Instant?, schedule: Schedule) =
            StatusSummary(label, lesson, countdownTo, isInLesson = false, following = schedule.lessonAfter(lesson))

        /** "Holnap", "Hétfő", or "Hétfő, nov. 23." once it is a week or more away. */
        fun dayName(instant: Instant, now: Instant): String {
            val days = KretaDate.days(now, instant)
            if (days == 1) return "Holnap"
            val date = KretaDate.localDate(instant)
            val weekday = KretaDate.weekdayName(date).capitalizedFirst()
            return if (days < DAYS_IN_WEEK) weekday else "$weekday, ${KretaDate.shortDate(date)}"
        }
    }
}

/** One school day at a glance. */
data class DaySummary(
    /** Start of the day. */
    val day: Instant,
    /** Every lesson of the day, cancelled ones included. */
    val lessons: List<Lesson>,
) {
    val active: List<Lesson> get() = lessons.filter { it.isActive }
    val first: Lesson? get() = active.firstOrNull()
    val last: Lesson? get() = active.lastOrNull()
    val cancelledCount: Int get() = lessons.count { it.isCancelled }
    val substitutedCount: Int get() = active.count { it.isSubstituted }

    /** "8:00–13:35 · 6 óra" */
    val span: String?
        get() {
            val opening = first ?: return null
            val closing = last ?: return null
            return "${KretaDate.timeString(opening.start)}–${KretaDate.timeString(closing.end)} · ${active.size} óra"
        }
}

/** The next lesson that takes place on the same day, after `lesson`. */
fun Schedule.lessonAfter(lesson: Lesson): Lesson? =
    activeLessons.firstOrNull { it.start >= lesson.end && KretaDate.isSameDay(it.start, lesson.start) }

fun Schedule.summaryOf(day: Instant): DaySummary = DaySummary(KretaDate.startOfDay(day), lessonsOn(day))

/** The next day with at least one lesson, strictly after today. */
fun Schedule.nextSchoolDay(now: Instant): DaySummary? = firstLessonOfNextSchoolDay(now)?.let { summaryOf(it.start) }

/**
 * The day worth listing right now: today while a lesson is still ahead or
 * running, otherwise the next school day.
 */
fun Schedule.focusDay(now: Instant): DaySummary? {
    val today = summaryOf(now)
    return if (today.active.any { it.end > now }) today else nextSchoolDay(now)
}

/** The days that have lessons, in order, from `now`'s day onwards. */
fun Schedule.upcomingDays(now: Instant, limit: Int = DEFAULT_UPCOMING_DAYS): List<DaySummary> {
    val today = KretaDate.startOfDay(now)
    return lessons
        .filter { it.start >= today }
        .map { KretaDate.startOfDay(it.start) }
        .distinct()
        .take(limit)
        .map(::summaryOf)
}

/**
 * The part of the snapshot from today on, for surfaces with a small transfer
 * budget.
 */
fun TimetableSnapshot.window(now: Instant, days: Int): TimetableSnapshot {
    val today = KretaDate.startOfDay(now)
    val start = maxOf(rangeStart, today)
    val end = minOf(rangeEnd, KretaDate.addingDays(days, today))
    return copy(
        lessons = lessons.filter { it.start >= start && it.start < end },
        rangeStart = start,
        rangeEnd = maxOf(start, end),
    )
}

/**
 * The days a day-by-day view pages through: every weekday of the window, and
 * a weekend day only when it has a lesson. A weekday without lessons stays in,
 * so the week keeps its shape.
 */
fun TimetableSnapshot.pagerDays(): List<LocalDate> {
    val first = KretaDate.localDate(rangeStart)
    val last = KretaDate.localDate(rangeEnd).minusDays(1)
    val withLessons = lessons.filter { it.kind == Lesson.Kind.LESSON }.map { KretaDate.localDate(it.start) }.toSet()
    return generateSequence(first) { it.plusDays(1) }
        .takeWhile { !it.isAfter(last) }
        .filter { it.dayOfWeek < DayOfWeek.SATURDAY || it in withLessons }
        .toList()
}
