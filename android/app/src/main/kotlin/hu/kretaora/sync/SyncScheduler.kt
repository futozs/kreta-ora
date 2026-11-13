package hu.kretaora.sync

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import hu.kretaora.container
import java.util.concurrent.TimeUnit

/** Owns the periodic background sync. */
object SyncScheduler {
    private const val WORK_NAME = "timetable-sync"
    private const val INTERVAL_MINUTES = 15L
    private const val BACKOFF_MINUTES = 1L

    /** Starts the periodic sync unless the session is known to be expired. */
    fun start(context: Context) {
        if (context.container.sessionState.isExpired) return
        val request = PeriodicWorkRequestBuilder<SyncWorker>(INTERVAL_MINUTES, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, BACKOFF_MINUTES, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    /** Stops the periodic sync and the fast school-day checks. */
    fun stop(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        FastSync.cancel(context)
    }
}
