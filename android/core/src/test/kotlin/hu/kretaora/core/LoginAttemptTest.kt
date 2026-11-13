package hu.kretaora.core

import hu.kretaora.core.auth.Encoding
import hu.kretaora.core.auth.InstitutionCode
import hu.kretaora.core.auth.LoginAttempt
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import java.net.URI

class LoginAttemptTest {
    private val redirectBase = KretaConfig.REDIRECT_URI

    /** The parameters KRÉTA will see after it decodes `ReturnUrl`. */
    private fun authorizeParameters(attempt: LoginAttempt): Map<String, String?> {
        val login = URI(attempt.url)
        assertEquals("idp.e-kreta.hu", login.host)
        assertEquals("/Account/Login", login.path)
        val returnUrl = Encoding.parseQuery(login.rawQuery).orEmpty().first { it.first == "ReturnUrl" }.second.orEmpty()
        assertTrue(returnUrl.startsWith("/connect/authorize/callback?"))
        return Encoding.parseQuery(returnUrl.substringAfter("?")).orEmpty().toMap()
    }

    @Test
    fun `builds the hosted login URL with PKCE and the mobile client`() {
        val attempt = LoginAttempt.create(institution = " School-A ", username = "72345678901")
        val parameters = authorizeParameters(attempt)

        assertEquals(KretaConfig.REDIRECT_URI, parameters["redirect_uri"])
        assertEquals(KretaConfig.CLIENT_ID, parameters["client_id"])
        assertEquals("code", parameters["response_type"])
        assertEquals(KretaConfig.SCOPES, parameters["scope"])
        assertEquals(attempt.state, parameters["state"])
        assertEquals(attempt.nonce, parameters["nonce"])
        assertEquals("S256", parameters["code_challenge_method"])
        assertEquals(Encoding.base64Url(Encoding.sha256(attempt.verifier)), parameters["code_challenge"])
        assertEquals("school-a", parameters["institute_code"])
        assertEquals("72345678901", parameters["login_hint"])
    }

    @Test
    fun `leaves out the optional hints when they are not given`() {
        val parameters = authorizeParameters(LoginAttempt.create(institution = "  "))
        assertNull(parameters["institute_code"])
        assertNull(parameters["login_hint"])
    }

    @Test
    fun `every attempt gets its own secrets`() {
        val first = LoginAttempt.create()
        val second = LoginAttempt.create()
        assertNotEquals(first.verifier, second.verifier)
        assertNotEquals(first.state, second.state)
        assertNotEquals(first.nonce, second.nonce)
        assertTrue(first.verifier.length >= 43)
    }

    @Test
    fun `printing an attempt does not reveal its secrets`() {
        val attempt = LoginAttempt.create()
        assertFalse(attempt.toString().contains(attempt.verifier))
        assertFalse(attempt.toString().contains(attempt.state))
    }

    @Test
    fun `refuses an institution code that could leave the official domain`() {
        expectThrows<KretaException.InvalidInstitution> { LoginAttempt.create(institution = "evil.example") }
    }

    @Test
    fun `accepts the exact callback and returns its code`() {
        val attempt = LoginAttempt.create()
        val redirect = "$redirectBase?code=abc%2B1&state=${attempt.state}"
        assertEquals("abc+1", attempt.authorizationCode(redirect))
        assertTrue(LoginAttempt.isRedirect(redirect))
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            "https://evil.example/ellenorzo-student/prod/oauthredirect?code=c&state=STATE",
            "http://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&state=STATE",
            "https://mobil.e-kreta.hu:8443/ellenorzo-student/prod/oauthredirect?code=c&state=STATE",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/other?code=c&state=STATE",
            "https://user@mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&state=STATE",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&state=wrong",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&state=STATE&state=STATE",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&code=d&state=STATE",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=&state=STATE",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?state=STATE",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&state=STATE&error=denied",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=c&state=STATE#fragment",
            "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=%ZZ&state=STATE",
            "not a url",
        ],
    )
    fun `rejects callbacks that are not exactly ours`(template: String) {
        val attempt = LoginAttempt.create()
        expectThrows<KretaException.LoginRejected> {
            attempt.authorizationCode(template.replace("STATE", attempt.state))
        }
    }

    @Test
    fun `an attempt expires after fifteen minutes`() {
        val started = Fixture.date(16, 8)
        val attempt = LoginAttempt.create(now = started)
        val redirect = "$redirectBase?code=c&state=${attempt.state}"
        assertEquals("c", attempt.authorizationCode(redirect, started.plusSeconds(899)))
        expectThrows<KretaException.LoginRejected> {
            attempt.authorizationCode(redirect, started.plusSeconds(901))
        }
    }

    @Test
    fun `only the redirect itself is intercepted`() {
        assertFalse(LoginAttempt.isRedirect("https://idp.e-kreta.hu/Account/Login"))
        assertFalse(LoginAttempt.isRedirect("https://mobil.e-kreta.hu/"))
        assertFalse(LoginAttempt.isRedirect("about:blank"))
        assertFalse(LoginAttempt.isRedirect("not a url"))
        assertTrue(LoginAttempt.isRedirect("https://mobil.e-kreta.hu:443/ellenorzo-student/prod/oauthredirect"))
    }

    @Test
    fun `normalizes valid institution codes`() {
        assertEquals("school-123", InstitutionCode.validate(" SCHOOL-123 "))
        assertEquals("a", InstitutionCode.validate("a"))
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            "", "  ", "../evil", "x.evil", "x:443", "x@evil", "-x", "x-", "árvíz", "a b",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ],
    )
    fun `rejects invalid institution codes`(code: String) {
        expectThrows<KretaException.InvalidInstitution> { InstitutionCode.validate(code) }
    }
}
