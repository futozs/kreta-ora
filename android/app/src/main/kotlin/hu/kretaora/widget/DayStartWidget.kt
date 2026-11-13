package hu.kretaora.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.compose.ui.graphics.toArgb
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.presentation.Presenter
import hu.kretaora.ui.design.Subjects
import java.time.Instant
import kotlin.math.roundToInt

class DayStartWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        runAsync { WidgetUpdater.refreshAll(context) }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        runAsync { WidgetUpdater.refreshAll(context) }

    override fun onDisabled(context: Context) = runAsync { WidgetUpdater.refreshAll(context) }
}

/**
 * When the next school day starts. The time is the widget, set as large as
 * the width allows. Under it: the first lesson, and the whole day as a bar of
 * subject colours, so its length and its gaps read at a glance.
 */
internal object DayStartWidget {
    private const val TALL_DP = 170f
    private const val HORIZONTAL_PADDING_DP = 36f
    private const val BAR_HEIGHT_DP = 12f
    private const val BAR_GAP_DP = 4f
    private const val OUTLINE_DP = 1.5f
    private const val MIN_TIME_SP = 50f
    private const val MAX_TIME_SP = 120f

    /** Room left for the time once the label and the lines under it are placed. */
    private const val RESERVED_HEIGHT_DP = 150f
    private const val TIME_HEIGHT_PER_SP = 1.05f
    private const val TIME_WIDTH_PER_SP = 2.5f

    /** The time grows with the widget: limited by the height left over and by the width "88:88" needs. */
    private fun timeSize(size: SizeF): Float {
        val byHeight = (size.height - RESERVED_HEIGHT_DP) / TIME_HEIGHT_PER_SP
        val byWidth = (size.width - HORIZONTAL_PADDING_DP) / TIME_WIDTH_PER_SP
        return minOf(byHeight, byWidth).coerceIn(MIN_TIME_SP, MAX_TIME_SP)
    }

    fun render(context: Context, manager: AppWidgetManager, ids: IntArray, snapshot: TimetableSnapshot?, now: Instant) {
        val schedule = snapshot?.schedule
        val day = schedule?.let { Presenter.dayStartSummary(it, now) }
        val card = schedule?.let { Presenter.dayStart(context, it, now) }
        ids.forEach { id ->
            val views = responsive(widgetSizes(manager, id)) { size ->
                when {
                    snapshot == null -> noteViews(context, R.string.app_name, R.string.widget_signed_out)
                    day == null || card == null ->
                        noteViews(context, R.string.widget_day_start_name, R.string.status_nothing_left)
                    else -> build(context, size, card, day.lessons)
                }
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun build(
        context: Context,
        size: SizeF,
        card: hu.kretaora.presentation.DayStartCard,
        lessons: List<Lesson>,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_start)
        views.setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
        views.setTextViewText(R.id.ds_label, card.label)
        views.setTextViewText(R.id.ds_time, card.time)
        views.heavy(R.id.ds_time, R.id.ds_title)
        views.setTextViewText(R.id.ds_title, card.title)
        views.setTextViewText(R.id.ds_detail, card.detail.orEmpty())
        views.setTextViewTextSize(R.id.ds_time, TypedValue.COMPLEX_UNIT_SP, timeSize(size))
        if (size.height < TALL_DP || card.detail == null) views.setViewVisibility(R.id.ds_detail, View.GONE)
        views.setImageViewBitmap(R.id.ds_bar, dayBar(context, lessons, size.width - HORIZONTAL_PADDING_DP))

        // A cancelled lesson or a substitute matters more than the length of the day.
        val alert = card.alert
        if (alert != null) {
            views.setViewVisibility(R.id.ds_alert, View.VISIBLE)
            views.setViewVisibility(R.id.ds_span, View.GONE)
            views.setTextViewText(R.id.ds_alert, alert)
        } else {
            views.setTextViewText(R.id.ds_span, card.footnote.orEmpty())
        }
        return views
    }

    /** One rounded segment per lesson in its subject's colour; a cancelled one is only an outline. */
    private fun dayBar(context: Context, lessons: List<Lesson>, widthDp: Float): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).roundToInt().coerceAtLeast(1)
        val height = (BAR_HEIGHT_DP * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        if (lessons.isEmpty()) return bitmap

        val canvas = Canvas(bitmap)
        val gap = BAR_GAP_DP * density
        val segment = (width - gap * (lessons.size - 1)) / lessons.size
        val radius = height / 2f
        val outline = OUTLINE_DP * density
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = outline
            color = context.getColor(R.color.widget_outline)
        }
        lessons.forEachIndexed { index, lesson ->
            val left = index * (segment + gap)
            val rect = RectF(left, 0f, left + segment, height.toFloat())
            if (lesson.isCancelled) {
                rect.inset(outline / 2, outline / 2)
                canvas.drawRoundRect(rect, radius, radius, stroke)
            } else {
                fill.color = Subjects.color(lesson.name).toArgb()
                canvas.drawRoundRect(rect, radius, radius, fill)
            }
        }
        return bitmap
    }
}
