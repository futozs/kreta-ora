package hu.kretaora.core.timetable

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/** What a student wants to know right now. */
sealed interface ScheduleStatus {
    /** A lesson is running. `next` is the following lesson today, if any. */
    data class InLesson(val current: Lesson, val next: Lesson?) : ScheduleStatus

    /** Between two lessons today. */
    data class BreakTime(val next: Lesson) : ScheduleStatus

    /** Today's first lesson has not started yet. */
    data class BeforeFirst(val first: Lesson) : ScheduleStatus

    /** Nothing left today. `nextFirst` opens the next school day. */
    data class DayOver(val nextFirst: Lesson?) : ScheduleStatus
}

/** Read-only questions over a list of lessons. All day math is school time. */
class Schedule(lessons: List<Lesson>) {
    /** Lessons and events sorted by start. */
    val entries: List<Lesson> = lessons.sortedWith(Lesson.ORDER)

    /** Real lessons, including cancelled ones. */
    val lessons: List<Lesson> get() = entries.filter { it.kind == Lesson.Kind.LESSON }

    /** Lessons that actually take place. */
    val activeLessons: List<Lesson> get() = entries.filter { it.isActive }

    /**
     * Every lesson of the day, cancelled ones included, so the UI can cross
     * them out.
     */
    fun lessonsOn(day: LocalDate): List<Lesson> = lessons.filter { KretaDate.localDate(it.start) == day }

    fun lessonsOn(day: Instant): List<Lesson> = lessonsOn(KretaDate.localDate(day))

    /** School-year events of the day, for example a holiday. */
    fun eventsOn(day: LocalDate): List<Lesson> =
        entries.filter { it.kind == Lesson.Kind.EVENT && KretaDate.localDate(it.start) == day }

    fun eventsOn(day: Instant): List<Lesson> = eventsOn(KretaDate.localDate(day))

    fun firstLessonOn(day: Instant): Lesson? = activeLessons.firstOrNull { KretaDate.isSameDay(it.start, day) }

    fun lastLessonOn(day: Instant): Lesson? = activeLessons.lastOrNull { KretaDate.isSameDay(it.start, day) }

    fun currentLesson(now: Instant): Lesson? = activeLessons.firstOrNull { it.contains(now) }

    /** The next lesson that has not started yet, today or later. */
    fun nextLesson(now: Instant): Lesson? = activeLessons.firstOrNull { it.start > now }

    /** The first lesson of the next day that has any, strictly after `day`. */
    fun firstLessonOfNextSchoolDay(day: Instant): Lesson? {
        val tomorrow = KretaDate.addingDays(1, KretaDate.startOfDay(day))
        return activeLessons.firstOrNull { it.start >= tomorrow }
    }

    fun status(now: Instant): ScheduleStatus {
        val today = activeLessons.filter { KretaDate.isSameDay(it.start, now) }
        val current = today.firstOrNull { it.contains(now) }
        if (current != null) {
            return ScheduleStatus.InLesson(current, today.firstOrNull { it.start >= current.end })
        }
        val next = today.firstOrNull { it.start > now }
            ?: return ScheduleStatus.DayOver(firstLessonOfNextSchoolDay(now))
        return if (today.any { it.end <= now }) ScheduleStatus.BreakTime(next) else ScheduleStatus.BeforeFirst(next)
    }

    /**
     * Moments when the answer of [status] or a day label changes, so a widget
     * can schedule its redraws without touching the network.
     */
    fun refreshDates(
        now: Instant,
        horizon: Duration = DEFAULT_HORIZON,
        limit: Int = DEFAULT_LIMIT,
    ): List<Instant> {
        val end = now.plus(horizon)
        val boundaries = activeLessons.flatMap { listOf(it.start, it.end) }
        val midnights = (1..2).map { KretaDate.addingDays(it, KretaDate.startOfDay(now)) }
        val upcoming = (boundaries + midnights).toSet().filter { it > now && it <= end }.sorted()
        return (listOf(now) + upcoming).take(limit)
    }

    companion object {
        private val DEFAULT_HORIZON: Duration = Duration.ofHours(36)
        private const val DEFAULT_LIMIT = 48
        private const val DAYS_BEFORE_WEEK = 7L
        private const val DAYS_AFTER_WEEK_START = 20L

        /**
         * The window every sync asks for: last week through two weeks after
         * the current one. Both ends are inclusive school days.
         */
        fun syncRange(now: Instant): Pair<LocalDate, LocalDate> {
            val weekStart = KretaDate.localDate(now).with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            return weekStart.minusDays(DAYS_BEFORE_WEEK) to weekStart.plusDays(DAYS_AFTER_WEEK_START)
        }
    }
}
