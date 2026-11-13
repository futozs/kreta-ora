package hu.kretaora.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
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

/** When the next school day starts, with its first lesson and how long the day is. */
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
        WidgetCard {
            when {
                !isSignedIn -> WidgetSignedOut()
                card == null -> {
                    WidgetLabel(context.getString(R.string.widget_day_start_name))
                    WidgetDetail(context.getString(R.string.status_nothing_left))
                }
                else -> {
                    WidgetLabel(card.label)
                    Text(
                        text = card.time,
                        style = TextStyle(color = WidgetColors.ink, fontSize = 28.sp, fontWeight = FontWeight.Bold),
                        maxLines = 1,
                    )
                    WidgetDetail(listOfNotNull(card.title, card.detail.takeIf { isWide }).joinToString(" · "))
                    card.footnote?.let { WidgetDetail(it) }
                    card.alert?.let { WidgetAlert(it) }
                }
            }
        }
    }

    private companion object {
        val SMALL = DpSize(110.dp, 50.dp)
        val WIDE = DpSize(250.dp, 50.dp)
    }
}

class DayStartWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DayStartWidget()
}
