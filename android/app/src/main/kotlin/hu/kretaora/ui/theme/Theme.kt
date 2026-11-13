package hu.kretaora.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight

// Direction: a school notebook. Warm paper and ink by day, a chalkboard by
// night, one board-green accent, and serif headings against a plain body face.

private val LightColors = lightColorScheme(
    primary = Color(0xFF1F5C4A),
    onPrimary = Color(0xFFFFFCF6),
    primaryContainer = Color(0xFFD7E8DF),
    onPrimaryContainer = Color(0xFF0E3328),
    background = Color(0xFFF6F2EA),
    onBackground = Color(0xFF1B1F1D),
    surface = Color(0xFFFFFCF6),
    onSurface = Color(0xFF1B1F1D),
    surfaceVariant = Color(0xFFEAE4D8),
    onSurfaceVariant = Color(0xFF5A605C),
    outline = Color(0xFFA39C8D),
    outlineVariant = Color(0xFFDAD3C5),
    error = Color(0xFFB3382C),
    onError = Color(0xFFFFFCF6),
    errorContainer = Color(0xFFF6DDD8),
    onErrorContainer = Color(0xFF5C1710),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF8FD6B8),
    onPrimary = Color(0xFF0B2A20),
    primaryContainer = Color(0xFF1D4A3C),
    onPrimaryContainer = Color(0xFFCFEBDD),
    background = Color(0xFF101614),
    onBackground = Color(0xFFECE8DF),
    surface = Color(0xFF171F1C),
    onSurface = Color(0xFFECE8DF),
    surfaceVariant = Color(0xFF222C28),
    onSurfaceVariant = Color(0xFFA6B0AA),
    outline = Color(0xFF6B7872),
    outlineVariant = Color(0xFF2C3833),
    error = Color(0xFFFF8A7A),
    onError = Color(0xFF4A0F08),
    errorContainer = Color(0xFF5C1D15),
    onErrorContainer = Color(0xFFFFDAD4),
)

/** Colours that carry meaning about a lesson, beyond the Material roles. */
@Immutable
data class LessonColors(
    val cancelled: Color,
    val substituted: Color,
    val test: Color,
)

private val LightLessonColors = LessonColors(
    cancelled = Color(0xFFB3382C),
    substituted = Color(0xFF9A6A12),
    test = Color(0xFF3F5BA9),
)

private val DarkLessonColors = LessonColors(
    cancelled = Color(0xFFFF8A7A),
    substituted = Color(0xFFF2B84B),
    test = Color(0xFF9DB4F5),
)

val LocalLessonColors = staticCompositionLocalOf { LightLessonColors }

private val KretaOraTypography: Typography = Typography().let { base ->
    base.copy(
        displaySmall = base.displaySmall.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold),
        headlineMedium = base.headlineMedium.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold),
        headlineSmall = base.headlineSmall.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold),
        titleLarge = base.titleLarge.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold),
        titleMedium = base.titleMedium.copy(fontWeight = FontWeight.SemiBold),
    )
}

@Composable
fun KretaOraTheme(content: @Composable () -> Unit) {
    val isDark = isSystemInDarkTheme()
    CompositionLocalProvider(LocalLessonColors provides if (isDark) DarkLessonColors else LightLessonColors) {
        MaterialTheme(
            colorScheme = if (isDark) DarkColors else LightColors,
            typography = KretaOraTypography,
            content = content,
        )
    }
}
