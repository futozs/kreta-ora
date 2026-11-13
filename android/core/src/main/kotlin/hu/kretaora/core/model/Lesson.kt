package hu.kretaora.core.model

import hu.kretaora.core.KretaException
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull
import java.time.Instant

/** One timetable entry, already normalized from the KRÉTA payload. */
@Serializable
data class Lesson(
    val id: String,
    @Serializable(with = InstantSerializer::class) val start: Instant,
    @Serializable(with = InstantSerializer::class) val end: Instant,
    val name: String,
    /** Position in the day (1st lesson, 2nd lesson, …) when the school numbers it. */
    val index: Int? = null,
    val teacher: String? = null,
    val substituteTeacher: String? = null,
    val room: String? = null,
    val topic: String? = null,
    val group: String? = null,
    val kind: Kind = Kind.LESSON,
    val isCancelled: Boolean = false,
    val hasTest: Boolean = false,
    val hasHomework: Boolean = false,
) {
    enum class Kind {
        /** A regular lesson. */
        LESSON,

        /** A free slot placeholder (`UresOra`). */
        EMPTY,

        /** A school-year event such as a holiday (`TanevRendjeEsemeny`). */
        EVENT,
    }

    /** A lesson that actually takes place. */
    val isActive: Boolean get() = kind == Kind.LESSON && !isCancelled

    val isSubstituted: Boolean get() = substituteTeacher != null

    /** The teacher who will actually be in the room. */
    val effectiveTeacher: String? get() = substituteTeacher ?: teacher

    /** Subject name with a capital first letter, as KRÉTA stores them lowercase. */
    val displayName: String get() = name.capitalizedFirst()

    fun contains(instant: Instant): Boolean = start <= instant && instant < end

    companion object {
        /** Timetable order: by start, then by identifier so ties are stable. */
        val ORDER: Comparator<Lesson> = compareBy<Lesson> { it.start }.thenBy { it.id }

        /**
         * Decodes the `OrarendElemek` array. Rows that cannot be understood are
         * skipped, so one odd entry cannot hide the whole timetable.
         */
        fun decodeList(body: ByteArray): List<Lesson> {
            val rows = try {
                Json.parseToJsonElement(String(body, Charsets.UTF_8)) as? JsonArray
            } catch (_: SerializationException) {
                null
            } ?: throw KretaException.BadResponse()
            return rows.mapNotNull { (it as? JsonObject)?.let(::fromRow) }.sortedWith(ORDER)
        }

        private fun fromRow(row: JsonObject): Lesson? {
            val id = row.text("Uid") ?: return null
            val start = row.text("KezdetIdopont")?.let(KretaDate::parse) ?: return null
            val end = row.text("VegIdopont")?.let(KretaDate::parse) ?: return null
            if (end <= start) return null

            val state = row.reference("Allapot")
            val stateText = listOfNotNull(state.name, state.description).joinToString(" ")

            return Lesson(
                id = id,
                start = start,
                end = end,
                name = row.text("Nev") ?: row.reference("Tantargy").name ?: "Óra",
                index = row.int("Oraszam"),
                teacher = row.text("TanarNeve"),
                substituteTeacher = row.text("HelyettesTanarNeve"),
                room = row.text("TeremNeve"),
                topic = row.text("Tema"),
                group = row.reference("OsztalyCsoport").name,
                kind = kind(row.reference("Tipus").name),
                isCancelled = stateText.contains("elmarad", ignoreCase = true),
                hasTest = row.text("BejelentettSzamonkeresUid") != null,
                hasHomework = row.text("HaziFeladatUid") != null,
            )
        }

        private fun kind(type: String?): Kind =
            when (type) {
                "UresOra" -> Kind.EMPTY
                "TanevRendjeEsemeny" -> Kind.EVENT
                else -> Kind.LESSON
            }
    }
}

private class Reference(val name: String?, val description: String?)

private fun JsonElement?.primitive(): JsonPrimitive? = (this as? JsonPrimitive)?.takeIf { it !is JsonNull }

/** A non-empty, trimmed string; whole numbers are accepted too. */
private fun JsonObject.text(name: String): String? {
    val value = this[name].primitive() ?: return null
    val raw = if (value.isString) value.content else value.longOrNull?.toString()
    return raw?.trim()?.takeIf { it.isNotEmpty() }
}

private fun JsonObject.int(name: String): Int? {
    val value = this[name].primitive() ?: return null
    return if (value.isString) value.content.toIntOrNull() else value.longOrNull?.toInt()
}

/**
 * The `Nev` and `Leiras` of a nested reference object, or the plain string
 * when the server sends one.
 */
private fun JsonObject.reference(name: String): Reference {
    val nested = this[name] as? JsonObject ?: return Reference(text(name), null)
    return Reference(nested.text("Nev"), nested.text("Leiras"))
}
