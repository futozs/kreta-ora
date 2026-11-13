package hu.kretaora.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.os.SystemClock
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.compose.ui.graphics.toArgb
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.StatusSummary
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.ui.design.Subjects
import java.time.Duration
import java.time.Instant

/** The launcher's entry point. Every event ends in one redraw of all widgets. */
class NextLessonWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        runAsync { WidgetUpdater.refreshAll(context) }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        runAsync { WidgetUpdater.refreshAll(context) }

    override fun onDisabled(context: Context) = runAsync { WidgetUpdater.refreshAll(context) }
}

/**
 * The lesson that matters now, drawn as the app draws it: a block in the
 * subject's colour with a countdown the system ticks every second, even
 * while the app is not running. Below it, as much of the rest of the day as
 * the widget's height allows.
 */
internal object NextLessonWidget {
    /** Narrower than this, the times move into the detail line and the number goes. */
    private const val WIDE_DP = 210f

    /** From this width, a widget too short for stacked blocks puts the next lessons beside the current one. */
    private const val SPLIT_MIN_WIDTH_DP = 300f

    /** Tall enough to stack the next lessons under the current one. */
    private const val STACK_MIN_HEIGHT_DP = 290f
    private const val TILE_DP = 62f
    private const val MAX_TILES = 3

    /** The block's height with the countdown and the progress bar. */
    private const val FULL_BLOCK_DP = 172f

    /** The block without the progress bar and with a one-line name. */
    private const val COMPACT_BLOCK_DP = 128f
    private const val ROW_DP = 58f
    private const val MAX_ROWS = 5
    private const val PROGRESS_MAX = 1_000

    /** Closer than this, the next lesson counts down; further away it shows its start time. */
    val COUNTDOWN_WINDOW: Duration = Duration.ofMinutes(60)

    fun render(context: Context, manager: AppWidgetManager, ids: IntArray, snapshot: TimetableSnapshot?, now: Instant) {
        val model = snapshot?.let { Model.of(it.schedule, now) }
        ids.forEach { id ->
            val views = responsive(widgetSizes(manager, id)) { size ->
                when {
                    snapshot == null -> noteViews(context, R.string.app_name, R.string.widget_signed_out)
                    model == null -> noteViews(context, R.string.widget_next_name, R.string.status_nothing_left)
                    else -> build(context, size, model, now)
                }
            }
            manager.updateAppWidget(id, views)
        }
    }

    private enum class Phase { Running, Soon, Later }

    private data class Model(val lesson: Lesson, val phase: Phase, val following: List<Lesson>) {
        companion object {
            fun of(schedule: Schedule, now: Instant): Model? {
                val summary = StatusSummary.of(schedule, now)
                val lesson = summary.lesson ?: return null
                val phase = when {
                    summary.isInLesson -> Phase.Running
                    KretaDate.isSameDay(lesson.start, now) &&
                        Duration.between(now, lesson.start) <= COUNTDOWN_WINDOW -> Phase.Soon
                    else -> Phase.Later
                }
                // Cancelled lessons stay in the list, so a free period is no surprise.
                val following = schedule.lessonsOn(lesson.start).filter { it.start >= lesson.end }
                return Model(lesson, phase, following)
            }
        }
    }

