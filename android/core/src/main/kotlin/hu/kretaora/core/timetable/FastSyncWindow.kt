package hu.kretaora.core.timetable

import hu.kretaora.core.model.KretaDate
import java.time.Duration
import java.time.Instant

/**
 * When to check the timetable more often than the background schedule allows.
 *
 * A change that matters most is one that is about to happen, so on a school
 * day the timetable is checked every few minutes from shortly before the
 * first lesson until the last one ends. Outside that window the regular,
 * slower background sync is enough.
 */
object FastSyncWindow {
    /** The window opens this long before the day's first lesson. */
    val LEAD: Duration = Duration.ofHours(2)

    /** How often to check inside the window. */
    val INTERVAL: Duration = Duration.ofMinutes(5)

    /**
     * The next moment a check is due, or null when no school day is ahead.
     * Inside the window that is [INTERVAL] from now, capped at the window's
     * end; before it, the opening; after it, the next school day's opening.
     */
    fun next(schedule: Schedule, now: Instant): Instant? {
        val today = schedule.activeLessons.filter { KretaDate.isSameDay(it.start, now) }
        if (today.isNotEmpty()) {
            val opens = today.first().start.minus(LEAD)
            val closes = today.last().end
            if (now < opens) return opens
            if (now < closes) return minOf(now.plus(INTERVAL), closes)
        }
        return schedule.firstLessonOfNextSchoolDay(now)?.start?.minus(LEAD)
    }
}
