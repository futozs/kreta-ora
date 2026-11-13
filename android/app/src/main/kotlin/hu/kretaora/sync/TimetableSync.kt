package hu.kretaora.sync

import android.content.Context
import hu.kretaora.container
import hu.kretaora.core.KretaException
import hu.kretaora.core.sync.SyncResult
import hu.kretaora.notify.ChangeNotifier
import hu.kretaora.widget.WidgetUpdater
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant

/**
 * The single way the timetable gets synced. Opening the app, pull to refresh
 * and the background worker all call [run]; a future push message would too.
 */
object TimetableSync {
    /**
     * Syncs, then announces changes and redraws the widgets before any other
     * sync or sign-out can start. Throws what the sync engine throws.
     */
    suspend fun run(context: Context): SyncResult = withContext(Dispatchers.IO) {
        val app = context.applicationContext
        val container = app.container
        try {
            container.engine.sync(afterwards = { result ->
                ChangeNotifier.post(app, result.changes, Instant.now())
                WidgetUpdater.refreshAll(app)
                FastSync.schedule(app, result.snapshot, Instant.now())
            })
        } catch (error: KretaException.SessionExpired) {
            // Tell the user once, then stay quiet until they sign in again.
            if (container.sessionState.markExpired()) ChangeNotifier.postSessionExpired(app)
            SyncScheduler.stop(app)
            throw error
        }
    }
}
