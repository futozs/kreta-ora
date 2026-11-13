package hu.kretaora.ui

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import hu.kretaora.R
import hu.kretaora.core.auth.LoginAttempt

/** The first screen: an optional school code, then off to KRÉTA's own login page. */
@Composable
fun LoginScreen(message: String?, onStart: (String) -> Unit) {
    var institution by rememberSaveable { mutableStateOf("") }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 40.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = stringResource(R.string.app_name),
            style = MaterialTheme.typography.displaySmall,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.login_tagline),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(40.dp))
        OutlinedTextField(
            value = institution,
            onValueChange = { institution = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.login_institution_label)) },
            supportingText = { Text(stringResource(R.string.login_institution_hint)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.None,
                autoCorrectEnabled = false,
                imeAction = ImeAction.Go,
            ),
            keyboardActions = KeyboardActions(onGo = { onStart(institution) }),
        )
        if (message != null) {
            Spacer(Modifier.height(12.dp))
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
            )
        }
        Spacer(Modifier.height(24.dp))
        Button(onClick = { onStart(institution) }, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.login_button), modifier = Modifier.padding(vertical = 6.dp))
        }
        Spacer(Modifier.height(20.dp))
        Text(
            text = stringResource(R.string.login_privacy),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** KRÉTA's hosted login page. The password never passes through the app's own UI. */
@Composable
fun LoginWebScreen(attempt: LoginAttempt, onRedirect: (String) -> Unit, onCancel: () -> Unit) {
    BackHandler(onBack = onCancel)
    Column(modifier = Modifier.fillMaxSize().safeDrawingPadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.login_web_title),
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onCancel) { Text(stringResource(R.string.login_cancel)) }
        }
        LoginWebView(url = attempt.url, onRedirect = onRedirect, modifier = Modifier.fillMaxSize())
    }
}

// The KRÉTA login page does not work without JavaScript. Nothing is exposed to
// it: no JavaScript interface, no file access, no content access.
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun LoginWebView(url: String, onRedirect: (String) -> Unit, modifier: Modifier = Modifier) {
    val currentOnRedirect by rememberUpdatedState(onRedirect)
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.setSupportMultipleWindows(false)
                webViewClient = RedirectInterceptor { currentOnRedirect(it) }
                loadUrl(url)
            }
        },
        onRelease = { webView ->
            webView.stopLoading()
            webView.destroy()
        },
    )
}

/** Catches the OAuth redirect and hands it over instead of loading it. */
private class RedirectInterceptor(private val onRedirect: (String) -> Unit) : WebViewClient() {
    private var isDelivered = false

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
        intercept(request.url.toString())

    // A second net in case a navigation reaches the redirect without passing
    // through shouldOverrideUrlLoading.
    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        if (intercept(url)) view.stopLoading()
    }

    private fun intercept(url: String): Boolean {
        if (!LoginAttempt.isRedirect(url)) return false
        if (!isDelivered) {
            isDelivered = true
            onRedirect(url)
        }
        return true
    }
}
