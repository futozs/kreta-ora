package hu.kretaora.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import hu.kretaora.container
import hu.kretaora.presentation.Presenter
import hu.kretaora.presentation.StatusCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant

/** The running lesson or the next one, with room and teacher. */
class NextLessonWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(SMALL, WIDE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val now = Instant.now()
        val snapshot = withContext(Dispatchers.IO) { context.container.snapshots.load() }
        WidgetUpdater.scheduleNextRefresh(context, snapshot, now)
        val card = snapshot?.let { Presenter.status(context, it.schedule, now) }
        provideContent { Content(card) }
    }

    @Composable
    private fun Content(card: StatusCard?) {
        val isWide = LocalSize.current.width >= WIDE.width
        WidgetCard {
            if (card == null) {
                WidgetSignedOut()
            } else {
                WidgetLabel(card.label)
                WidgetTitle(card.title, maxLines = if (isWide) 1 else 2)
                card.detail?.let { WidgetDetail(it) }
                card.alert?.let { WidgetAlert(it) }
                if (isWide) card.footnote?.let { WidgetDetail(it) }
            }
        }
    }

    private companion object {
        val SMALL = DpSize(110.dp, 50.dp)
        val WIDE = DpSize(250.dp, 50.dp)
    }
}

class NextLessonWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextLessonWidget()
}
