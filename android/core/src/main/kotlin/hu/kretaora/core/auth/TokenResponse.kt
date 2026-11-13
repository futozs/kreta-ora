package hu.kretaora.core.auth

import hu.kretaora.core.KretaException
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull
import java.time.Instant

private fun parseObject(text: String): JsonObject? =
    try {
        Json.parseToJsonElement(text) as? JsonObject
    } catch (_: SerializationException) {
        null
    }

/** The JSON body of `connect/token`. */
internal data class TokenResponse(
    val accessToken: String,
    val refreshToken: String?,
    val idToken: String?,
    val expiresIn: Long,
) {
    /**
     * Builds the token set, keeping the previous refresh token when the
     * server did not rotate it.
     */
    fun tokenSet(previous: TokenSet?, now: Instant): TokenSet {
        val refresh = listOfNotNull(refreshToken, previous?.refreshToken).firstOrNull { it.isNotEmpty() }
        if (accessToken.isEmpty() || refresh == null) throw KretaException.BadResponse()
        return TokenSet(
            accessToken = accessToken,
            refreshToken = refresh,
            expiresAt = now.plusSeconds(expiresIn),
        )
    }

    companion object {
        fun parse(body: ByteArray): TokenResponse {
            val fields = parseObject(String(body, Charsets.UTF_8)) ?: throw KretaException.BadResponse()
            return TokenResponse(
                accessToken = optionalText(fields, "access_token") ?: throw KretaException.BadResponse(),
                refreshToken = optionalText(fields, "refresh_token"),
                idToken = optionalText(fields, "id_token"),
                expiresIn = lifetime(fields["expires_in"]) ?: throw KretaException.BadResponse(),
            )
        }

        /** Absent and null are fine; any other non-text value is a bad response. */
        private fun optionalText(fields: JsonObject, name: String): String? =
            when (val value = fields[name]) {
                null, JsonNull -> null
                is JsonPrimitive -> if (value.isString) value.content else throw KretaException.BadResponse()
                is JsonObject, is JsonArray -> throw KretaException.BadResponse()
            }

        /** KRÉTA has been seen sending the lifetime both as a number and as text. */
        private fun lifetime(value: JsonElement?): Long? {
            val primitive = value as? JsonPrimitive ?: return null
            return if (primitive.isString) primitive.content.toLongOrNull() else primitive.longOrNull
        }
    }
}

/**
 * The claims of the identity token that the login needs.
 *
 * The token arrives over TLS straight from the token endpoint, so the claims
 * are read without an independent signature check.
 */
internal data class IdTokenClaims(
    val nonce: String?,
    val audiences: List<String>,
    val institutionCode: String?,
    val userName: String?,
    val userId: String?,
    val name: String?,
) {
    companion object {
        private const val JWT_PARTS = 3

        fun parse(jwt: String): IdTokenClaims {
            val parts = jwt.split(".")
            val claims = parts.takeIf { it.size == JWT_PARTS }
                ?.let { Encoding.base64UrlDecode(it[1]) }
                ?.let { parseObject(String(it, Charsets.UTF_8)) }
                ?: throw KretaException.BadResponse()

            fun text(name: String): String? {
                val value = claims[name] as? JsonPrimitive ?: return null
                return value.content.takeIf { value !is JsonNull && it.isNotEmpty() }
            }

            val audiences = when (val audience = claims["aud"]) {
                is JsonArray -> audience.mapNotNull { (it as? JsonPrimitive)?.takeIf(JsonPrimitive::isString)?.content }
                is JsonPrimitive -> if (audience.isString) listOf(audience.content) else emptyList()
                else -> emptyList()
            }

            return IdTokenClaims(
                nonce = text("nonce"),
                audiences = audiences,
                institutionCode = text("kreta:institute_code"),
                userName = text("kreta:user_name"),
                userId = text("kreta:institute_user_id"),
                name = text("name"),
            )
        }
    }
}
