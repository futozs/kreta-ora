package hu.kretaora.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// Direction: a hand-coloured timetable. The day is a stack of flat blocks,
// one solid colour per subject, on a warm near-black or a paper ground.
// Colour belongs to the lessons; the interface around them stays neutral and
// uses a single chalk yellow for "selected" and "now". No gradients, no
// glows, no blur: shape and fill carry the meaning.

/** The app's own colours. Material's scheme is derived from these. */
@Immutable
data class Palette(
    val isDark: Boolean,
    val background: Color,
    val surface: Color,
    val surfaceHigh: Color,
    val outline: Color,
    val text: Color,
    val textDim: Color,
    val textFaint: Color,
    /** Chalk yellow: the selected day, the primary button. Always a fill under [Ink], never text. */
    val accent: Color,
    /** Cancelled. */
    val danger: Color,
)

/** Text on a subject colour and on the accent. */
val Ink = Color(0xFF141413)

val DarkPalette = Palette(
    isDark = true,
    background = Color(0xFF111110),
    surface = Color(0xFF1C1C1A),
    surfaceHigh = Color(0xFF292926),
    outline = Color(0xFF3B3A36),
    text = Color(0xFFF3F0E7),
    textDim = Color(0xFFABA79C),
    textFaint = Color(0xFF77746B),
    accent = Color(0xFFFFD60A),
    danger = Color(0xFFFF6A55),
)

val LightPalette = Palette(
    isDark = false,
    background = Color(0xFFF3F0E8),
    surface = Color(0xFFFBF9F4),
    surfaceHigh = Color(0xFFE6E2D7),
    outline = Color(0xFFCDC8BA),
    text = Color(0xFF141413),
    textDim = Color(0xFF5F5C54),
    textFaint = Color(0xFF8F8C83),
    accent = Color(0xFFFFD60A),
    danger = Color(0xFFD63A27),
)

private val LocalPalette = staticCompositionLocalOf { DarkPalette }

/** Shorthand for the current palette: `Kreta.palette.text`. */
object Kreta {
    val palette: Palette
        @Composable
        @ReadOnlyComposable
        get() = LocalPalette.current
}

@Composable
fun KretaOraTheme(isDark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val palette = if (isDark) DarkPalette else LightPalette
    // Material components (the sheet, pull to refresh) read these.
    val base = if (isDark) darkColorScheme() else lightColorScheme()
    val scheme = base.copy(
        primary = palette.text,
        onPrimary = palette.background,
        background = palette.background,
        onBackground = palette.text,
        surface = palette.surface,
        onSurface = palette.text,
        surfaceVariant = palette.surfaceHigh,
        onSurfaceVariant = palette.textDim,
        surfaceContainerLowest = palette.background,
        surfaceContainerLow = palette.surface,
        surfaceContainer = palette.surface,
        surfaceContainerHigh = palette.surfaceHigh,
        surfaceContainerHighest = palette.surfaceHigh,
        outline = palette.outline,
        outlineVariant = palette.outline,
        error = palette.danger,
    )
    CompositionLocalProvider(LocalPalette provides palette) {
        MaterialTheme(
            colorScheme = scheme,
            typography = Typography(
                bodyLarge = KretaType.body,
                bodyMedium = KretaType.body,
                bodySmall = KretaType.small,
                labelLarge = KretaType.button,
            ),
            content = content,
        )
    }
}
