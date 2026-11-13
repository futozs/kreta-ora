package hu.kretaora.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by the redraw alarm, and by the system when the user allows or
 * revokes exact alarms. Redraws the widgets and arms the next alarm.
 */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        runAsync { WidgetUpdater.refreshAll(app) }
    }
}
