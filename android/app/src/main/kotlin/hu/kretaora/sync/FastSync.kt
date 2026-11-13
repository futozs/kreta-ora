package hu.kretaora.sync

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import hu.kretaora.container
import hu.kretaora.core.KretaException
import hu.kretaora.core.timetable.FastSyncWindow
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.widget.WidgetUpdater
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import java.time.Instant

/**
 * Checks the timetable every few minutes on school days, around the lessons,
 * where the regular background sync can only run every fifteen minutes.
 *
 * It is one alarm that re-arms itself after every check, following
 * [FastSyncWindow]. The alarm may fire while the phone sleeps: a change to
 * the next lesson is worth waking it for. Without the exact-alarm permission
 * the system decides the timing and the checks become less frequent.
 */
object FastSync {
    private const val REQUEST_CODE = 1
    private const val MIN_DELAY_SECONDS = 30L

    fun schedule(context: Context, snapshot: TimetableSnapshot?, now: Instant) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val check = pendingCheck(context)
        val next = snapshot?.let { FastSyncWindow.next(it.schedule, now) }
        if (next == null || context.container.sessionState.isExpired) {
            alarms.cancel(check)
            return
        }
        val trigger = maxOf(next, now.plusSeconds(MIN_DELAY_SECONDS)).toEpochMilli()
        if (WidgetUpdater.canRedrawOnTime(context)) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, check)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, check)
        }
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(pendingCheck(context))
    }

    private fun pendingCheck(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, FastSyncReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

/**
 * Runs one check right in the receiver. In Doze an alarm opens a network
 * window of only a few seconds, which a queued background job would miss.
 */
class FastSyncReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                withTimeoutOrNull(TIMEOUT_MILLIS) { TimetableSync.run(app) }
            } catch (error: KretaException) {
                Log.i(TAG, "Fast sync did not finish: ${error.javaClass.simpleName}")
            } catch (error: IOException) {
                Log.i(TAG, "Fast sync had no connection: ${error.javaClass.simpleName}")
            } finally {
                // Re-arm from what is stored, whether or not this check worked.
                FastSync.schedule(app, app.container.snapshots.load(), Instant.now())
                pending.finish()
            }
        }
    }

    private companion object {
        const val TAG = "FastSync"
        const val TIMEOUT_MILLIS = 20_000L
    }
}
