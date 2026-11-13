package hu.kretaora.ui

import android.content.pm.ApplicationInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import hu.kretaora.ui.login.LandingScreen
import hu.kretaora.ui.login.LoginWebScreen
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaOraTheme
import hu.kretaora.ui.timetable.TimetableScreen

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KretaOraTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    if (isLandingPreview()) LandingScreen(message = null, onStart = {}) else AppRoot(viewModel)
                }
            }
        }
    }

    /**
     * Debuggable builds only: `adb shell am start -n hu.kretaora/.ui.MainActivity --ez preview_landing true`
     * shows the first screen for a design check without touching the stored session.
     */
    private fun isLandingPreview(): Boolean {
        val isDebuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        return isDebuggable && intent.getBooleanExtra(EXTRA_PREVIEW_LANDING, false)
    }

    override fun onResume() {
        super.onResume()
        viewModel.refreshIfStale()
    }
}

private const val EXTRA_PREVIEW_LANDING = "preview_landing"

@Composable
private fun AppRoot(viewModel: AppViewModel) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val attempt = state.loginAttempt
    when {
        state.isLoading || state.isSigningIn ->
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Kreta.palette.text, strokeWidth = 3.dp)
            }
        attempt != null -> LoginWebScreen(
            attempt = attempt,
            onRedirect = viewModel::completeLogin,
            onCancel = viewModel::cancelLogin,
        )
        // No institution is asked for: KRÉTA's own page has the school picker.
        state.account == null -> LandingScreen(message = state.message, onStart = { viewModel.startLogin("") })
        else -> TimetableScreen(
            state = state,
            onRefresh = viewModel::refresh,
            onSignOut = viewModel::signOut,
            onSignInAgain = viewModel::signInAgain,
            onDismissMessage = viewModel::dismissMessage,
        )
    }
}
