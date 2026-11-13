package hu.kretaora.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.presentation.Presenter
import hu.kretaora.ui.theme.LocalLessonColors

/**
 * One lesson: time on the left, a bar whose colour says what state it is in,
 * then the subject and where it is. A cancelled lesson is crossed out.
 */
@Composable
fun LessonRow(lesson: Lesson, isCurrent: Boolean, modifier: Modifier = Modifier) {
    val lessonColors = LocalLessonColors.current
    val colors = MaterialTheme.colorScheme
    val accent = when {
        lesson.isCancelled -> lessonColors.cancelled
        lesson.isSubstituted -> lessonColors.substituted
        isCurrent -> colors.primary
        else -> colors.outlineVariant
    }
    val textColor = if (lesson.isCancelled) colors.onSurfaceVariant else colors.onSurface

    Row(
        modifier = modifier.fillMaxWidth().height(IntrinsicSize.Min).padding(vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.width(48.dp), horizontalAlignment = Alignment.End) {
            Text(
                text = KretaDate.timeString(lesson.start),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.SemiBold,
                color = textColor,
            )
            Text(
                text = KretaDate.timeString(lesson.end),
                style = MaterialTheme.typography.bodySmall,
                color = colors.onSurfaceVariant,
            )
        }
        Spacer(Modifier.width(12.dp))
        Box(
            modifier = Modifier
                .width(if (isCurrent || lesson.isCancelled || lesson.isSubstituted) 4.dp else 2.dp)
                .fillMaxHeight()
                .clip(RoundedCornerShape(2.dp))
                .background(accent),
        )
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = lesson.displayName,
                style = MaterialTheme.typography.titleMedium,
                color = textColor,
                textDecoration = if (lesson.isCancelled) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            LessonNotes(lesson)
        }
        lesson.index?.let { index ->
            Text(
                text = stringResource(R.string.lesson_number, index),
                style = MaterialTheme.typography.headlineSmall,
                color = if (isCurrent) colors.primary else colors.outline,
                textAlign = TextAlign.End,
                modifier = Modifier.padding(start = 12.dp),
            )
        }
    }
}

/** The lines under the subject: what happened to the lesson, then where it is. */
@Composable
private fun LessonNotes(lesson: Lesson) {
    val lessonColors = LocalLessonColors.current
    val context = LocalContext.current
    when {
        lesson.isCancelled -> Text(
            text = stringResource(R.string.lesson_cancelled),
            style = MaterialTheme.typography.labelLarge,
            color = lessonColors.cancelled,
        )
        lesson.isSubstituted -> Text(
            text = listOfNotNull(lesson.room, stringResource(R.string.lesson_substitute, lesson.substituteTeacher.orEmpty()))
                .joinToString(" · "),
            style = MaterialTheme.typography.bodyMedium,
            color = lessonColors.substituted,
        )
        else -> Presenter.place(context, lesson)?.let { place ->
            Text(
                text = place,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
    if (lesson.hasTest && !lesson.isCancelled) {
        Text(
            text = stringResource(R.string.lesson_test),
            style = MaterialTheme.typography.labelLarge,
            color = lessonColors.test,
        )
    }
}
