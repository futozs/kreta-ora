package hu.kretaora.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.model.capitalizedFirst
import hu.kretaora.core.timetable.ChangeFormatter
import hu.kretaora.core.timetable.DaySummary
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.TimetableSnapshot
import hu.kretaora.core.timetable.upcomingDays
import hu.kretaora.presentation.Presenter
import hu.kretaora.presentation.StatusCard
import hu.kretaora.ui.theme.LocalLessonColors
import kotlinx.coroutines.delay
import java.time.Instant
import java.util.Locale

private const val CLOCK_TICK_MILLIS = 15_000L
private val HUNGARIAN: Locale = Locale.forLanguageTag("hu-HU")

/** The main screen: what is happening now, then the coming days. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimetableScreen(
    state: AppState,
    onRefresh: () -> Unit,
    onSignOut: () -> Unit,
    onSignInAgain: () -> Unit,
    onDismissMessage: () -> Unit,
) {
    val now by rememberNow()
    val schedule = remember(state.snapshot) { state.snapshot?.schedule }
    RequestNotificationPermission()

    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        PullToRefreshBox(
            isRefreshing = state.isSyncing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            ) {
                item { Header(name = state.account?.displayName.orEmpty(), onSignOut = onSignOut) }
                state.message?.let { message ->
                    item {
                        MessageBanner(
                            message = message,
                            action = stringResource(
                                if (state.needsSignIn) R.string.timetable_sign_in_again else R.string.message_dismiss,
                            ),
                            onAction = if (state.needsSignIn) onSignInAgain else onDismissMessage,
                        )
                    }
                }
                if (schedule != null) {
                    timetable(schedule, state.snapshot, now)
                }
            }
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.timetable(
    schedule: Schedule,
    snapshot: TimetableSnapshot?,
    now: Instant,
) {
    item { StatusCardView(schedule, now) }
    val days = schedule.upcomingDays(now)
    if (days.isEmpty()) {
        item { EmptyTimetable() }
    }
    days.forEach { day ->
        item { DayHeader(day, now) }
        items(schedule.eventsOn(day.day)) { event -> EventRow(event) }
        items(day.lessons) { lesson ->
            LessonRow(lesson = lesson, isCurrent = lesson.isActive && lesson.contains(now))
        }
    }
    snapshot?.let { item { SyncedAt(it.syncedAt, now) } }
}

/** The current time, refreshed often enough for the "now" card to stay right. */
@Composable
private fun rememberNow(): State<Instant> =
    produceState(initialValue = Instant.now()) {
        while (true) {
            delay(CLOCK_TICK_MILLIS)
            value = Instant.now()
        }
    }

/** Asks for the notification permission once the user is signed in (Android 13 and later). */
@Composable
private fun RequestNotificationPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    LaunchedEffect(Unit) {
        val isGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!isGranted) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}

@Composable
private fun Header(name: String, onSignOut: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.app_name).uppercase(HUNGARIAN),
                style = MaterialTheme.typography.labelMedium,
                letterSpacing = 1.6.sp,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = name,
                style = MaterialTheme.typography.headlineSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        TextButton(onClick = onSignOut) { Text(stringResource(R.string.timetable_sign_out)) }
    }
}

@Composable
private fun MessageBanner(message: String, action: String, onAction: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.errorContainer,
        contentColor = MaterialTheme.colorScheme.onErrorContainer,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
    ) {
        Row(
            modifier = Modifier.padding(start = 16.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = message, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            TextButton(onClick = onAction) { Text(action) }
        }
    }
}

/** The big card: the lesson that matters right now. */
@Composable
private fun StatusCardView(schedule: Schedule, now: Instant) {
    val context = LocalContext.current
    val card: StatusCard = Presenter.status(context, schedule, now)
    val colors = MaterialTheme.colorScheme
    Surface(
        color = colors.primary,
        contentColor = colors.onPrimary,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp, bottomStart = 28.dp, bottomEnd = 8.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(horizontal = 22.dp, vertical = 20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = card.label.uppercase(HUNGARIAN),
                    style = MaterialTheme.typography.labelLarge,
                    letterSpacing = 1.6.sp,
                    color = colors.onPrimary.copy(alpha = 0.78f),
                    modifier = Modifier.weight(1f),
                )
                card.countdown?.let {
                    Text(text = it, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(text = card.title, style = MaterialTheme.typography.displaySmall)
            card.detail?.let {
                Spacer(Modifier.height(6.dp))
                Text(text = it, style = MaterialTheme.typography.titleMedium)
            }
            card.alert?.let {
                Spacer(Modifier.height(10.dp))
                Surface(color = colors.onPrimary, contentColor = LocalLessonColors.current.cancelled, shape = RoundedCornerShape(10.dp)) {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
            card.footnote?.let {
                Spacer(Modifier.height(14.dp))
                HorizontalDivider(color = colors.onPrimary.copy(alpha = 0.24f))
                Spacer(Modifier.height(12.dp))
                Text(text = it, style = MaterialTheme.typography.bodyMedium, color = colors.onPrimary.copy(alpha = 0.86f))
            }
        }
    }
}

@Composable
private fun DayHeader(day: DaySummary, now: Instant) {
    val lessonColors = LocalLessonColors.current
    Column(modifier = Modifier.fillMaxWidth().padding(top = 28.dp, bottom = 6.dp)) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text(
                text = ChangeFormatter.dayLabel(day.day, now).capitalizedFirst(),
                style = MaterialTheme.typography.titleLarge,
            )
            day.span?.let {
                Text(text = it, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (day.cancelledCount > 0) {
            Text(
                text = stringResource(R.string.day_cancelled_count, day.cancelledCount),
                style = MaterialTheme.typography.labelLarge,
                color = lessonColors.cancelled,
            )
        }
        Spacer(Modifier.height(6.dp))
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}

/** A school-year event of the day, such as a holiday. */
@Composable
private fun EventRow(event: Lesson) {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
    ) {
        Text(
            text = event.displayName,
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
        )
    }
}

@Composable
private fun EmptyTimetable() {
    Column(modifier = Modifier.fillMaxWidth().padding(top = 36.dp)) {
        Text(text = stringResource(R.string.timetable_empty_title), style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(6.dp))
        Text(
            text = stringResource(R.string.timetable_empty_body),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SyncedAt(syncedAt: Instant, now: Instant) {
    Text(
        text = stringResource(
            R.string.timetable_synced_at,
            ChangeFormatter.dayLabel(syncedAt, now).lowercase(HUNGARIAN),
            KretaDate.timeString(syncedAt),
        ),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 28.dp),
    )
}
