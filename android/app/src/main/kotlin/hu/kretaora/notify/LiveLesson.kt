package hu.kretaora.notify

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.ui.graphics.toArgb
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.ui.MainActivity
import hu.kretaora.ui.design.Subjects
import hu.kretaora.widget.lessonDetail
import hu.kretaora.widget.timeRange
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

/**
 * The school day as one ongoing notification: the running lesson and the
 * time left, or the next lesson and the time until it starts, with the day's
 * lessons as coloured segments of a progress bar. On Android 16 it is
 * promoted to a Live Update, so it sits on the lock screen and as a chip in
 * the status bar.
 *
 * It is opt-in, appears an hour before the first lesson, and goes away after
 * the last. Swiping it away, or "Elrejtés mára", hides it for the rest of
 * the day.
 */
object LiveLesson {
    private const val CHANNEL_ID = "live_lesson"
    private const val NOTIFICATION_ID = 10
    private const val PREFERENCES = "live_lesson"
    private const val ENABLED = "enabled"
    private const val OFFER_DISMISSED = "offer_dismissed"
    private const val HIDDEN_ON = "hidden_on"

    /** Shown this long before the day's first lesson, the same window in which the widget starts counting down. */
    val LEAD: Duration = Duration.ofMinutes(60)

    private val BREAK_COLOR = 0xFF8F8C83.toInt()
    private val CANCELLED_COLOR = 0xFFCDC8BA.toInt()

    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.live_channel_name),
            // Not MIN, or it could not be promoted; not higher, so the hourly updates stay silent.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.live_channel_description)
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun isEnabled(context: Context): Boolean = preferences(context).getBoolean(ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        preferences(context).edit().putBoolean(ENABLED, enabled).putBoolean(OFFER_DISMISSED, true).apply()
        if (!enabled) NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /** Whether to suggest turning it on: once, until the user answers. */
    fun isOfferDue(context: Context): Boolean =
        !isEnabled(context) && !preferences(context).getBoolean(OFFER_DISMISSED, false) && canNotify(context)

    fun dismissOffer(context: Context) {
        preferences(context).edit().putBoolean(OFFER_DISMISSED, true).apply()
    }

    fun hideForToday(context: Context, today: LocalDate) {
        preferences(context).edit().putString(HIDDEN_ON, today.toString()).apply()
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /** Posts, refreshes or removes the notification to match the moment. */
    fun update(context: Context, snapshot: TimetableSnapshot?, now: Instant) {
        val manager = NotificationManagerCompat.from(context)
        val today = KretaDate.localDate(now)
        val day = snapshot?.schedule?.let { Day.of(it, now) }
        val isHidden = preferences(context).getString(HIDDEN_ON, null) == today.toString()
        if (day == null || !isEnabled(context) || isHidden || !canNotify(context)) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        // The permission is checked in canNotify, which lint can not see.
        @Suppress("MissingPermission")
        manager.notify(NOTIFICATION_ID, build(context, day, now))
    }

    /** The day as it stands at one moment: what to show, and what it counts down to. */
    private data class Day(val lessons: List<Lesson>, val focus: Lesson, val isRunning: Boolean, val target: Instant) {
        val start: Instant get() = lessons.first().start
        val end: Instant get() = lessons.last().end

        companion object {
            fun of(schedule: Schedule, now: Instant): Day? {
                val lessons = schedule.lessonsOn(now)
                val active = lessons.filter { it.isActive }
                val first = active.firstOrNull() ?: return null
                if (now < first.start.minus(LEAD) || now >= active.last().end) return null
                active.firstOrNull { it.contains(now) }?.let { running ->
                    return Day(lessons, running, isRunning = true, target = running.end)
                }
                val next = active.firstOrNull { it.start > now } ?: return null
                return Day(lessons, next, isRunning = false, target = next.start)
            }
        }
    }

    private fun build(context: Context, day: Day, now: Instant) = NotificationCompat.Builder(context, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_timetable)
        .setColor(Subjects.color(day.focus.name).toArgb())
        .setContentTitle(title(context, day))
        .setContentText(lessonDetail(context, day.focus, withTime = !day.isRunning))
        .setSubText(timeRange(day.focus))
        .setStyle(progress(day, now))
        // The header and the status-bar chip count down to the bell.
        .setWhen(day.target.toEpochMilli())
        .setShowWhen(true)
        .setUsesChronometer(true)
        .setChronometerCountDown(true)
        .setOngoing(true)
        .setRequestPromotedOngoing(true)
        .setOnlyAlertOnce(true)
        .setSilent(true)
        .setCategory(NotificationCompat.CATEGORY_PROGRESS)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setContentIntent(openApp(context))
        .setDeleteIntent(hideIntent(context, LiveLessonReceiver.ACTION_DISMISSED))
        .addAction(0, context.getString(R.string.live_hide_today), hideIntent(context, LiveLessonReceiver.ACTION_HIDE))
        .build()

    private fun title(context: Context, day: Day): String {
        val lesson = day.focus
        val name = listOfNotNull(lesson.index?.let { "$it." }, lesson.displayName).joinToString(" ")
        return if (day.isRunning) name else context.getString(R.string.live_next_title, name)
    }

    /**
     * The day from the first bell to the last, one segment per lesson in its
     * subject's colour, breaks in grey, minutes as the unit. The bar fills
     * up to now.
     */
    private fun progress(day: Day, now: Instant): NotificationCompat.ProgressStyle {
        val style = NotificationCompat.ProgressStyle()
        var cursor = day.start
        day.lessons.forEach { lesson ->
            val gap = Duration.between(cursor, lesson.start).toMinutes()
            if (gap > 0) style.addProgressSegment(NotificationCompat.ProgressStyle.Segment(gap.toInt()).setColor(BREAK_COLOR))
            val length = Duration.between(maxOf(cursor, lesson.start), lesson.end).toMinutes()
            if (length > 0) {
                val color = if (lesson.isCancelled) CANCELLED_COLOR else Subjects.color(lesson.name).toArgb()
                style.addProgressSegment(NotificationCompat.ProgressStyle.Segment(length.toInt()).setColor(color))
            }
            cursor = maxOf(cursor, lesson.end)
        }
        val elapsed = Duration.between(day.start, now).toMinutes().coerceIn(0, Duration.between(day.start, day.end).toMinutes())
        return style.setProgress(elapsed.toInt())
    }

    private fun openApp(context: Context): PendingIntent =
        PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun hideIntent(context: Context, action: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            Intent(context, LiveLessonReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun canNotify(context: Context): Boolean {
        val isDenied = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        return !isDenied && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun preferences(context: Context) = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}

/** "Elrejtés mára", or the user swiped the notification away: either way, not again today. */
class LiveLessonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_HIDE || intent.action == ACTION_DISMISSED) {
            LiveLesson.hideForToday(context, KretaDate.localDate(Instant.now()))
        }
    }

    companion object {
        const val ACTION_HIDE = "hu.kretaora.action.HIDE_LIVE_LESSON"
        const val ACTION_DISMISSED = "hu.kretaora.action.LIVE_LESSON_DISMISSED"
    }
}
