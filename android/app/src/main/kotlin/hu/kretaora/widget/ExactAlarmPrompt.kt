package hu.kretaora.widget

import android.content.Context

/**
 * Whether the app should ask for exact alarms: only when a widget or the
 * school-day notification follows the clock, the permission is missing, and
 * the user has not said no.
 */
object ExactAlarmPrompt {
    private const val PREFERENCES = "widget"
    private const val DISMISSED = "exact_alarm_prompt_dismissed"

    fun isDue(context: Context): Boolean =
        !WidgetUpdater.canRedrawOnTime(context) &&
            WidgetUpdater.hasClockSurfaces(context) &&
            !context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getBoolean(DISMISSED, false)

    fun dismiss(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().putBoolean(DISMISSED, true).apply()
    }
}