    private fun build(context: Context, size: SizeF, model: Model, now: Instant): RemoteViews {
        val lesson = model.lesson
        val isSplit = size.width >= SPLIT_MIN_WIDTH_DP && size.height < STACK_MIN_HEIGHT_DP && model.following.isNotEmpty()
        // Beside the tiles the block is about 60% of the width: lay it out as a narrow one.
        val isWide = !isSplit && size.width >= WIDE_DP
        val blockHeight = if (model.phase == Phase.Running) FULL_BLOCK_DP else FULL_BLOCK_DP - 20f
        val isCompact = size.height < blockHeight
        val rows = if (isSplit) {
            0
        } else {
            ((size.height - blockHeight) / ROW_DP).toInt().coerceIn(0, minOf(MAX_ROWS, model.following.size))
        }

        val views = RemoteViews(
            context.packageName,
            if (isSplit) R.layout.widget_next_lesson_split else R.layout.widget_next_lesson,
        )
        views.setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
        views.setInt(R.id.main_fill, "setColorFilter", Subjects.color(lesson.name).toArgb())
        views.setTextViewText(R.id.main_name, lesson.displayName)
        views.heavy(R.id.main_number, R.id.main_name, R.id.main_start, R.id.main_countdown, R.id.main_static)
        views.setTextViewText(R.id.main_detail, lessonDetail(context, lesson, withTime = !isWide))

        if (isWide) {
            views.setTextViewText(R.id.main_number, lesson.index?.let { "$it." }.orEmpty())
            views.setTextViewText(R.id.main_start, KretaDate.timeString(lesson.start))
            views.setTextViewText(R.id.main_end, KretaDate.timeString(lesson.end))
        } else if (isSplit) {
            // The number stays; the times join the detail line to leave the name room.
            views.setTextViewText(R.id.main_number, lesson.index?.let { "$it." }.orEmpty())
            views.setViewVisibility(R.id.main_times, View.GONE)
            views.setTextViewTextSize(R.id.main_countdown, TypedValue.COMPLEX_UNIT_SP, SPLIT_COUNTDOWN_SP)
            views.setTextViewTextSize(R.id.main_static, TypedValue.COMPLEX_UNIT_SP, SPLIT_COUNTDOWN_SP)
            views.setTextViewTextSize(R.id.main_count_label, TypedValue.COMPLEX_UNIT_SP, SPLIT_LABEL_SP)
        } else {
            views.setViewVisibility(R.id.main_number, View.GONE)
            views.setViewVisibility(R.id.main_times, View.GONE)
            views.setTextViewTextSize(R.id.main_name, TypedValue.COMPLEX_UNIT_SP, NARROW_NAME_SP)
        }
        if (isCompact) {
            views.setInt(R.id.main_name, "setMaxLines", 1)
            views.setTextViewTextSize(R.id.main_countdown, TypedValue.COMPLEX_UNIT_SP, COMPACT_COUNTDOWN_SP)
            views.setTextViewTextSize(R.id.main_static, TypedValue.COMPLEX_UNIT_SP, COMPACT_COUNTDOWN_SP)
        } else if (!isWide && !isSplit) {
            views.setTextViewTextSize(R.id.main_countdown, TypedValue.COMPLEX_UNIT_SP, NARROW_COUNTDOWN_SP)
            views.setTextViewTextSize(R.id.main_static, TypedValue.COMPLEX_UNIT_SP, NARROW_COUNTDOWN_SP)
        }

        when (model.phase) {
            Phase.Running -> {
                countdown(views, lesson.end, now)
                views.setTextViewText(R.id.main_count_label, context.getString(R.string.status_left))
                if (isCompact) {
                    views.setViewVisibility(R.id.main_progress, View.GONE)
                } else {
                    views.setProgressBar(R.id.main_progress, PROGRESS_MAX, progress(lesson, now), false)
                }
            }
            Phase.Soon -> {
                countdown(views, lesson.start, now)
                views.setTextViewText(R.id.main_count_label, context.getString(R.string.widget_starts_in))
                views.setViewVisibility(R.id.main_progress, View.GONE)
            }
            Phase.Later -> {
                views.setViewVisibility(R.id.main_countdown, View.GONE)
                views.setViewVisibility(R.id.main_static, View.VISIBLE)
                views.setTextViewText(R.id.main_static, KretaDate.timeString(lesson.start))
                views.setTextViewText(R.id.main_count_label, dayWord(context, lesson.start, now))
                views.setViewVisibility(R.id.main_progress, View.GONE)
            }
        }

        // The launcher may reapply onto the views it already shows, and addView
        // appends: without this the list would grow with every redraw.
        views.removeAllViews(R.id.follow_container)
        if (isSplit) {
            val tiles = ((size.height + TILE_GAP_DP) / TILE_DP).toInt().coerceIn(1, minOf(MAX_TILES, model.following.size))
            model.following.take(tiles).forEachIndexed { index, next ->
                views.addView(R.id.follow_container, followTile(context, next, isFirst = index == 0, roomy = tiles < MAX_TILES))
            }
        } else {
            model.following.take(rows).forEach { views.addView(R.id.follow_container, followRow(context, it)) }
        }
        return views
    }

