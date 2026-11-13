package hu.kretaora.ui.timetable

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LifecycleResumeEffect
import hu.kretaora.notify.LiveLesson
import hu.kretaora.widget.ExactAlarmPrompt
import hu.kretaora.widget.WidgetUpdater
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.capitalizedFirst
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.focusDay
import hu.kretaora.core.timetable.pagerDays
import hu.kretaora.core.timetable.summaryOf
import hu.kretaora.ui.AppState
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.design.rememberNow
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import java.util.Locale

private val HUNGARIAN: Locale = Locale.forLanguageTag("hu-HU")
private val LONG_DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("MMMM d.", HUNGARIAN)
private const val SCHOOL_DAYS = 5L
private const val MESSAGE_MILLIS = 5_000L

/**
 * The timetable: one day per page, swiped sideways. The header names the day
 * on screen, the strip under it shows where that day sits in its week.
 */
@Composable
fun TimetableScreen(
    state: AppState,
    onRefresh: () -> Unit,
    onSignOut: () -> Unit,
    onSignInAgain: () -> Unit,
    onDismissMessage: () -> Unit,
    onClockSurfacesChanged: () -> Unit,
) {
    val palette = Kreta.palette
    val now by rememberNow(Duration.ofSeconds(15))
    val today = KretaDate.localDate(now)
    val schedule = remember(state.snapshot) { state.snapshot?.schedule }
    val days = remember(state.snapshot, today) {
        state.snapshot?.pagerDays()?.takeIf { it.isNotEmpty() } ?: schoolWeekOf(today)
    }
    var showsAccount by rememberSaveable { mutableStateOf(false) }
    val context = LocalContext.current
    var asksForExactAlarms by remember { mutableStateOf(false) }
    var offersLiveLesson by remember { mutableStateOf(false) }
    LifecycleResumeEffect(Unit) {
        asksForExactAlarms = ExactAlarmPrompt.isDue(context)
        offersLiveLesson = LiveLesson.isOfferDue(context)
        onPauseOrDispose { }
    }
    val notice: (@Composable () -> Unit)? = when {
        asksForExactAlarms -> {
            {
                OfferNote(
                    body = stringResource(R.string.exact_alarm_body),
                    allow = stringResource(R.string.exact_alarm_allow),
                    onAllow = { context.startActivity(WidgetUpdater.exactAlarmSettings(context)) },
                    onLater = {
                        ExactAlarmPrompt.dismiss(context)
                        asksForExactAlarms = false
                    },
                )
            }
        }
        offersLiveLesson -> {
            {
                OfferNote(
                    body = stringResource(R.string.live_offer_body),
                    allow = stringResource(R.string.live_offer_allow),
                    onAllow = {
                        LiveLesson.setEnabled(context, true)
                        offersLiveLesson = false
                        asksForExactAlarms = ExactAlarmPrompt.isDue(context)
                        onClockSurfacesChanged()
                    },
                    onLater = {
                        LiveLesson.dismissOffer(context)
                        offersLiveLesson = false
                    },
                )
            }
        }
        else -> null
    }

    // A new window of days (the first sync, or a week rolling over) starts the pager afresh.
    key(days.first(), days.size) {
        val pager = rememberPagerState(initialPage = initialPage(days, schedule, now)) { days.size }
        val scope = rememberCoroutineScope()
        val selected = days[pager.currentPage.coerceIn(days.indices)]
        val todayPage = days.indexOf(today)

        Box(modifier = Modifier.fillMaxSize().background(palette.background)) {
            Column(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
                Header(
                    day = selected,
                    today = today,
                    summary = schedule?.let { summaryLine(it, selected) },
                    initials = initials(state.account?.displayName.orEmpty()),
                    onAccount = { showsAccount = true },
                )
                WeekStrip(
                    days = weekOf(selected, days).map { StripDay(it, hasCancellation(schedule, it, now)) },
                    selected = selected,
                    today = today,
                    onSelect = { day -> scope.launch { pager.animateScrollToPage(days.indexOf(day)) } },
                    modifier = Modifier.padding(horizontal = 12.dp),
                )
                Box(modifier = Modifier.fillMaxWidth().height(10.dp), contentAlignment = Alignment.Center) {
                    if (state.isSyncing) {
                        LinearProgressIndicator(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp).height(2.dp),
                            color = palette.accent,
                            trackColor = palette.surfaceHigh,
                        )
                    }
                }
                HorizontalPager(
                    state = pager,
                    modifier = Modifier.weight(1f),
                    beyondViewportPageCount = 1,
                    key = { days[it].toEpochDay() },
                ) { page ->
                    DayPage(
                        day = days[page],
                        schedule = schedule,
                        now = now,
                        isRefreshing = state.isSyncing && state.snapshot != null,
                        needsSignIn = state.needsSignIn,
                        onRefresh = onRefresh,
                        onSignInAgain = onSignInAgain,
                        notice = notice,
                    )
                }
            }

            Column(
                modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                AnimatedVisibility(
                    visible = todayPage >= 0 && pager.currentPage != todayPage,
                    enter = fadeIn() + slideInVertically { it / 2 },
                    exit = fadeOut() + slideOutVertically { it / 2 },
                ) {
                    Text(
                        text = stringResource(R.string.timetable_back_to_today),
                        style = KretaType.button,
                        color = palette.background,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(palette.text)
                            .pressable { scope.launch { pager.animateScrollToPage(todayPage) } }
                            .padding(horizontal = 22.dp, vertical = 14.dp),
                    )
                }
                // A session problem already has its own note at the top of the day.
                Message(text = state.message.takeIf { !state.needsSignIn }, onDismiss = onDismissMessage)
            }
        }
    }

    if (showsAccount) {
        AccountSheet(
            onClockSurfacesChanged = onClockSurfacesChanged,
            account = state.account,
            syncedAt = state.snapshot?.syncedAt,
            now = now,
            onRefresh = onRefresh,
            onSignOut = {
                showsAccount = false
                onSignOut()
            },
            onDismiss = { showsAccount = false },
        )
    }
}

