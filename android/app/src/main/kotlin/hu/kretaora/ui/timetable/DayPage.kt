package hu.kretaora.ui.timetable

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.StatusSummary
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.theme.Ink
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

private val BlockGap = 6.dp
private const val LONG_BREAK_MINUTES = 20L
private const val SKELETON_BLOCKS = 6

/** One row of a day: a lesson, or the note that a long gap sits between two lessons. */
private sealed interface DayRow {
    val key: String

    data class Block(val lesson: Lesson, val mode: BlockMode) : DayRow {
        override val key: String get() = lesson.id
    }

    data class Gap(val minutes: Long, val after: String) : DayRow {
        override val key: String get() = "gap-$after"
    }
}

/**
 * One day of the pager: its lessons stacked as colour blocks, top to bottom
 * in the order they happen. Pulling down refreshes the timetable.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DayPage(
    day: LocalDate,
    schedule: Schedule?,
    now: Instant,
    isRefreshing: Boolean,
    needsSignIn: Boolean,
    onRefresh: () -> Unit,
    onSignInAgain: () -> Unit,
    modifier: Modifier = Modifier,
    notice: (@Composable () -> Unit)? = null,
) {
    val rows = remember(schedule, day, now) { schedule?.let { rowsOf(it, day, now) } }
    val events = remember(schedule, day) { schedule?.eventsOn(day).orEmpty() }

    PullToRefreshBox(isRefreshing = isRefreshing, onRefresh = onRefresh, modifier = modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 132.dp),
            verticalArrangement = Arrangement.spacedBy(BlockGap),
        ) {
            if (needsSignIn) {
                item(key = "sign-in") { SignInAgainNote(onSignInAgain) }
            }
            if (notice != null) {
                item(key = "notice") { notice() }
            }
            items(events, key = { "event-${it.id}" }) { EventNote(it) }
            when {
                rows == null -> items(SKELETON_BLOCKS) { SkeletonBlock() }
                rows.isEmpty() -> item(key = "empty") { EmptyDay(day, schedule) }
                else -> items(rows, key = { it.key }) { row ->
                    when (row) {
                        is DayRow.Block -> LessonBlock(row.lesson, row.mode, Modifier.animateItem())
                        is DayRow.Gap -> GapNote(row.minutes)
                    }
                }
            }
        }
    }
}

/** The day's lessons with their modes, and a gap row wherever the break is long enough to matter. */
private fun rowsOf(schedule: Schedule, day: LocalDate, now: Instant): List<DayRow> {
    val lessons = schedule.lessonsOn(day)
    val summary = StatusSummary.of(schedule, now)
    // Only a lesson that is still to start today is "next up"; tomorrow's first lesson is not.
    val nextUp = summary.lesson.takeIf { !summary.isInLesson && summary.countdownTo != null }
    return lessons.flatMapIndexed { index, lesson ->
        val previous = lessons.getOrNull(index - 1)
        val gap = previous?.let { Duration.between(it.end, lesson.start).toMinutes() } ?: 0
        listOfNotNull(
            DayRow.Gap(gap, previous?.id.orEmpty()).takeIf { gap >= LONG_BREAK_MINUTES },
            DayRow.Block(lesson, blockMode(lesson, now, nextUp)),
        )
    }
}

@Composable
private fun GapNote(minutes: Long) {
    Text(
        text = stringResource(R.string.day_gap, minutes),
        style = KretaType.small,
        color = Kreta.palette.textFaint,
        modifier = Modifier.padding(start = 56.dp, top = 6.dp, bottom = 6.dp),
    )
}

/** A school-year event of the day, for example a holiday. */
@Composable
private fun EventNote(event: Lesson) {
    val palette = Kreta.palette
    Text(
        text = event.displayName,
        style = KretaType.strong,
        color = palette.text,
        modifier = Modifier
            .fillMaxWidth()
            .border(1.5.dp, palette.outline, RoundedCornerShape(18.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
    )
}

@Composable
private fun EmptyDay(day: LocalDate, schedule: Schedule?) {
    val palette = Kreta.palette
    val next = schedule?.firstLessonOfNextSchoolDay(KretaDate.startOfDay(day))
    Column(modifier = Modifier.fillMaxWidth().padding(start = 8.dp, end = 8.dp, top = 36.dp)) {
        Text(text = stringResource(R.string.day_empty_title), style = KretaType.dayTitle, color = palette.text)
        Text(
            text = if (next != null) {
                stringResource(
                    R.string.day_empty_next,
                    KretaDate.weekdayName(KretaDate.localDate(next.start)),
                    KretaDate.timeString(next.start),
                    next.displayName,
                )
            } else {
                stringResource(R.string.day_empty_body)
            },
            style = KretaType.body,
            color = palette.textDim,
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

/** The stored session stopped working. The timetable below is the last one saved. */
@Composable
private fun SignInAgainNote(onSignInAgain: () -> Unit) {
    val palette = Kreta.palette
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 6.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(palette.surface)
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = stringResource(R.string.error_session_expired), style = KretaType.body, color = palette.text)
        Text(
            text = stringResource(R.string.timetable_sign_in_again),
            style = KretaType.button,
            color = Ink,
            modifier = Modifier
                .clip(CircleShape)
                .background(palette.accent)
                .pressable(onClick = onSignInAgain)
                .padding(horizontal = 20.dp, vertical = 12.dp),
        )
    }
}

/** A one-time suggestion at the top of the day: a sentence, a yes and a not now. */
@Composable
fun OfferNote(body: String, allow: String, onAllow: () -> Unit, onLater: () -> Unit) {
    val palette = Kreta.palette
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 6.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(palette.surface)
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(text = body, style = KretaType.body, color = palette.text)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = allow,
                style = KretaType.button,
                color = Ink,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(palette.accent)
                    .pressable(onClick = onAllow)
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            )
            Text(
                text = stringResource(R.string.exact_alarm_later),
                style = KretaType.button,
                color = palette.textDim,
                modifier = Modifier
                    .clip(CircleShape)
                    .pressable(onClick = onLater)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            )
        }
    }
}

/** A placeholder block while the first timetable is on its way. */
@Composable
private fun SkeletonBlock() {
    val alpha by rememberInfiniteTransition(label = "skeleton").animateFloat(
        initialValue = 0.45f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(durationMillis = 900), RepeatMode.Reverse),
        label = "pulse",
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(74.dp)
            .graphicsLayer { this.alpha = alpha }
            .clip(RoundedCornerShape(22.dp))
            .background(Kreta.palette.surface),
    )
}
