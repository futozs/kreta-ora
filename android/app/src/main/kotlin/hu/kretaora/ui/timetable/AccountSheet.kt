package hu.kretaora.ui.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import hu.kretaora.R
import hu.kretaora.core.auth.Account
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.timetable.ChangeFormatter
import hu.kretaora.ui.design.pressable
import hu.kretaora.ui.theme.Kreta
import hu.kretaora.ui.theme.KretaType
import java.time.Instant

/** Who is signed in, how fresh the timetable is, and the way out. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSheet(
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
