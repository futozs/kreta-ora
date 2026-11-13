package hu.kretaora

import android.app.Application
import android.content.Context
import hu.kretaora.core.auth.AuthService
import hu.kretaora.core.auth.SessionStore
import hu.kretaora.core.net.KretaApi
import hu.kretaora.core.sync.SyncEngine
import hu.kretaora.core.timetable.SnapshotStore
import hu.kretaora.data.KeystoreSessionStore
import hu.kretaora.data.SessionState
import hu.kretaora.notify.ChangeNotifier
import hu.kretaora.notify.LiveLesson
import java.io.File

/** The app's few long-lived objects, created once and shared by every entry point. */
class AppContainer(context: Context) {
    val sessions: SessionStore = KeystoreSessionStore(context)
    val snapshots = SnapshotStore(File(context.filesDir, "timetable"))
    val sessionState = SessionState(context)
    private val api = KretaApi()
    val auth = AuthService(api)
    val engine = SyncEngine(api, sessions, snapshots)
}

class KretaOraApp : Application() {
    val container: AppContainer by lazy { AppContainer(this) }

    override fun onCreate() {
        super.onCreate()
        ChangeNotifier.createChannel(this)
        LiveLesson.createChannel(this)
    }
}

val Context.container: AppContainer
    get() = (applicationContext as KretaOraApp).container
