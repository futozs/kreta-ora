package hu.kretaora.core.model

import hu.kretaora.core.KretaConfig
import java.time.DateTimeException
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit

/** Date handling for KRÉTA payloads. School time is always Europe/Budapest. */
object KretaDate {
    private const val MIN_LENGTH = 19
    private const val MAX_OFFSET_HOURS = 14
    private val WEEKDAYS = listOf("hétfő", "kedd", "szerda", "csütörtök", "péntek", "szombat", "vasárnap")
    private val MONTHS = listOf(
        "jan.", "febr.", "márc.", "ápr.", "máj.", "jún.",
        "júl.", "aug.", "szept.", "okt.", "nov.", "dec.",
    )

    /**
     * Parses `yyyy-MM-ddTHH:mm:ss` with optional fractional seconds and an
     * optional `Z` or numeric offset. A value without a zone is school time.
     */
    fun parse(raw: String): Instant? {
        val text = raw.trim()
        if (text.length < MIN_LENGTH) return null

        fun number(range: IntRange): Int? =
            text.substring(range).takeIf { part -> part.all { it in '0'..'9' } }?.toIntOrNull()

        fun isAt(index: Int, characters: String) = text[index] in characters

        val year = number(0..3)
        val month = number(5..6)
        val day = number(8..9)
        val hour = number(11..12)
        val minute = number(14..15)
        val second = number(17..18)
        val hasSeparators = isAt(4, "-") && isAt(7, "-") && isAt(10, "T ") && isAt(13, ":") && isAt(16, ":")
        if (!hasSeparators || year == null || month == null || day == null ||
            hour == null || minute == null || second == null
        ) {
            return null
        }

        var index = MIN_LENGTH
        if (index < text.length && text[index] == '.') {
            index += 1
            while (index < text.length && text[index] in '0'..'9') index += 1
        }
        val zone: ZoneId = if (index < text.length) zone(text.substring(index)) ?: return null else KretaConfig.ZONE

        return try {
            LocalDateTime.of(year, month, day, hour, minute, second).atZone(zone).toInstant()
        } catch (_: DateTimeException) {
            null
        }
    }

    private fun zone(suffix: String): ZoneId? {
        if (suffix == "Z" || suffix == "z") return ZoneOffset.UTC
        val sign = suffix.first()
        val digits = suffix.drop(1).filter { it != ':' }
        if ((sign != '+' && sign != '-') || digits.length != 4 || !digits.all { it in '0'..'9' }) return null
        val hours = digits.take(2).toInt()
        val minutes = digits.takeLast(2).toInt()
        if (hours > MAX_OFFSET_HOURS || minutes >= 60) return null
        val seconds = (hours * 60 + minutes) * 60
        return ZoneOffset.ofTotalSeconds(if (sign == '-') -seconds else seconds)
    }

    /** The school day containing the instant. */
    fun localDate(instant: Instant): LocalDate = instant.atZone(KretaConfig.ZONE).toLocalDate()

    /** `yyyy-MM-dd` of the school day containing the instant. */
    fun dayString(instant: Instant): String = localDate(instant).toString()

    /** `H:mm` in school time. */
    fun timeString(instant: Instant): String {
        val time = instant.atZone(KretaConfig.ZONE)
        return "%d:%02d".format(time.hour, time.minute)
    }

    fun startOfDay(date: LocalDate): Instant = date.atStartOfDay(KretaConfig.ZONE).toInstant()

    fun startOfDay(instant: Instant): Instant = startOfDay(localDate(instant))

    fun addingDays(days: Int, instant: Instant): Instant =
        instant.atZone(KretaConfig.ZONE).plusDays(days.toLong()).toInstant()

    /** Whole school days from `start` to `end`; negative when `end` is earlier. */
    fun days(start: Instant, end: Instant): Int =
        ChronoUnit.DAYS.between(localDate(start), localDate(end)).toInt()

    fun isSameDay(first: Instant, second: Instant): Boolean = localDate(first) == localDate(second)

    /** "péntek" */
    fun weekdayName(date: LocalDate): String = WEEKDAYS[date.dayOfWeek.value - 1]

    /** "nov. 20." */
    fun shortDate(date: LocalDate): String = "${MONTHS[date.monthValue - 1]} ${date.dayOfMonth}."
}
