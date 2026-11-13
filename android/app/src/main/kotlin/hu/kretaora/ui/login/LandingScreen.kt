package hu.kretaora.ui.login

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.model.Lesson
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.theme.Ink
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import hu.kretaora.ui.timetable.BlockMode
import hu.kretaora.ui.timetable.LessonBlock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

private const val ENTRANCE_MILLIS = 420
private const val STAGGER_MILLIS = 90
private const val RISE_DP = 28f

/**
 * The first screen. It asks the question the app answers, shows three blocks
 * of a real-looking morning so the idea lands without a word of explanation,
 * and offers one button. Nothing to type: the school is picked on KRÉTA's page.
 */
@Composable
fun LandingScreen(message: String?, onStart: () -> Unit) {
    val palette = Kreta.palette
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .safeDrawingPadding()
            .padding(horizontal = 22.dp),
    ) {
        Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.BottomStart) {
            SampleMorning()
        }
        Spacer(Modifier.height(34.dp))
        Text(text = stringResource(R.string.landing_headline), style = KretaType.display, color = palette.text)
        Text(
            text = stringResource(R.string.landing_body),
            style = KretaType.body,
            color = palette.textDim,
            modifier = Modifier.padding(top = 14.dp, end = 24.dp),
        )

        if (message != null) {
            Text(
                text = message,
                style = KretaType.small,
                color = palette.danger,
                modifier = Modifier.padding(top = 18.dp),
            )
        }

        Text(
            text = stringResource(R.string.landing_button),
            style = KretaType.button,
            color = Ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(top = 26.dp)
                .fillMaxWidth()
                .clip(CircleShape)
                .background(palette.accent)
                .pressable(onClick = onStart)
                .padding(vertical = 20.dp),
        )
        Text(
            text = stringResource(R.string.landing_privacy),
            style = KretaType.small,
            color = palette.textFaint,
            modifier = Modifier.padding(top = 16.dp, bottom = 18.dp),
        )
    }
}

/**
 * A slice of a school morning in the app's own blocks: one lesson running,
 * one cancelled, one still to come. They rise into place once, one after
 * another, and then stay put.
 */
@Composable
private fun SampleMorning() {
    val lessons = remember { sampleLessons() }
    Column(
        // Decoration: a screen reader should not read invented lessons as the user's timetable.
        modifier = Modifier.fillMaxWidth().clearAndSetSemantics { },
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        lessons.forEachIndexed { index, (lesson, mode) ->
            val progress = remember { Animatable(0f) }
            LaunchedEffect(Unit) {
                progress.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(ENTRANCE_MILLIS, delayMillis = index * STAGGER_MILLIS, easing = FastOutSlowInEasing),
                )
            }
            LessonBlock(
                lesson = lesson,
                mode = mode,
                modifier = Modifier
                    .clip(RoundedCornerShape(22.dp))
                    .graphicsLayer {
                        alpha = progress.value
                        translationY = (1f - progress.value) * RISE_DP.dp.toPx()
                    },
            )
        }
    }
}

/** Three invented lessons around the current moment, so the sample shows a live countdown. */
private fun sampleLessons(): List<Pair<Lesson, BlockMode>> {
    val zone = ZoneId.systemDefault()
    val now = Instant.now()
    val running = now.minus(Duration.ofMinutes(21))
    fun lesson(id: String, start: Instant, name: String, index: Int, room: String, cancelled: Boolean = false) =
        Lesson(
            id = id,
            start = start,
            end = start.plus(Duration.ofMinutes(45)),
            name = name,
            index = index,
            teacher = null,
            room = room,
            isCancelled = cancelled,
        )
    // Keep the sample inside one day even when the app is opened around midnight.
    // LocalDate.ofInstant needs API 34; going through the zone works from API 26.
    fun day(instant: Instant): LocalDate = instant.atZone(zone).toLocalDate()
    val anchor = if (day(running) == day(now.plus(Duration.ofHours(3)))) {
        running
    } else {
        day(now).atTime(LocalTime.of(9, 0)).atZone(zone).toInstant()
    }
    return listOf(
        lesson("sample-2", anchor, "Matematika", 2, "204") to
            if (anchor == running) BlockMode.Running else BlockMode.Upcoming,
        lesson("sample-3", anchor.plus(Duration.ofMinutes(55)), "Fizika", 3, "Labor", cancelled = true) to BlockMode.Upcoming,
        lesson("sample-4", anchor.plus(Duration.ofMinutes(110)), "Angol nyelv", 4, "21") to BlockMode.Upcoming,
    )
}
