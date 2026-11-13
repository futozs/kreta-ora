package hu.kretaora.notify

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import hu.kretaora.R
import hu.kretaora.core.timetable.ChangeFormatter
import hu.kretaora.core.timetable.TimetableChange
import hu.kretaora.ui.MainActivity
import java.time.Instant

/** Turns timetable changes into system notifications. */
object ChangeNotifier {
    private const val CHANNEL_ID = "timetable_changes"
    private const val SUMMARY_ID = 1
    private const val SESSION_ID = 2

    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.notification_channel_description)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** One notification per change, or a single summary when there are many. */
    fun post(context: Context, changes: List<TimetableChange>, now: Instant) {
        if (changes.isEmpty()) return
        val formatter = ChangeFormatter(now)
        if (changes.size > ChangeFormatter.INDIVIDUAL_LIMIT) {
            val summary = formatter.summary(changes)
            notify(context, SUMMARY_ID, summary.title, summary.body)
        } else {
            changes.forEach { notify(context, it.id.hashCode(), formatter.title(it), formatter.body(it)) }
        }
    }

    fun postSessionExpired(context: Context) {
        notify(
            context,
            SESSION_ID,
            context.getString(R.string.notification_session_title),
            context.getString(R.string.notification_session_body),
        )
    }

    fun clearSessionExpired(context: Context) {
        NotificationManagerCompat.from(context).cancel(SESSION_ID)
    }

    private fun notify(context: Context, id: Int, title: String, body: String) {
        val isDenied = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        val manager = NotificationManagerCompat.from(context)
        if (isDenied || !manager.areNotificationsEnabled()) return
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timetable)
            .setColor(ContextCompat.getColor(context, R.color.notification_accent))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(id, notification)
    }
}
