package hu.kretaora.core.model

import java.util.Locale

private val HUNGARIAN: Locale = Locale.forLanguageTag("hu-HU")

/** First letter in upper case, using Hungarian casing rules. */
fun String.capitalizedFirst(): String = replaceFirstChar { it.uppercase(HUNGARIAN) }