@Composable
private fun Header(
    day: LocalDate,
    today: LocalDate,
    summary: AnnotatedString?,
    initials: String,
    onAccount: () -> Unit,
) {
    val palette = Kreta.palette
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 22.dp, end = 18.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            AnimatedContent(
                targetState = day,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "day",
            ) { shown ->
                Text(
                    text = KretaDate.weekdayName(shown).capitalizedFirst(),
                    style = KretaType.dayTitle,
                    color = palette.text,
                )
            }
            Text(
                text = buildAnnotatedString {
                    append(dateLine(day, today))
                    if (summary != null) {
                        append(" · ")
                        append(summary)
                    }
                },
                style = KretaType.small,
                color = palette.textDim,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Box(
            modifier = Modifier
                .padding(top = 6.dp)
                .size(42.dp)
                .clip(CircleShape)
                .border(1.5.dp, palette.outline, CircleShape)
                .pressable(onClick = onAccount),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = initials, style = KretaType.strong, color = palette.text)
        }
    }
}

/** A short notice above the system bar that goes away on its own or on a tap. */
@Composable
private fun Message(text: String?, onDismiss: () -> Unit) {
    val palette = Kreta.palette
    LaunchedEffect(text) {
        if (text != null) {
            delay(MESSAGE_MILLIS)
            onDismiss()
        }
    }
    AnimatedVisibility(visible = text != null, enter = fadeIn(), exit = fadeOut()) {
        Text(
            text = text.orEmpty(),
            style = KretaType.small,
            color = palette.text,
            modifier = Modifier
                .padding(top = 10.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(palette.surfaceHigh)
                .pressable(onClick = onDismiss)
                .padding(horizontal = 16.dp, vertical = 14.dp),
        )
    }
}

/** "Ma, november 13." for the three days around today, the plain date otherwise. */
@Composable
private fun dateLine(day: LocalDate, today: LocalDate): String {
    val date = day.format(LONG_DATE)
    val relative = when (day) {
        today -> stringResource(R.string.day_today)
        today.plusDays(1) -> stringResource(R.string.day_tomorrow)
        today.minusDays(1) -> stringResource(R.string.day_yesterday)
        else -> return date
    }
    return "$relative, $date"
}

/** "7 óra, 7:55–14:10 · 1 elmarad", the cancelled part in red. */
@Composable
private fun summaryLine(schedule: Schedule, day: LocalDate): AnnotatedString? {
    val summary = schedule.summaryOf(KretaDate.startOfDay(day))
    if (summary.lessons.isEmpty()) return null
    val danger = Kreta.palette.danger
    val cancelled = stringResource(R.string.day_cancelled_count, summary.cancelledCount)
    val span = summary.span
    return buildAnnotatedString {
        if (span != null) append(span.replace(" · ", ", "))
        if (summary.cancelledCount > 0) {
            if (length > 0) append(" · ")
            withStyle(SpanStyle(color = danger, fontWeight = KretaType.strong.fontWeight)) { append(cancelled) }
        }
    }
}

/** Opens on today while lessons remain, otherwise on the next school day. */
private fun initialPage(days: List<LocalDate>, schedule: Schedule?, now: Instant): Int {
    val focus = schedule?.focusDay(now)?.day?.let(KretaDate::localDate) ?: KretaDate.localDate(now)
    val page = days.indexOfFirst { !it.isBefore(focus) }
    return if (page >= 0) page else days.lastIndex
}

/** The pager days that share a week with [day]. */
private fun weekOf(day: LocalDate, days: List<LocalDate>): List<LocalDate> {
    val monday = day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    return days.filter { it.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)) == monday }
}

/** Monday to Friday of the week of [day], shown before the first timetable arrives. */
private fun schoolWeekOf(day: LocalDate): List<LocalDate> {
    val monday = day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    return (0 until SCHOOL_DAYS).map(monday::plusDays)
}

private fun hasCancellation(schedule: Schedule?, day: LocalDate, now: Instant): Boolean =
    schedule?.lessonsOn(day).orEmpty().any { it.isCancelled && it.end > now }

/** "Futó Zsombor" becomes "FZ". */
private fun initials(name: String): String =
    name.split(' ').filter { it.isNotBlank() }.take(2).joinToString("") { it.take(1).uppercase(HUNGARIAN) }
