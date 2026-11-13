package hu.kretaora.ui

import android.app.Application
import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import hu.kretaora.R
import hu.kretaora.container
import hu.kretaora.core.KretaException
import hu.kretaora.core.auth.Account
import hu.kretaora.core.auth.LoginAttempt
import hu.kretaora.core.auth.Session
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.notify.ChangeNotifier
import hu.kretaora.sync.SyncScheduler
import hu.kretaora.sync.TimetableSync
import hu.kretaora.widget.WidgetUpdater
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.time.Duration
import java.time.Instant

data class AppState(
    /** True until the stored session and timetable have been read. */
    val isLoading: Boolean = true,
    val account: Account? = null,
    val snapshot: TimetableSnapshot? = null,
    /** Set while the KRÉTA login page is open. */
    val loginAttempt: LoginAttempt? = null,
    val isSigningIn: Boolean = false,
    val isSyncing: Boolean = false,
    /** The stored session no longer works; the timetable shown is the last one saved. */
    val needsSignIn: Boolean = false,
    val message: String? = null,
)

class AppViewModel(application: Application) : AndroidViewModel(application) {
    private val container = application.container
    private val mutableState = MutableStateFlow(AppState())
    val state: StateFlow<AppState> = mutableState.asStateFlow()

    init {
        viewModelScope.launch {
            val session = withContext(Dispatchers.IO) { container.sessions.load() }
            val snapshot = withContext(Dispatchers.IO) { container.snapshots.load() }
            val isExpired = container.sessionState.isExpired
            mutableState.update {
                it.copy(
                    isLoading = false,
                    account = session?.account,
                    snapshot = snapshot?.takeIf { stored -> stored.accountId == session?.account?.id },
                    needsSignIn = session != null && isExpired,
                    message = text(R.string.error_session_expired).takeIf { session != null && isExpired },
                )
            }
            if (session != null && !isExpired) {
                SyncScheduler.start(getApplication())
                refresh()
            }
        }
    }

    /** Opens the KRÉTA login page with a clean web view. */
    fun startLogin(institution: String) {
        val attempt = try {
            LoginAttempt.create(institution = institution.ifBlank { null })
        } catch (error: KretaException.InvalidInstitution) {
            mutableState.update { it.copy(message = error.message) }
            return
        }
        WebStorage.getInstance().deleteAllData()
        CookieManager.getInstance().removeAllCookies {
            mutableState.update { it.copy(loginAttempt = attempt, message = null) }
        }
    }

    fun cancelLogin() {
        mutableState.update { it.copy(loginAttempt = null) }
    }

    /** Called with the intercepted OAuth redirect. */
    fun completeLogin(redirect: String) {
        val attempt = state.value.loginAttempt ?: return
        mutableState.update { it.copy(loginAttempt = null, isSigningIn = true, message = null) }
        viewModelScope.launch {
            try {
                val session = withContext(Dispatchers.IO) { signIn(attempt, redirect) }
                container.sessionState.clear()
                ChangeNotifier.clearSessionExpired(getApplication())
                mutableState.update { state ->
                    state.copy(
                        isSigningIn = false,
                        account = session.account,
                        snapshot = state.snapshot?.takeIf { it.accountId == session.account.id },
                        needsSignIn = false,
                    )
                }
                SyncScheduler.start(getApplication())
                refresh()
            } catch (error: KretaException) {
                mutableState.update { it.copy(isSigningIn = false, message = error.message) }
            } catch (_: StorageException) {
                mutableState.update { it.copy(isSigningIn = false, message = text(R.string.error_storage)) }
            } catch (_: IOException) {
                mutableState.update { it.copy(isSigningIn = false, message = text(R.string.error_offline)) }
            }
        }
    }

    /** Syncs unless a sync is already running. */
    fun refresh() {
        val current = state.value
        if (current.account == null || current.isSyncing || current.needsSignIn) return
        mutableState.update { it.copy(isSyncing = true) }
        viewModelScope.launch {
            try {
                val result = TimetableSync.run(getApplication())
                mutableState.update { it.copy(snapshot = result.snapshot, message = null) }
            } catch (_: KretaException.SessionExpired) {
                mutableState.update { it.copy(needsSignIn = true, message = text(R.string.error_session_expired)) }
            } catch (_: KretaException.NotLoggedIn) {
                mutableState.update { AppState(isLoading = false) }
            } catch (error: KretaException) {
                mutableState.update { it.copy(message = error.message) }
            } catch (_: IOException) {
                mutableState.update { it.copy(message = text(R.string.error_offline)) }
            } finally {
                mutableState.update { it.copy(isSyncing = false) }
            }
        }
    }

    /** Syncs when the app comes to the front and the timetable is not fresh. */
    fun refreshIfStale() {
        val syncedAt = state.value.snapshot?.syncedAt
        val isStale = syncedAt == null || Duration.between(syncedAt, Instant.now()) > STALE_AFTER
        if (isStale) refresh()
    }

    /** Starts a new login for the same school after the session expired. */
    fun signInAgain() {
        startLogin(state.value.account?.institutionCode.orEmpty())
    }

    fun signOut() {
        viewModelScope.launch {
            val application = getApplication<Application>()
            SyncScheduler.stop(application)
            val failure = try {
                withContext(Dispatchers.IO) {
                    container.engine.signOut(afterwards = { WidgetUpdater.refreshAll(application) })
                }
                null
            } catch (_: IOException) {
                text(R.string.error_sign_out)
            }
            container.sessionState.clear()
            ChangeNotifier.clearSessionExpired(application)
            mutableState.value = AppState(isLoading = false, message = failure)
        }
    }

    fun refreshWidgets() {
        viewModelScope.launch { WidgetUpdater.refreshAll(getApplication()) }
    }

    fun dismissMessage() {
        mutableState.update { it.copy(message = null) }
    }

    /**
     * Exchanges the code and stores the session. Signing in as someone else
     * first wipes what belonged to the previous account.
     */
    private suspend fun signIn(attempt: LoginAttempt, redirect: String): Session {
        val session = container.auth.completeLogin(attempt, redirect)
        val previous = container.sessions.load()?.account?.id
        try {
            if (previous != null && previous != session.account.id) container.engine.signOut()
            container.sessions.save(session)
        } catch (error: IOException) {
            throw StorageException(error)
        }
        return session
    }

    /** The login worked, but the session could not be stored on the device. */
    private class StorageException(cause: IOException) : Exception(cause)

    private fun text(id: Int): String = getApplication<Application>().getString(id)

    private companion object {
        val STALE_AFTER: Duration = Duration.ofMinutes(2)
    }
}
