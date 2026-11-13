package hu.kretaora.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import hu.kretaora.core.KretaException
import java.io.IOException

/** The periodic background sync. All the work happens in [TimetableSync]. */
class SyncWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result =
        try {
            TimetableSync.run(applicationContext)
            Result.success()
        } catch (_: KretaException.NotLoggedIn) {
            Result.success()
        } catch (_: KretaException.SessionExpired) {
            // TimetableSync already told the user and stopped the schedule.
            Result.success()
        } catch (_: KretaException) {
            Result.retry()
        } catch (_: IOException) {
            Result.retry()
        }
}
