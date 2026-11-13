package hu.kretaora.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.SizeF
import android.widget.RemoteViews
import androidx.core.os.BundleCompat
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.ui.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import android.graphics.Paint
import android.graphics.Typeface

private const val RECEIVER_TIMEOUT_MILLIS = 8_000L
private val FALLBACK_SIZE = SizeF(250f, 180f)
private const val SEPARATOR = " · "

/** The sizes the launcher draws a widget at, in dp: one per orientation, or more on foldables. */
internal fun widgetSizes(manager: AppWidgetManager, id: Int): List<SizeF> {
    val options = manager.getAppWidgetOptions(id)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val sizes = BundleCompat.getParcelableArrayList(options, AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java)
        if (!sizes.isNullOrEmpty()) return sizes.distinct()
    }
    // Older launchers report a range; in portrait the widget is minWidth wide and maxHeight tall.
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    return listOf(if (width > 0 && height > 0) SizeF(width.toFloat(), height.toFloat()) else FALLBACK_SIZE)
}

/**
 * One layout per size the widget can be shown at. From Android 12 the
 * launcher picks between them without asking the app again.
 */
internal fun responsive(sizes: List<SizeF>, build: (SizeF) -> RemoteViews): RemoteViews =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && sizes.size > 1) {
        RemoteViews(sizes.associateWith(build))
    } else {
        build(sizes.first())
    }

internal fun widgetIds(context: Context, receiver: Class<out BroadcastReceiver>): IntArray =
    AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, receiver))

/** Tapping anywhere on a widget opens the timetable. */
internal fun openAppIntent(context: Context): PendingIntent =
    PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

/** The neutral block for "signed out" and "nothing left". */
internal fun noteViews(context: Context, title: Int, body: Int): RemoteViews =
    RemoteViews(context.packageName, R.layout.widget_note).apply {
        setTextViewText(R.id.note_title, context.getString(title))
        setTextViewText(R.id.note_body, context.getString(body))
        heavy(R.id.note_title)
        setOnClickPendingIntent(android.R.id.background, openAppIntent(context))
    }

/** Runs [block] off the main thread while the receiver keeps the process alive. */
internal fun BroadcastReceiver.runAsync(block: suspend () -> Unit) {
    val pending = goAsync()
    CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
        try {
            withTimeoutOrNull(RECEIVER_TIMEOUT_MILLIS) { block() }
        } finally {
            pending.finish()
        }
    }
}

/**
 * Thickens the strokes of the given texts. Some launchers, Samsung's among
 * them, draw every weight of the phone's font alike in a widget, which would
 * flatten the hierarchy; a synthetic bold keeps the big numbers big.
 */
internal fun RemoteViews.heavy(vararg ids: Int) {
    val flags = Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG or Paint.FAKE_BOLD_TEXT_FLAG
    ids.forEach { setInt(it, "setPaintFlags", flags) }
}

internal fun timeRange(lesson: Lesson): String =
    "${KretaDate.timeString(lesson.start)}–${KretaDate.timeString(lesson.end)}"

/**
 * "102 · Kiss Béla". A substitute and an announced test are set in bold,
 * because they are what changed.
 */
internal fun lessonDetail(context: Context, lesson: Lesson, withTime: Boolean): CharSequence {
    val text = SpannableStringBuilder()
    fun add(part: String?, bold: Boolean = false) {
        if (part.isNullOrBlank()) return
        if (text.isNotEmpty()) text.append(SEPARATOR)
        val start = text.length
        text.append(part)
        if (bold) text.setSpan(StyleSpan(Typeface.BOLD), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
    if (withTime) add(timeRange(lesson))
    add(lesson.room)
    val substitute = lesson.substituteTeacher
    if (substitute != null) add(context.getString(R.string.lesson_substitute, substitute), bold = true) else add(lesson.teacher)
    if (lesson.hasTest) add(context.getString(R.string.lesson_test), bold = true)
    return text
}
