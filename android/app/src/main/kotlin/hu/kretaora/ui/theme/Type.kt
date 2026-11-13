package hu.kretaora.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import hu.kretaora.R

// Bricolage Grotesque speaks: day names, lesson names, lesson numbers. Its
// ink traps and uneven widths read as drawn rather than generated, which is
// the point. Hanken Grotesk does the reading work underneath, and sets every
// clock, because its figures can be made the same width.

private const val OPTICAL_SIZE = "opsz"

/** Bricolage at one optical size: the large cut is tighter and sharper than the small one. */
private fun bricolage(opticalSize: Float): FontFamily =
    FontFamily(
        listOf(600, 700, 800).map { weight ->
            Font(
                resId = R.font.bricolage_grotesque,
                weight = FontWeight(weight),
                variationSettings = FontVariation.Settings(
                    FontVariation.weight(weight),
                    FontVariation.Setting(OPTICAL_SIZE, opticalSize),
                ),
            )
        },
    )

private val BricolageDisplay = bricolage(opticalSize = 72f)
private val BricolageText = bricolage(opticalSize = 22f)

private val Hanken = FontFamily(
    listOf(400, 500, 600, 700, 800).map { weight ->
        Font(
            resId = R.font.hanken_grotesk,
            weight = FontWeight(weight),
            variationSettings = FontVariation.Settings(FontVariation.weight(weight)),
        )
    },
)

/** Every digit the same width, so a ticking clock does not jitter. */
private const val TABULAR = "tnum"

object KretaType {
    /** The question on the first screen. */
    val display = TextStyle(
        fontFamily = BricolageDisplay, fontWeight = FontWeight.W800,
        fontSize = 50.sp, lineHeight = 50.sp, letterSpacing = (-1.4).sp,
    )

    /** The day name above the timetable. */
    val dayTitle = TextStyle(
        fontFamily = BricolageDisplay, fontWeight = FontWeight.W800,
        fontSize = 42.sp, lineHeight = 44.sp, letterSpacing = (-1.1).sp,
    )

    /** The lesson that is running or comes next. */
    val blockTitleLarge = TextStyle(
        fontFamily = BricolageDisplay, fontWeight = FontWeight.W800,
        fontSize = 27.sp, lineHeight = 29.sp, letterSpacing = (-0.5).sp,
    )

    val blockTitle = TextStyle(
        fontFamily = BricolageText, fontWeight = FontWeight.W700,
        fontSize = 19.sp, lineHeight = 22.sp, letterSpacing = (-0.2).sp,
    )

    /** "3." in front of a lesson. */
    val number = TextStyle(
        fontFamily = BricolageText, fontWeight = FontWeight.W800,
        fontSize = 24.sp, lineHeight = 26.sp,
    )

    val headline = TextStyle(
        fontFamily = BricolageText, fontWeight = FontWeight.W700,
        fontSize = 24.sp, lineHeight = 28.sp, letterSpacing = (-0.3).sp,
    )

    /** The live countdown inside the running lesson. */
    val countdown = TextStyle(
        fontFamily = Hanken, fontWeight = FontWeight.W800,
        fontSize = 46.sp, lineHeight = 46.sp, letterSpacing = (-1.2).sp,
        fontFeatureSettings = TABULAR,
    )

    val time = TextStyle(
        fontFamily = Hanken, fontWeight = FontWeight.W700,
        fontSize = 15.sp, lineHeight = 19.sp, fontFeatureSettings = TABULAR,
    )

    // The quiet text is set at regular weight, so it stays apart from the bold
    // text even when the phone's "bold font" setting adds weight to everything.
    val body = TextStyle(fontFamily = Hanken, fontWeight = FontWeight.W400, fontSize = 16.sp, lineHeight = 23.sp)

    val small = TextStyle(fontFamily = Hanken, fontWeight = FontWeight.W400, fontSize = 13.5.sp, lineHeight = 18.sp)

    val strong = TextStyle(fontFamily = Hanken, fontWeight = FontWeight.W700, fontSize = 13.5.sp, lineHeight = 18.sp)

    val button = TextStyle(fontFamily = Hanken, fontWeight = FontWeight.W800, fontSize = 16.sp, lineHeight = 20.sp)
}
