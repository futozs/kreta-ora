package hu.kretaora.widget

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import hu.kretaora.R
import hu.kretaora.ui.MainActivity
import java.util.Locale

/** The widget palette: the app's paper and chalkboard colours, by day and by night. */
internal object WidgetColors {
    val surface = ColorProvider(day = Color(0xFFFFFCF6), night = Color(0xFF171F1C))
    val ink = ColorProvider(day = Color(0xFF1B1F1D), night = Color(0xFFECE8DF))
    val muted = ColorProvider(day = Color(0xFF5A605C), night = Color(0xFFA6B0AA))
    val accent = ColorProvider(day = Color(0xFF1F5C4A), night = Color(0xFF8FD6B8))
    val alert = ColorProvider(day = Color(0xFFB3382C), night = Color(0xFFFF8A7A))
}

private val HUNGARIAN: Locale = Locale.forLanguageTag("hu-HU")

/** The rounded surface every widget sits on. Tapping it opens the app. */
@Composable
internal fun WidgetCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(WidgetColors.surface)
            .cornerRadius(22.dp)
            .padding(14.dp)
            .clickable(actionStartActivity<MainActivity>()),
        verticalAlignment = Alignment.Vertical.CenterVertically,
        content = content,
    )
}

@Composable
internal fun WidgetLabel(text: String) {
    Text(
        text = text.uppercase(HUNGARIAN),
        style = TextStyle(color = WidgetColors.accent, fontSize = 11.sp, fontWeight = FontWeight.Bold),
        maxLines = 1,
    )
}

@Composable
internal fun WidgetTitle(text: String, maxLines: Int = 1) {
    Text(
        text = text,
        style = TextStyle(color = WidgetColors.ink, fontSize = 17.sp, fontWeight = FontWeight.Bold),
        maxLines = maxLines,
    )
}

@Composable
internal fun WidgetDetail(text: String) {
    Text(text = text, style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp), maxLines = 1)
}

@Composable
internal fun WidgetAlert(text: String) {
    Text(
        text = text,
        style = TextStyle(color = WidgetColors.alert, fontSize = 12.sp, fontWeight = FontWeight.Medium),
        maxLines = 2,
    )
}

/** Shown when there is no stored timetable, usually because nobody is signed in. */
@Composable
internal fun WidgetSignedOut() {
    val context = LocalContext.current
    WidgetLabel(context.getString(R.string.app_name))
    WidgetDetail(context.getString(R.string.widget_signed_out))
}
