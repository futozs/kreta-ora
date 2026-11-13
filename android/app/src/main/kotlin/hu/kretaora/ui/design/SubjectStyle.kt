package hu.kretaora.ui.design

import androidx.compose.ui.graphics.Color
import java.text.Normalizer

/**
 * Gives every subject its colour, the way a student colours a paper
 * timetable. Known subjects get a fixed colour so maths is always the same
 * blue; anything else gets a stable one from its name, so it never changes
 * between launches. Every colour is light enough to carry near-black text.
 */
object Subjects {
    private val tangerine = Color(0xFFF59A3A)
    private val grass = Color(0xFF6CC474)
    private val teal = Color(0xFF3DBFAE)
    private val sky = Color(0xFF62B4EE)
    private val cobalt = Color(0xFF7B95F2)
    private val plum = Color(0xFFC08BE0)
    private val rose = Color(0xFFF088B2)
    private val olive = Color(0xFFB7C55C)
    private val sand = Color(0xFFD6B381)
    private val mint = Color(0xFF8BDABD)

    private val fallback = listOf(tangerine, grass, teal, sky, cobalt, plum, rose, olive, sand, mint)

    /** Checked in order, so the specific keywords come before the general ones. */
    private val known: List<Pair<List<String>, Color>> = listOf(
        listOf("gyogytestneveles") to mint,
        listOf("testneveles", "tesi", "sport") to grass,
        listOf("matematika", "matek") to cobalt,
        listOf("magyar", "irodalom", "nyelvtan") to rose,
        listOf("szakmai angol") to teal,
        listOf("angol", "nemet", "francia", "spanyol", "olasz", "latin", "idegen nyelv") to plum,
        listOf("tortenelem", "allampolgar") to sand,
        listOf("fizika") to sky,
        listOf("kemia") to olive,
        listOf("biologia", "termeszettudomany") to grass,
        listOf("foldrajz") to teal,
        listOf("informatika", "digitalis", "ikt", "programozas", "projekt", "halozat", "szoftver", "web") to tangerine,
        listOf("osztalyfonoki", "kozossegi") to olive,
        listOf("enek", "zene") to rose,
        listOf("rajz", "vizualis", "muveszet") to tangerine,
        listOf("etika", "hittan", "filozofia") to sand,
    )

    fun color(name: String): Color {
        val key = normalize(name)
        known.firstOrNull { (keywords, _) -> keywords.any(key::contains) }?.let { return it.second }
        val hash = key.fold(0) { sum, character -> (sum * 31 + character.code) and 0x7FFFFFFF }
        return fallback[hash % fallback.size]
    }

    /** Lower case without accents, so "Történelem" matches "tortenelem". */
    private fun normalize(text: String): String =
        Normalizer.normalize(text.lowercase(), Normalizer.Form.NFD).filter { it.code !in 0x300..0x36F }
}
