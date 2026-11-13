package hu.kretaora.ui

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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import hu.kretaora.ui.theme.KretaOraTheme

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KretaOraTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    AppRoot(viewModel)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        viewModel.refreshIfStale()
    }
}

@Composable
private fun AppRoot(viewModel: AppViewModel) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val attempt = state.loginAttempt
    when {
        state.isLoading || state.isSigningIn ->
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        attempt != null -> LoginWebScreen(
            attempt = attempt,
            onRedirect = viewModel::completeLogin,
            onCancel = viewModel::cancelLogin,
        )
        state.account == null -> LoginScreen(message = state.message, onStart = viewModel::startLogin)
        else -> TimetableScreen(
            state = state,
            onRefresh = viewModel::refresh,
            onSignOut = viewModel::signOut,
            onSignInAgain = viewModel::signInAgain,
            onDismissMessage = viewModel::dismissMessage,
        )
    }
}
