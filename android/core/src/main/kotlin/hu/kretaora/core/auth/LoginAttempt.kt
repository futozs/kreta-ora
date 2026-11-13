package hu.kretaora.core.auth

import hu.kretaora.core.KretaConfig
import hu.kretaora.core.KretaException
import java.net.URI
import java.net.URISyntaxException
import java.time.Duration
import java.time.Instant

object InstitutionCode {
    private const val MAX_LABEL_LENGTH = 63

    /**
     * Normalizes an institution code and makes sure it is one DNS label, so it
     * can never point requests outside `*.e-kreta.hu`.
     */
    fun validate(raw: String): String {
        val value = raw.trim().lowercase()
        fun isAlphanumeric(character: Char) = character in '0'..'9' || character in 'a'..'z'
        val isValid = value.isNotEmpty() &&
            value.length <= MAX_LABEL_LENGTH &&
            isAlphanumeric(value.first()) &&
            isAlphanumeric(value.last()) &&
            value.all { isAlphanumeric(it) || it == '-' }
        if (!isValid) throw KretaException.InvalidInstitution()
        return value
    }
}

/**
 * One sign-in attempt: the hosted KRÉTA login URL plus the PKCE verifier,
 * state and nonce that the callback and the token response must match.
 */
class LoginAttempt private constructor(
    val state: String,
    val nonce: String,
    val verifier: String,
    val createdAt: Instant,
    /** Open this in a web view. The password is typed on KRÉTA's own page. */
    val url: String,
) {
    /**
     * Extracts the authorization code from the redirect, rejecting anything
     * that is not exactly the expected callback for this attempt.
     */
    fun authorizationCode(redirect: String, now: Instant = Instant.now()): String {
        val isAlive = Duration.between(createdAt, now) <= KretaConfig.LOGIN_ATTEMPT_LIFETIME
        val uri = parse(redirect)
        if (!isAlive || uri == null || !matchesRedirect(uri) || uri.rawUserInfo != null || uri.rawFragment != null) {
            throw KretaException.LoginRejected()
        }

        val items = Encoding.parseQuery(uri.rawQuery) ?: throw KretaException.LoginRejected()
        val states = items.filter { it.first == "state" }
        val codes = items.filter { it.first == "code" }
        val isExpected = items.none { it.first == "error" } && states.size == 1 && states[0].second == state
        val code = codes.singleOrNull()?.second?.takeIf { isExpected && it.isNotEmpty() }
        return code ?: throw KretaException.LoginRejected()
    }

    /** Never prints the secrets, so an attempt is safe to log. */
    override fun toString(): String = "LoginAttempt(createdAt=$createdAt)"

    companion object {
        private val expected = URI(KretaConfig.REDIRECT_URI)
        private const val HTTPS_PORT = 443

        fun create(
            institution: String? = null,
            username: String? = null,
            identityProvider: String = KretaConfig.IDENTITY_PROVIDER,
            now: Instant = Instant.now(),
        ): LoginAttempt {
            val state = Encoding.randomToken()
            val nonce = Encoding.randomToken()
            val verifier = Encoding.randomToken()
            val challenge = Encoding.base64Url(Encoding.sha256(verifier))

            val hints = listOfNotNull(
                username?.takeIf { it.isNotEmpty() }?.let { "login_hint" to it },
                institution?.takeIf { it.isNotBlank() }?.let { "institute_code" to InstitutionCode.validate(it) },
            )
            val parameters = listOf(
                "redirect_uri" to KretaConfig.REDIRECT_URI,
                "client_id" to KretaConfig.CLIENT_ID,
                "response_type" to "code",
                "prompt" to "login",
                "state" to state,
                "nonce" to nonce,
                "scope" to KretaConfig.SCOPES,
                "code_challenge" to challenge,
                "code_challenge_method" to "S256",
                "suppressed_prompt" to "login",
            ) + hints

            val returnUrl = "/connect/authorize/callback?" + Encoding.formEncode(parameters)
            val base = identityProvider.trimEnd('/')
            return LoginAttempt(
                state = state,
                nonce = nonce,
                verifier = verifier,
                createdAt = now,
                url = "$base/Account/Login?ReturnUrl=${Encoding.percentEncode(returnUrl)}",
            )
        }

        /**
         * True when a navigation target is the OAuth redirect, which the web
         * view must intercept instead of loading.
         */
        fun isRedirect(url: String): Boolean = parse(url)?.let(::matchesRedirect) ?: false

        private fun parse(url: String): URI? =
            try {
                URI(url)
            } catch (_: URISyntaxException) {
                null
            }

        private fun matchesRedirect(actual: URI): Boolean =
            actual.scheme == expected.scheme &&
                actual.host == expected.host &&
                (actual.port == -1 || actual.port == HTTPS_PORT) &&
                actual.rawPath == expected.rawPath
    }
}
