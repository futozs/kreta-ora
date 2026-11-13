package hu.kretaora.ui.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.auth.Account
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.timetable.ChangeFormatter
import hu.kretaora.notify.LiveLesson
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.theme.Ink
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import java.time.Instant

/** Who is signed in, how fresh the timetable is, and the way out. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSheet(
    onClockSurfacesChanged: () -> Unit,
    account: Account?,
    syncedAt: Instant?,
    now: Instant,
    onRefresh: () -> Unit,
    onSignOut: () -> Unit,
    onDismiss: () -> Unit,
) {
    val palette = Kreta.palette
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = palette.surface,
        contentColor = palette.text,
        shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(start = 24.dp, end = 24.dp, bottom = 24.dp),
        ) {
            Text(text = account?.displayName.orEmpty(), style = KretaType.headline, color = palette.text)
            Text(
                text = account?.institutionCode.orEmpty(),
                style = KretaType.small,
                color = palette.textDim,
                modifier = Modifier.padding(top = 4.dp),
            )
            if (syncedAt != null) {
                Text(
                    text = stringResource(
                        R.string.timetable_synced_at,
                        ChangeFormatter.dayLabel(syncedAt, now).lowercase(),
                        KretaDate.timeString(syncedAt),
                    ),
                    style = KretaType.small,
                    color = palette.textDim,
                    modifier = Modifier.padding(top = 18.dp),
                )
            }
            LiveLessonSwitch(onChanged = onClockSurfacesChanged)
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = stringResource(R.string.timetable_refresh),
                    style = KretaType.button,
                    color = palette.text,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(palette.surfaceHigh)
                        .pressable(onClick = onRefresh)
                        .padding(horizontal = 20.dp, vertical = 13.dp),
                )
                Text(
                    text = stringResource(R.string.timetable_sign_out),
                    style = KretaType.button,
                    color = palette.danger,
                    modifier = Modifier
                        .clip(CircleShape)
                        .pressable(onClick = onSignOut)
                        .padding(horizontal = 20.dp, vertical = 13.dp),
                )
            }
            Text(
                text = stringResource(R.string.account_note),
                style = KretaType.small,
                color = palette.textFaint,
                modifier = Modifier.padding(top = 22.dp),
            )
        }
    }
}

/** Turns the school-day notification on or off. */
@Composable
private fun LiveLessonSwitch(onChanged: () -> Unit) {
    val palette = Kreta.palette
    val context = LocalContext.current
    var isOn by remember { mutableStateOf(LiveLesson.isEnabled(context)) }
    val toggle = {
        isOn = !isOn
        LiveLesson.setEnabled(context, isOn)
        onChanged()
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 22.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(palette.surfaceHigh)
            .toggleable(value = isOn, role = Role.Switch, onValueChange = { toggle() })
            .padding(start = 18.dp, end = 14.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = stringResource(R.string.live_toggle_title), style = KretaType.strong, color = palette.text)
            Text(
                text = stringResource(R.string.live_toggle_body),
                style = KretaType.small,
                color = palette.textDim,
                modifier = Modifier.padding(top = 3.dp),
            )
        }
        Switch(
            checked = isOn,
            onCheckedChange = null,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Ink,
                checkedTrackColor = palette.accent,
                checkedBorderColor = palette.accent,
                uncheckedThumbColor = palette.textDim,
                uncheckedTrackColor = palette.surface,
                uncheckedBorderColor = palette.outline,
            ),
        )
    }
}
