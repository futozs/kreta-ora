package hu.kretaora.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import hu.kretaora.container
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.notify.LiveLesson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Duration
import java.time.Instant

/**
 * Redraws the widgets and the school-day notification, and arranges the
 * next redraw.
 *
 * Widgets render from the stored snapshot only. The countdown ticks on its
 * own; a redraw is needed only when the picture changes: at every bell, an
 * hour before a lesson (when its start time turns into a countdown), at
 * midnight, and every few minutes during a lesson to move the progress bar.
 *
 * With the exact-alarm permission the redraw lands on the bell. Without it
 * the system may deliver it some minutes late, and the countdown would run
 * past zero in the meantime; the app asks for the permission for that reason.
 */
object WidgetUpdater {
    private const val SLACK_SECONDS = 1L
    private const val MIN_DELAY_SECONDS = 15L
    private const val WINDOW_MILLIS = 60_000L
    private val PROGRESS_STEP: Duration = Duration.ofMinutes(5)

    suspend fun refreshAll(context: Context) {
        val app = context.applicationContext
        val next = widgetIds(app, NextLessonWidgetReceiver::class.java)
        val dayStart = widgetIds(app, DayStartWidgetReceiver::class.java)
        if (next.isEmpty() && dayStart.isEmpty() && !LiveLesson.isEnabled(app)) {
            LiveLesson.update(app, snapshot = null, now = Instant.now())
            scheduleNextRefresh(app, snapshot = null, now = Instant.now())
            return
        }
        val snapshot = withContext(Dispatchers.IO) { app.container.snapshots.load() }
        val now = Instant.now()
        val manager = AppWidgetManager.getInstance(app)
        NextLessonWidget.render(app, manager, next, snapshot, now)
        DayStartWidget.render(app, manager, dayStart, snapshot, now)
        LiveLesson.update(app, snapshot, now)
        scheduleNextRefresh(app, snapshot, now)
    }

    /** Something on screen follows the clock: a widget, or the school-day notification. */
    fun hasClockSurfaces(context: Context): Boolean =
        widgetIds(context, NextLessonWidgetReceiver::class.java).isNotEmpty() ||
            widgetIds(context, DayStartWidgetReceiver::class.java).isNotEmpty() ||
            LiveLesson.isEnabled(context)

    /** True when redraws can land exactly on the bell. */
    fun canRedrawOnTime(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    /** The system page where the user allows exact alarms for this app (Android 12 and later). */
    fun exactAlarmSettings(context: Context): Intent =
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))

    /**
     * Arms the alarm for the next moment the widgets would show something
     * else. Without a snapshot there is nothing to wait for, so the alarm is
     * cancelled and nothing reschedules itself.
     */
    private fun scheduleNextRefresh(context: Context, snapshot: TimetableSnapshot?, now: Instant) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val refresh = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val moment = snapshot?.let { nextChange(it.schedule, now) }
        if (moment == null) {
            alarms.cancel(refresh)
            return
        }
        // Never sooner than a few seconds, so a redraw can not chain into a loop.
        val trigger = maxOf(moment.plusSeconds(SLACK_SECONDS), now.plusSeconds(MIN_DELAY_SECONDS)).toEpochMilli()
        // RTC, not RTC_WAKEUP: with the screen off nobody sees the widget, and
        // a missed redraw is delivered as soon as the phone wakes.
        if (canRedrawOnTime(context)) {
            alarms.setExact(AlarmManager.RTC, trigger, refresh)
        } else {
            alarms.setWindow(AlarmManager.RTC, trigger, WINDOW_MILLIS, refresh)
        }
    }

    /** The next moment either widget looks different. */
    private fun nextChange(schedule: Schedule, now: Instant): Instant? {
        val lessons = schedule.activeLessons
        val bells = lessons.flatMap { listOf(it.start.minus(NextLessonWidget.COUNTDOWN_WINDOW), it.start, it.end) }
        val midnights = (1..2).map { KretaDate.addingDays(it, KretaDate.startOfDay(now)) }
        // Every few minutes while school is on, so the progress bars keep moving.
        val today = lessons.filter { KretaDate.isSameDay(it.start, now) }
        val isSchoolTime = today.isNotEmpty() && now >= today.first().start && now < today.last().end
        val progress = listOfNotNull(now.plus(PROGRESS_STEP).takeIf { isSchoolTime })
        return (bells + midnights + progress).filter { it > now }.minOrNull()
    }
}
