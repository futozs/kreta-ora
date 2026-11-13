package hu.kretaora.ui.timetable

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.ui.design.Subjects
import hu.kretaora.ui.design.rememberNow
import hu.kretaora.ui.theme.Ink
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import java.time.Duration
import java.time.Instant

/** Where a lesson stands relative to now. It decides how much room its block takes. */
enum class BlockMode {
    /** Later today, or on another day. */
    Upcoming,

    /** Already over: the block gives its colour back and shrinks to one quiet line. */
    Past,

    /** Being held right now: the block grows and counts down to the bell. */
    Running,

    /** The next one to start today: slightly larger, says how soon. */
    UpNext,
}

private val BlockShape = RoundedCornerShape(22.dp)
private val NumberWidth = 40.dp
private const val MUTED_INK = 0.68f
private const val SECONDS_PER_MINUTE = 60L
private const val SECONDS_PER_HOUR = 3_600L
private const val MINUTES_PER_HOUR = 60

/**
 * One lesson as a block of its subject's colour.
 *
 * A cancelled lesson loses its fill and keeps only a dashed outline: the slot
 * is still there, but nothing is in it.
 */
@Composable
fun LessonBlock(lesson: Lesson, mode: BlockMode, modifier: Modifier = Modifier) {
    when {
        mode == BlockMode.Past -> PastRow(lesson, modifier)
        lesson.isCancelled -> CancelledBlock(lesson, modifier)
        else -> FilledBlock(lesson, mode, modifier)
    }
}

/**
 * A lesson that is over. The day spends its colour as it goes: what is left
 * in colour is what is still ahead.
 */
@Composable
private fun PastRow(lesson: Lesson, modifier: Modifier) {
    val palette = Kreta.palette
    Row(
        modifier = modifier.fillMaxWidth().padding(start = 16.dp, end = 18.dp, top = 5.dp, bottom = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = lesson.index?.let { stringResource(R.string.lesson_number, it) } ?: "",
            style = KretaType.strong,
            color = palette.textFaint,
            modifier = Modifier.width(NumberWidth),
        )
        Text(
            text = lesson.displayName,
            style = KretaType.small.copy(
                textDecoration = if (lesson.isCancelled) TextDecoration.LineThrough else TextDecoration.None,
            ),
            color = palette.textDim,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = "${KretaDate.timeString(lesson.start)}–${KretaDate.timeString(lesson.end)}",
            style = KretaType.time.copy(fontWeight = FontWeight.W400),
            color = palette.textFaint,
        )
    }
}

@Composable
private fun FilledBlock(lesson: Lesson, mode: BlockMode, modifier: Modifier) {
    val fill = Subjects.color(lesson.name)
    val isEmphasized = mode == BlockMode.Running || mode == BlockMode.UpNext
    val ink = Ink

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(BlockShape)
            .background(fill)
            .animateContentSize()
            .padding(start = 16.dp, end = 18.dp, top = 15.dp, bottom = 15.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = lesson.index?.let { stringResource(R.string.lesson_number, it) } ?: "",
                style = KretaType.number,
                color = ink,
                modifier = Modifier.width(NumberWidth),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = lesson.displayName,
                    style = if (isEmphasized) KretaType.blockTitleLarge else KretaType.blockTitle,
                    color = ink,
                    maxLines = if (isEmphasized) 2 else 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = detail(lesson),
                    style = KretaType.small,
                    color = ink.copy(alpha = MUTED_INK),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.width(10.dp))
            Column(horizontalAlignment = Alignment.End) {
                Text(text = KretaDate.timeString(lesson.start), style = KretaType.time, color = ink)
                Text(
                    text = KretaDate.timeString(lesson.end),
                    style = KretaType.time.copy(fontWeight = FontWeight.W400),
                    color = ink.copy(alpha = MUTED_INK),
                )
            }
        }
        when (mode) {
            BlockMode.Running -> RunningFooter(lesson)
            BlockMode.UpNext -> UpNextFooter(lesson)
            BlockMode.Upcoming, BlockMode.Past -> Unit
        }
    }
}

/** Room, then who teaches. A substitute and a test are set in bold, because they are the news. */
@Composable
private fun detail(lesson: Lesson): AnnotatedString {
    val substitute = lesson.substituteTeacher?.let { stringResource(R.string.lesson_substitute, it) }
    val test = stringResource(R.string.lesson_test).takeIf { lesson.hasTest }
    return buildAnnotatedString {
        val plain = listOfNotNull(lesson.room, lesson.teacher.takeIf { substitute == null })
        append(plain.joinToString(SEPARATOR))
        listOfNotNull(substitute, test).forEach { news ->
            if (length > 0) append(SEPARATOR)
            withStyle(SpanStyle(fontWeight = FontWeight.W800)) { append(news) }
        }
    }
}

