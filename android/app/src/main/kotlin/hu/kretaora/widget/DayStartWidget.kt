package hu.kretaora.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Spacer
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import hu.kretaora.R
import hu.kretaora.container
import hu.kretaora.presentation.DayStartCard
import hu.kretaora.presentation.Presenter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant

/**
 * When the next school day starts. The clock time is the widget: it is set
 * as large as the space allows, with the first lesson and the day's length
 * underneath.
 */
class DayStartWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(SMALL, WIDE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val now = Instant.now()
        val snapshot = withContext(Dispatchers.IO) { context.container.snapshots.load() }
        WidgetUpdater.scheduleNextRefresh(context, snapshot, now)
        val card = snapshot?.let { Presenter.dayStart(context, it.schedule, now) }
        provideContent { Content(isSignedIn = snapshot != null, card = card) }
    }

    @Composable
    private fun Content(isSignedIn: Boolean, card: DayStartCard?) {
        val context = LocalContext.current
        val isWide = LocalSize.current.width >= WIDE.width
        when {
            !isSignedIn -> WidgetSignedOut()
            card == null -> WidgetNote(
                context.getString(R.string.widget_day_start_name),
                context.getString(R.string.status_nothing_left),
            )
            else -> WidgetBlock {
                Text(
                    text = card.label,
                    style = TextStyle(color = WidgetColors.muted, fontSize = 13.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1,
                )
                Text(
                    text = card.time,
                    style = TextStyle(
                        color = WidgetColors.text,
                        fontSize = if (isWide) 46.sp else 38.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
                Spacer(GlanceModifier.defaultWeight())
                Text(
                    text = listOfNotNull(card.title, card.detail.takeIf { isWide }).joinToString(" · "),
                    style = TextStyle(color = WidgetColors.text, fontSize = 14.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1,
                )
                // A cancelled or substituted lesson matters more than the length of the day.
                val alert = card.alert
                if (alert != null) {
                    Text(
                        text = alert,
                        style = TextStyle(color = WidgetColors.danger, fontSize = 12.sp, fontWeight = FontWeight.Bold),
                        maxLines = 1,
                    )
                } else {
                    card.footnote?.let { footnote ->
                        Text(text = footnote, style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp), maxLines = 1)
                    }
                }
            }
        }
    }

    private companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val WIDE = DpSize(250.dp, 110.dp)
    }
}

class DayStartWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DayStartWidget()
}
