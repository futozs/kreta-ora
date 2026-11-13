package hu.kretaora.core

import java.time.Duration
import java.time.ZoneId

/**
 * Fixed parameters of the KRÉTA student mobile protocol.
 *
 * These are the public values the official student app uses. The API key is
 * not a secret: every client sends the same one.
 */
object KretaConfig {
    const val CLIENT_ID = "kreta-ellenorzo-student-mobile-android"
    const val REDIRECT_URI = "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect"
    val SCOPES: String = listOf(
        "openid", "email", "offline_access",
        "kreta-ellenorzo-webapi.public",
        "kreta-eugyintezes-webapi.public",
        "kreta-fileservice-webapi.public",
        "kreta-mobile-global-webapi.public",
        "kreta-dkt-webapi.public",
        "kreta-ier-webapi.public",
    ).joinToString(" ")
    const val USER_AGENT = "hu.ekreta.student/5.15.0/KretaOra/13/33"
    const val API_KEY = "21ff6c25-d1da-4a68-a811-c881a6057463"
    const val IDENTITY_PROVIDER = "https://idp.e-kreta.hu"
    val ZONE: ZoneId = ZoneId.of("Europe/Budapest")

    /** A started login must be finished within this window. */
    val LOGIN_ATTEMPT_LIFETIME: Duration = Duration.ofMinutes(15)

    /** Access tokens are refreshed this long before they actually expire. */
    val TOKEN_LEEWAY: Duration = Duration.ofSeconds(60)

    /** Upper bound for a JSON response body. */
    const val MAX_RESPONSE_BYTES = 16 * 1024 * 1024
}