private const val SEPARATOR = " · "

/** The live part of the running lesson: time left, and how far the lesson has got. */
@Composable
private fun RunningFooter(lesson: Lesson) {
    val now by rememberNow(Duration.ofSeconds(1))
    val total = Duration.between(lesson.start, lesson.end).seconds.coerceAtLeast(1)
    val left = Duration.between(now, lesson.end).seconds.coerceIn(0, total)
    val spoken = stringResource(R.string.status_minutes_left, minutesRoundedUp(left))

    Spacer(Modifier.height(16.dp))
    Row(
        modifier = Modifier.clearAndSetSemantics { contentDescription = spoken },
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(text = clock(left), style = KretaType.countdown, color = Ink)
        Spacer(Modifier.width(8.dp))
        Text(
            text = stringResource(R.string.status_left),
            style = KretaType.strong,
            color = Ink.copy(alpha = MUTED_INK),
            modifier = Modifier.padding(bottom = 7.dp),
        )
    }
    Spacer(Modifier.height(12.dp))
    Box(modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Ink.copy(alpha = 0.16f))) {
        Box(
            modifier = Modifier
                .fillMaxWidth(fraction = 1f - left.toFloat() / total)
                .fillMaxHeight()
                .clip(CircleShape)
                .background(Ink),
        )
    }
}

@Composable
private fun UpNextFooter(lesson: Lesson) {
    val now by rememberNow(Duration.ofSeconds(1))
    val minutes = minutesRoundedUp(Duration.between(now, lesson.start).seconds.coerceAtLeast(0))
    // Minutes, not a clock: "15:40 múlva" would read as a time of day.
    val text = when {
        minutes < MINUTES_PER_HOUR -> stringResource(R.string.block_starts_in_minutes, minutes)
        minutes % MINUTES_PER_HOUR == 0 -> stringResource(R.string.block_starts_in_hours, minutes / MINUTES_PER_HOUR)
        else -> stringResource(
            R.string.block_starts_in_hours_minutes,
            minutes / MINUTES_PER_HOUR,
            minutes % MINUTES_PER_HOUR,
        )
    }
    Spacer(Modifier.height(12.dp))
    Text(
        text = text,
        style = KretaType.strong,
        color = Ink,
        modifier = Modifier.padding(start = NumberWidth),
    )
}

/** The slot of a lesson that will not be held: an outline with the name crossed out. */
@Composable
private fun CancelledBlock(lesson: Lesson, modifier: Modifier) {
    val palette = Kreta.palette
    val outline = palette.textFaint
    Row(
        modifier = modifier
            .fillMaxWidth()
            .drawBehind {
                val stroke = 1.5.dp.toPx()
                drawRoundRect(
                    color = outline,
                    topLeft = androidx.compose.ui.geometry.Offset(stroke / 2, stroke / 2),
                    size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke),
                    cornerRadius = CornerRadius(22.dp.toPx()),
                    style = Stroke(
                        width = stroke,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 6.dp.toPx())),
                    ),
                )
            }
            .padding(start = 16.dp, end = 18.dp, top = 15.dp, bottom = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = lesson.index?.let { stringResource(R.string.lesson_number, it) } ?: "",
            style = KretaType.number,
            color = palette.textFaint,
            modifier = Modifier.width(NumberWidth),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = lesson.displayName,
                style = KretaType.blockTitle.copy(textDecoration = TextDecoration.LineThrough),
                color = palette.textDim,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = "${KretaDate.timeString(lesson.start)}–${KretaDate.timeString(lesson.end)}",
                style = KretaType.small,
                color = palette.textFaint,
            )
        }
        Text(text = stringResource(R.string.lesson_cancelled), style = KretaType.button, color = palette.danger)
    }
}

/** "23:41" under an hour, "1:05:09" above it. */
private fun clock(seconds: Long): String {
    val hours = seconds / SECONDS_PER_HOUR
    val minutes = seconds % SECONDS_PER_HOUR / SECONDS_PER_MINUTE
    val rest = seconds % SECONDS_PER_MINUTE
    return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, rest) else "%d:%02d".format(minutes, rest)
}

private fun minutesRoundedUp(seconds: Long): Int = ((seconds + SECONDS_PER_MINUTE - 1) / SECONDS_PER_MINUTE).toInt()

/** Which mode a lesson of the day shown is in. [nextUp] is the lesson the day is waiting for, if any. */
fun blockMode(lesson: Lesson, now: Instant, nextUp: Lesson?): BlockMode =
    when {
        lesson.end <= now -> BlockMode.Past
        lesson.contains(now) -> BlockMode.Running
        lesson.id == nextUp?.id -> BlockMode.UpNext
        else -> BlockMode.Upcoming
    }
