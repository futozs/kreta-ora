package hu.kretaora.data

import android.content.Context
import androidx.core.content.edit

/**
 * Remembers that the KRÉTA session has expired, so the user is told once and
 * background work stays off until they sign in again.
 */
class SessionState(context: Context) {
    private val preferences = context.getSharedPreferences("kretaora.state", Context.MODE_PRIVATE)

    val isExpired: Boolean
        get() = preferences.getBoolean(KEY_EXPIRED, false)

    /** Marks the session expired. True only the first time, on the transition. */
    @Synchronized
    fun markExpired(): Boolean {
        if (isExpired) return false
        preferences.edit { putBoolean(KEY_EXPIRED, true) }
        return true
    }

    /** Called on sign-in and sign-out. */
    @Synchronized
    fun clear() {
        preferences.edit { remove(KEY_EXPIRED) }
    }

    private companion object {
        const val KEY_EXPIRED = "session_expired"
    }
}
