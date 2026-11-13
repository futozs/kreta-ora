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
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextDecoration
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import hu.kretaora.R
import hu.kretaora.container
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.StatusSummary
import hu.kretaora.presentation.Presenter
import hu.kretaora.ui.design.Subjects
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant

/** What the widget draws: the lesson that matters now and what follows it that day. */
private data class NextLesson(val label: String, val lesson: Lesson, val later: List<Lesson>) {
    companion object {
        private const val LATER_LIMIT = 3

        fun of(schedule: Schedule, now: Instant): NextLesson? {
            val summary = StatusSummary.of(schedule, now)
            val lesson = summary.lesson ?: return null
            // Cancelled lessons stay in the list, crossed out, so a free period is no surprise.
            val later = schedule.lessonsOn(lesson.start).filter { it.start > lesson.start }.take(LATER_LIMIT)
            return NextLesson(summary.label, lesson, later)
        }
    }
}

/**
 * The running lesson or the next one, as a block in the subject's colour:
 * the same block the app shows, on the home screen.
 */
class NextLessonWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(SMALL, WIDE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val now = Instant.now()
        val snapshot = withContext(Dispatchers.IO) { context.container.snapshots.load() }
        WidgetUpdater.scheduleNextRefresh(context, snapshot, now)
        val next = snapshot?.let { NextLesson.of(it.schedule, now) }
        provideContent { Content(isSignedIn = snapshot != null, next = next) }
    }

    @Composable
    private fun Content(isSignedIn: Boolean, next: NextLesson?) {
        val context = LocalContext.current
        when {
            !isSignedIn -> WidgetSignedOut()
            next == null -> WidgetNote(
                context.getString(R.string.widget_next_name),
                context.getString(R.string.status_nothing_left),
            )
            else -> WidgetBlock(fill = ColorProvider(Subjects.color(next.lesson.name))) {
                if (LocalSize.current.width >= WIDE.width && next.later.isNotEmpty()) {
                    Row(modifier = GlanceModifier.fillMaxWidth().fillMaxHeight()) {
                        Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) { Main(next) }
                        Spacer(GlanceModifier.width(14.dp))
                        Column(modifier = GlanceModifier.width(132.dp).fillMaxHeight()) { Later(next.later) }
                    }
                } else {
                    Main(next)
                }
            }
        }
    }

    @Composable
    private fun ColumnScope.Main(next: NextLesson) {
        val context = LocalContext.current
        val lesson = next.lesson
        val number = lesson.index?.let { context.getString(R.string.widget_lesson_number, it) }
        Text(
            text = listOfNotNull(next.label, number).joinToString(" · "),
            style = TextStyle(color = WidgetColors.ink, fontSize = 13.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        Spacer(GlanceModifier.defaultWeight())
        Text(
            text = lesson.displayName,
            style = TextStyle(color = WidgetColors.ink, fontSize = 21.sp, fontWeight = FontWeight.Bold),
            maxLines = 2,
        )
        Text(
            text = Presenter.timeRange(lesson),
            style = TextStyle(color = WidgetColors.ink, fontSize = 14.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
            modifier = GlanceModifier.padding(top = 2.dp),
        )
        Presenter.place(context, lesson)?.let { place ->
            Text(text = place, style = TextStyle(color = WidgetColors.inkMuted, fontSize = 12.sp), maxLines = 1)
        }
    }

    /** The rest of the day: start time and name, one line each. */
    @Composable
    private fun ColumnScope.Later(lessons: List<Lesson>) {
        val context = LocalContext.current
        Text(
            text = context.getString(R.string.widget_later),
            style = TextStyle(color = WidgetColors.ink, fontSize = 13.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        Spacer(GlanceModifier.defaultWeight())
        lessons.forEach { lesson ->
            Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 3.dp)) {
                Text(
                    text = KretaDate.timeString(lesson.start),
                    style = TextStyle(color = WidgetColors.ink, fontSize = 12.sp, fontWeight = FontWeight.Bold),
                    modifier = GlanceModifier.width(40.dp),
                    maxLines = 1,
                )
                Text(
                    text = lesson.displayName,
                    style = TextStyle(
                        color = if (lesson.isCancelled) WidgetColors.inkMuted else WidgetColors.ink,
                        fontSize = 12.sp,
                        textDecoration = if (lesson.isCancelled) TextDecoration.LineThrough else TextDecoration.None,
                    ),
                    maxLines = 1,
                )
            }
        }
    }

    private companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val WIDE = DpSize(250.dp, 110.dp)
    }
}

class NextLessonWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextLessonWidget()
}
