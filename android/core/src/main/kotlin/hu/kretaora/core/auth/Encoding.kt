package hu.kretaora.core.auth

import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

internal object Encoding {
    private const val UNRESERVED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    private const val HEX_DIGITS = "0123456789ABCDEF"
    private val random = SecureRandom()

    fun base64Url(bytes: ByteArray): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

    fun base64UrlDecode(text: String): ByteArray? =
        try {
            Base64.getUrlDecoder().decode(text)
        } catch (_: IllegalArgumentException) {
            null
        }

    /** 256 bits from the system CSPRNG, URL-safe. */
    fun randomToken(): String = base64Url(ByteArray(32).also(random::nextBytes))

    fun sha256(text: String): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))

    fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }

    /**
     * Percent-encodes everything except RFC 3986 unreserved characters, so the
     * result is safe both as a query value and as a form body value.
     */
    fun percentEncode(text: String): String = buildString {
        for (byte in text.toByteArray(Charsets.UTF_8)) {
            val value = byte.toInt() and 0xFF
            val character = value.toChar()
            if (character in UNRESERVED) {
                append(character)
            } else {
                append('%').append(HEX_DIGITS[value shr 4]).append(HEX_DIGITS[value and 0x0F])
            }
        }
    }

    fun formEncode(pairs: List<Pair<String, String>>): String =
        pairs.joinToString("&") { (name, value) -> "${percentEncode(name)}=${percentEncode(value)}" }

    /** Decodes `%XX` sequences as UTF-8. A plus sign stays a plus sign. Null when malformed. */
    fun percentDecode(text: String): String? {
        val bytes = ArrayList<Byte>(text.length)
        var index = 0
        while (index < text.length) {
            val character = text[index]
            if (character != '%') {
                character.toString().toByteArray(Charsets.UTF_8).forEach(bytes::add)
                index += 1
                continue
            }
            val value = text.substring(index + 1, minOf(index + 3, text.length))
                .takeIf { it.length == 2 }
                ?.toIntOrNull(16)
                ?: return null
            bytes.add(value.toByte())
            index += 3
        }
        return String(bytes.toByteArray(), Charsets.UTF_8)
    }

    /** Splits a raw query into decoded name and value pairs. Null when malformed. */
    fun parseQuery(rawQuery: String?): List<Pair<String, String?>>? {
        if (rawQuery.isNullOrEmpty()) return emptyList()
        return rawQuery.split("&").map { piece ->
            val separator = piece.indexOf('=')
            val name = percentDecode(if (separator < 0) piece else piece.substring(0, separator)) ?: return null
            val value = if (separator < 0) null else percentDecode(piece.substring(separator + 1)) ?: return null
            name to value
        }
    }
}
