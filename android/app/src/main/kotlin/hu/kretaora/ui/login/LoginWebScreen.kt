package hu.kretaora.ui.login

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import hu.kretaora.R
import hu.kretaora.core.auth.LoginAttempt
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType

private const val FULLY_LOADED = 100

/** KRÉTA's hosted login page. The password never passes through the app's own UI. */
@Composable
fun LoginWebScreen(attempt: LoginAttempt, onRedirect: (String) -> Unit, onCancel: () -> Unit) {
    val palette = Kreta.palette
    var progress by remember { mutableIntStateOf(0) }
    BackHandler(onBack = onCancel)
    Column(modifier = Modifier.fillMaxSize().background(palette.background).safeDrawingPadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 14.dp, top = 6.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = stringResource(R.string.login_web_title), style = KretaType.headline, color = palette.text)
                Text(text = stringResource(R.string.login_web_host), style = KretaType.small, color = palette.textDim)
            }
            Box(
                modifier = Modifier.size(44.dp).clip(CircleShape).background(palette.surfaceHigh).pressable(onClick = onCancel),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.Close, contentDescription = stringResource(R.string.login_cancel), tint = palette.text)
            }
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)),
        ) {
            LoginWebView(
                url = attempt.url,
                onRedirect = onRedirect,
                onProgress = { progress = it },
                modifier = Modifier.fillMaxSize(),
            )
            androidx.compose.animation.AnimatedVisibility(
                visible = progress < FULLY_LOADED,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                LinearProgressIndicator(
                    progress = { progress / FULLY_LOADED.toFloat() },
                    modifier = Modifier.fillMaxWidth().height(3.dp),
                    color = palette.text,
                    trackColor = palette.surfaceHigh,
                )
            }
        }
    }
}

// The KRÉTA login page does not work without JavaScript. Nothing is exposed to
// it: no JavaScript interface, no file access, no content access.
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun LoginWebView(
    url: String,
    onRedirect: (String) -> Unit,
    onProgress: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val currentOnRedirect by rememberUpdatedState(onRedirect)
    val currentOnProgress by rememberUpdatedState(onProgress)
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
                webChromeClient = object : WebChromeClient() {
                    override fun onProgressChanged(view: WebView, newProgress: Int) {
                        currentOnProgress(newProgress)
                    }
                }
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
