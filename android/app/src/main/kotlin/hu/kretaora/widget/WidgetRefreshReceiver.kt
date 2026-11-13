package hu.kretaora.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/** Fired by the lesson-boundary alarm. Redraws the widgets and arms the next alarm. */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val app = context.applicationContext
        // A receiver has no scope of its own; the pending result keeps the process alive.
        CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
            try {
                withTimeoutOrNull(TIMEOUT_MILLIS) { WidgetUpdater.refreshAll(app) }
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 8_000L
    }
}
