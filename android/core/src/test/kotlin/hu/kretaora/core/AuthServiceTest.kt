package hu.kretaora.core

import hu.kretaora.core.auth.AuthService
import hu.kretaora.core.auth.LoginAttempt
import hu.kretaora.core.net.KretaApi
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class AuthServiceTest {
    private val now = Fixture.date(16, 8)

    private fun claims(nonce: String, audience: String = "\"${KretaConfig.CLIENT_ID}\"") = """
        {"nonce": "$nonce", "aud": $audience, "kreta:institute_code": "School-A",
         "kreta:user_name": "72345678901", "kreta:institute_user_id": 4711, "name": "Teszt Elek"}
    """.trimIndent()

    private fun redirect(attempt: LoginAttempt) = "${KretaConfig.REDIRECT_URI}?code=the-code&state=${attempt.state}"

    private fun service(transport: FakeTransport) = AuthService(KretaApi(transport))

    @Test
    fun `exchanges the code with the verifier and builds the session`() = runTest {
        val attempt = LoginAttempt.create(now = now)
        val idToken = Fixture.jwt(claims(attempt.nonce, """["other", "${KretaConfig.CLIENT_ID}"]"""))
        val transport = FakeTransport { _, _ -> json(Fixture.tokenJson(idToken = idToken)) }

        val session = service(transport).completeLogin(attempt, redirect(attempt), now)

        assertEquals("school-a", session.account.institutionCode)
        assertEquals("72345678901", session.account.userName)
        assertEquals("Teszt Elek", session.account.displayName)
        assertEquals(64, session.account.id.length)
        assertEquals("access-1", session.tokens.accessToken)
        assertEquals("refresh-1", session.tokens.refreshToken)
        assertEquals(now.plusSeconds(1800), session.tokens.expiresAt)

        val request = transport.requests.first()
        assertEquals("https://idp.e-kreta.hu/connect/token", request.url)
        assertEquals("POST", request.method)
        assertEquals("the-code", request.form["code"])
        assertEquals(attempt.verifier, request.form["code_verifier"])
        assertEquals(KretaConfig.REDIRECT_URI, request.form["redirect_uri"])
        assertEquals(KretaConfig.CLIENT_ID, request.form["client_id"])
        assertEquals("authorization_code", request.form["grant_type"])
    }

    @Test
    fun `the account identifier is stable for the same user`() = runTest {
        suspend fun login(): String {
            val attempt = LoginAttempt.create(now = now)
            val idToken = Fixture.jwt(claims(attempt.nonce))
            val transport = FakeTransport { _, _ -> json(Fixture.tokenJson(idToken = idToken)) }
            return service(transport).completeLogin(attempt, redirect(attempt), now).account.id
        }
        assertEquals(login(), login())
    }

    @Test
    fun `accepts a token lifetime sent as text`() = runTest {
        val attempt = LoginAttempt.create(now = now)
        val idToken = Fixture.jwt(claims(attempt.nonce))
        val transport = FakeTransport { _, _ ->
            json(Fixture.tokenJson(idToken = idToken, expiresIn = "\"3600\""))
        }
        val session = service(transport).completeLogin(attempt, redirect(attempt), now)
        assertEquals(now.plusSeconds(3600), session.tokens.expiresAt)
    }

    @Test
    fun `rejects an identity token minted for another attempt`() = runTest {
        val attempt = LoginAttempt.create(now = now)
        val idToken = Fixture.jwt(claims("someone-else"))
        val transport = FakeTransport { _, _ -> json(Fixture.tokenJson(idToken = idToken)) }
        expectThrows<KretaException.LoginRejected> {
            service(transport).completeLogin(attempt, redirect(attempt), now)
        }
    }

    @Test
    fun `rejects an identity token for another client`() = runTest {
        val attempt = LoginAttempt.create(now = now)
        val idToken = Fixture.jwt(claims(attempt.nonce, "\"another-client\""))
        val transport = FakeTransport { _, _ -> json(Fixture.tokenJson(idToken = idToken)) }
        expectThrows<KretaException.LoginRejected> {
            service(transport).completeLogin(attempt, redirect(attempt), now)
        }
    }

    @Test
    fun `a refused code is a rejected login, and no request is sent for a forged callback`() = runTest {
        val attempt = LoginAttempt.create(now = now)
        val refusing = FakeTransport { _, _ -> json("""{"error":"invalid_grant"}""", status = 400) }
        expectThrows<KretaException.LoginRejected> {
            service(refusing).completeLogin(attempt, redirect(attempt), now)
        }

        val untouched = FakeTransport { _, _ -> json("{}") }
        val forged = "${KretaConfig.REDIRECT_URI}?code=c&state=forged"
        expectThrows<KretaException.LoginRejected> {
            service(untouched).completeLogin(attempt, forged, now)
        }
        assertTrue(untouched.requests.isEmpty())
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            """{"access_token":"a","refresh_token":"r","expires_in":60}""",
            """{"access_token":"a","refresh_token":"r","expires_in":60,"id_token":"not-a-jwt"}""",
            """{"access_token":"a","refresh_token":"r","expires_in":"soon","id_token":"a.b.c"}""",
            """{"access_token":7,"refresh_token":"r","expires_in":60,"id_token":"a.b.c"}""",
            """{"access_token":"a","refresh_token":["r"],"expires_in":60,"id_token":"a.b.c"}""",
            "<html>maintenance</html>",
        ],
    )
    fun `malformed token responses are bad responses`(body: String) = runTest {
        val attempt = LoginAttempt.create(now = now)
        val transport = FakeTransport { _, _ -> json(body) }
        expectThrows<KretaException.BadResponse> {
            service(transport).completeLogin(attempt, redirect(attempt), now)
        }
    }

    @Test
    fun `identity token without the KRETA claims is a bad response`() = runTest {
        val attempt = LoginAttempt.create(now = now)
        val idToken = Fixture.jwt("""{"nonce": "${attempt.nonce}"}""")
        val transport = FakeTransport { _, _ -> json(Fixture.tokenJson(idToken = idToken)) }
        expectThrows<KretaException.BadResponse> {
            service(transport).completeLogin(attempt, redirect(attempt), now)
        }
    }

    @Test
    fun `refresh sends the refresh grant and keeps the old refresh token when none comes back`() = runTest {
        val transport = FakeTransport { _, _ -> json(Fixture.tokenJson(access = "access-2", refresh = null)) }
        val old = Fixture.session(expiresAt = now)

        val renewed = service(transport).refresh(old, now)

        assertEquals(old.account, renewed.account)
        assertEquals("access-2", renewed.tokens.accessToken)
        assertEquals("refresh-0", renewed.tokens.refreshToken)
        val form = transport.requests.first().form
        assertEquals("refresh_token", form["grant_type"])
        assertEquals("refresh-0", form["refresh_token"])
        assertEquals("school-a", form["institute_code"])
        assertEquals(KretaConfig.CLIENT_ID, form["client_id"])
    }

    @ParameterizedTest
    @ValueSource(ints = [400, 401])
    fun `a rejected refresh token means the session expired`(status: Int) = runTest {
        val transport = FakeTransport { _, _ -> json("{}", status = status) }
        expectThrows<KretaException.SessionExpired> {
            service(transport).refresh(Fixture.session(expiresAt = now), now)
        }
    }

    @Test
    fun `a server error during refresh is not treated as an expired session`() = runTest {
        val transport = FakeTransport { _, _ -> json("{}", status = 503) }
        val error = expectThrows<KretaException.Http> {
            service(transport).refresh(Fixture.session(expiresAt = now), now)
        }
        assertEquals(503, error.status)
    }

    @Test
    fun `printing tokens does not reveal them`() {
        val session = Fixture.session(expiresAt = now)
        assertFalse(session.toString().contains("access-0"))
        assertFalse(session.toString().contains("refresh-0"))
    }
}
