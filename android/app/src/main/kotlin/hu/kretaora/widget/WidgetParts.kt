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
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import hu.kretaora.R
import hu.kretaora.ui.MainActivity

/** The neutral widget colours: the app's paper and near-black, by day and by night. */
internal object WidgetColors {
    val surface = ColorProvider(day = Color(0xFFFBF9F4), night = Color(0xFF1C1C1A))
    val text = ColorProvider(day = Color(0xFF141413), night = Color(0xFFF3F0E7))
    val muted = ColorProvider(day = Color(0xFF5F5C54), night = Color(0xFFABA79C))
    val danger = ColorProvider(day = Color(0xFFD63A27), night = Color(0xFFFF6A55))

    /** Text on a subject colour, the same in both themes because the colour is. */
    val ink = ColorProvider(Color(0xFF141413))
    val inkMuted = ColorProvider(Color(0xB3141413))
}

internal val WidgetCorner = 26.dp

/**
 * The body of every widget: one flat block that opens the app when tapped.
 * A lesson widget passes the subject's colour; the others stay neutral.
 */
@Composable
internal fun WidgetBlock(fill: ColorProvider = WidgetColors.surface, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(fill)
            .cornerRadius(WidgetCorner)
            .padding(16.dp)
            .clickable(actionStartActivity<MainActivity>()),
        content = content,
    )
}

/** A neutral block with a heading and one line, for "signed out" and "nothing left". */
@Composable
internal fun WidgetNote(title: String, body: String) {
    WidgetBlock {
        Text(
            text = title,
            style = TextStyle(color = WidgetColors.text, fontSize = 15.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        Text(text = body, style = TextStyle(color = WidgetColors.muted, fontSize = 13.sp), maxLines = 3)
    }
}

/** Shown when there is no stored timetable, usually because nobody is signed in. */
@Composable
internal fun WidgetSignedOut() {
    val context = LocalContext.current
    WidgetNote(context.getString(R.string.app_name), context.getString(R.string.widget_signed_out))
}
