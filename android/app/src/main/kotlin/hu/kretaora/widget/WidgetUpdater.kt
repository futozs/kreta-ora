package hu.kretaora.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import hu.kretaora.container
import hu.kretaora.core.timetable.TimetableSnapshot
import java.time.Instant

/**
 * Redraws the widgets and arranges the next redraw.
 *
 * Widgets render from the stored snapshot only. They are redrawn after every
 * sync, and at each lesson boundary by one inexact alarm. An inexact alarm
 * needs no permission; the system may deliver it a few minutes late, which is
 * why the widgets show clock times instead of a countdown.
 */
object WidgetUpdater {
    private const val SLACK_SECONDS = 2L
    private const val MIN_DELAY_SECONDS = 30L
    private const val WINDOW_MILLIS = 60_000L

    suspend fun refreshAll(context: Context) {
        val app = context.applicationContext
        val manager = GlanceAppWidgetManager(app)
        val hasWidgets = manager.getGlanceIds(NextLessonWidget::class.java).isNotEmpty() ||
            manager.getGlanceIds(DayStartWidget::class.java).isNotEmpty()
        if (!hasWidgets) {
            scheduleNextRefresh(app, snapshot = null, now = Instant.now())
            return
        }
        NextLessonWidget().updateAll(app)
        DayStartWidget().updateAll(app)
        scheduleNextRefresh(app, app.container.snapshots.load(), Instant.now())
    }

    /**
     * Arms the alarm for the next moment the widgets would show something
     * else. Without a snapshot there is nothing to wait for, so the alarm is
     * cancelled and nothing reschedules itself.
     */
    fun scheduleNextRefresh(context: Context, snapshot: TimetableSnapshot?, now: Instant) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val refresh = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val boundary = snapshot?.schedule?.refreshDates(now)?.getOrNull(1)
        if (boundary == null) {
            alarms.cancel(refresh)
            return
        }
        // Never sooner than half a minute, so a redraw can not chain into a loop.
        val trigger = maxOf(boundary.plusSeconds(SLACK_SECONDS), now.plusSeconds(MIN_DELAY_SECONDS))
        alarms.setWindow(AlarmManager.RTC, trigger.toEpochMilli(), WINDOW_MILLIS, refresh)
    }
}