    /** A later lesson as a tile beside the current one: start time over the name. */
    private fun followTile(context: Context, lesson: Lesson, isFirst: Boolean, roomy: Boolean): RemoteViews {
        val tile = if (lesson.isCancelled) {
            RemoteViews(context.packageName, R.layout.widget_follow_tile_cancelled).apply {
                setTextViewText(R.id.tile_time, context.getString(R.string.lesson_cancelled))
                setTextViewText(R.id.tile_name, struck(lesson.displayName))
            }
        } else {
            RemoteViews(context.packageName, R.layout.widget_follow_tile).apply {
                setInt(R.id.tile_fill, "setColorFilter", Subjects.color(lesson.name).toArgb())
                setTextViewText(R.id.tile_time, KretaDate.timeString(lesson.start))
                setTextViewText(R.id.tile_name, lesson.displayName)
                heavy(R.id.tile_time)
            }
        }
        // The first tile lines up with the top of the block; the others keep their gap.
        if (isFirst) tile.setViewPadding(R.id.tile_root, 0, 0, 0, 0)
        if (!roomy) tile.setInt(R.id.tile_name, "setMaxLines", 1)
        return tile
    }

    /** A countdown the launcher ticks by itself; the next redraw replaces it at the bell. */
    private fun countdown(views: RemoteViews, target: Instant, now: Instant) {
        val base = SystemClock.elapsedRealtime() + Duration.between(now, target).toMillis()
        views.setChronometer(R.id.main_countdown, base, null, true)
        views.setChronometerCountDown(R.id.main_countdown, true)
    }

    private fun progress(lesson: Lesson, now: Instant): Int {
        val total = Duration.between(lesson.start, lesson.end).toMillis().coerceAtLeast(1)
        val done = Duration.between(lesson.start, now).toMillis().coerceIn(0, total)
        return (done * PROGRESS_MAX / total).toInt()
    }

    /** "ma", "holnap", or the weekday, next to a start time that is still far away. */
    private fun dayWord(context: Context, start: Instant, now: Instant): String =
        when (KretaDate.days(now, start)) {
            0 -> context.getString(R.string.widget_today)
            1 -> context.getString(R.string.widget_tomorrow)
            else -> KretaDate.weekdayName(KretaDate.localDate(start))
        }

    private fun followRow(context: Context, lesson: Lesson): RemoteViews {
        val number = lesson.index?.let { "$it." }.orEmpty()
        if (lesson.isCancelled) {
            return RemoteViews(context.packageName, R.layout.widget_follow_row_cancelled).apply {
                setTextViewText(R.id.row_number, number)
                setTextViewText(R.id.row_name, struck(lesson.displayName))
                setTextViewText(R.id.row_cancelled, context.getString(R.string.lesson_cancelled))
            }
        }
        return RemoteViews(context.packageName, R.layout.widget_follow_row).apply {
            setInt(R.id.row_fill, "setColorFilter", Subjects.color(lesson.name).toArgb())
            setTextViewText(R.id.row_number, number)
            setTextViewText(R.id.row_name, lesson.displayName)
            setTextViewText(R.id.row_time, KretaDate.timeString(lesson.start))
            heavy(R.id.row_number, R.id.row_time)
        }
    }

    private fun struck(text: String): CharSequence =
        SpannableString(text).apply { setSpan(StrikethroughSpan(), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) }

    private const val NARROW_NAME_SP = 21f
    private const val SPLIT_COUNTDOWN_SP = 42f
    private const val SPLIT_LABEL_SP = 13f
    private const val TILE_GAP_DP = 6f
    private const val NARROW_COUNTDOWN_SP = 38f
    private const val COMPACT_COUNTDOWN_SP = 34f
}
