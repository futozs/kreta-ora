package hu.kretaora.ui.timetable

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import hu.kretaora.core.model.KretaDate
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.theme.Ink
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import java.time.LocalDate

/** What the strip needs to know about one day. */
data class StripDay(
    val date: LocalDate,
    /** A lesson of this day that is still ahead has been cancelled. */
    val hasCancellation: Boolean,
)

private val WEEKDAY_LETTERS = listOf("H", "K", "Sze", "Cs", "P", "Szo", "V")

/**
 * The week of the selected day, one cell per day. The selected day sits on a
 * chalk-yellow disc, today wears a ring, and a red dot warns of a cancelled
 * lesson before the day is even opened.
 */
@Composable
fun WeekStrip(
    days: List<StripDay>,
    selected: LocalDate,
    today: LocalDate,
    onSelect: (LocalDate) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier = modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        days.forEach { day ->
            DayCell(
                day = day,
                isSelected = day.date == selected,
                isToday = day.date == today,
                onSelect = { onSelect(day.date) },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun DayCell(
    day: StripDay,
    isSelected: Boolean,
    isToday: Boolean,
    onSelect: () -> Unit,
    modifier: Modifier,
) {
    val palette = Kreta.palette
    val disc by animateColorAsState(if (isSelected) palette.accent else Color.Transparent, label = "disc")
    val number by animateColorAsState(if (isSelected) Ink else palette.text, label = "number")
    val description = "${KretaDate.weekdayName(day.date)}, ${KretaDate.shortDate(day.date)}"

    Column(
        modifier = modifier
            .pressable(onClick = onSelect)
            .semantics {
                contentDescription = description
                selected = isSelected
            }
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = WEEKDAY_LETTERS[day.date.dayOfWeek.value - 1],
            style = KretaType.strong,
            color = if (isSelected) palette.text else palette.textFaint,
        )
        Box(
            modifier = Modifier
                .size(46.dp)
                .clip(CircleShape)
                .background(disc)
                .then(
                    if (isToday && !isSelected) Modifier.border(1.5.dp, palette.text, CircleShape) else Modifier,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = day.date.dayOfMonth.toString(), style = KretaType.blockTitle, color = number)
        }
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(if (day.hasCancellation) palette.danger else Color.Transparent),
        )
    }
}
