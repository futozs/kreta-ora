package hu.kretaora.core.net

import hu.kretaora.core.KretaConfig
import hu.kretaora.core.KretaException
import hu.kretaora.core.auth.Encoding
import hu.kretaora.core.auth.InstitutionCode
import hu.kretaora.core.auth.TokenResponse
import hu.kretaora.core.model.Lesson
import java.time.LocalDate

/**
 * The KRÉTA endpoints the timetable app needs: the token endpoint and the
 * student's own timetable.
 */
class KretaApi(
    private val transport: HttpTransport = OkHttpTransport(),
    private val identityProvider: String = KretaConfig.IDENTITY_PROVIDER,
    private val schoolBase: (String) -> String = { "https://$it.e-kreta.hu" },
) {
    internal suspend fun exchangeCode(code: String, verifier: String): TokenResponse =
        token(
            listOf(
                "code" to code,
                "code_verifier" to verifier,
                "redirect_uri" to KretaConfig.REDIRECT_URI,
                "client_id" to KretaConfig.CLIENT_ID,
                "grant_type" to "authorization_code",
            ),
        )

    internal suspend fun refreshToken(refreshToken: String, institution: String): TokenResponse =
        token(
            listOf(
                "institute_code" to institution,
                "refresh_token" to refreshToken,
                "grant_type" to "refresh_token",
                "client_id" to KretaConfig.CLIENT_ID,
            ),
        )

    /** Lessons between two school days, both inclusive. KRÉTA accepts at most 42 days. */
    suspend fun timetable(
        institution: String,
        accessToken: String,
        from: LocalDate,
        to: LocalDate,
    ): List<Lesson> {
        val school = InstitutionCode.validate(institution)
        val query = Encoding.formEncode(listOf("datumTol" to from.toString(), "datumIg" to to.toString()))
        val request = HttpRequest(
            method = "GET",
            url = "${schoolBase(school)}/ellenorzo/v3/sajat/OrarendElemek?$query",
            headers = mapOf(
                "Authorization" to "Bearer $accessToken",
                "apiKey" to KretaConfig.API_KEY,
                "Accept" to "application/json",
                "User-Agent" to KretaConfig.USER_AGENT,
            ),
        )

        val response = transport.send(request)
        when (response.status) {
            in SUCCESS -> Unit
            UNAUTHORIZED -> throw KretaException.Authentication()
            else -> throw KretaException.Http(response.status)
        }
        return Lesson.decodeList(bounded(response.body))
    }

    private suspend fun token(form: List<Pair<String, String>>): TokenResponse {
        val request = HttpRequest(
            method = "POST",
            url = "${identityProvider.trimEnd('/')}/connect/token",
            headers = mapOf(
                "Content-Type" to "application/x-www-form-urlencoded",
                "Accept" to "*/*",
                "User-Agent" to KretaConfig.USER_AGENT,
            ),
            body = Encoding.formEncode(form),
        )

        val response = transport.send(request)
        when (response.status) {
            in SUCCESS -> Unit
            BAD_REQUEST, UNAUTHORIZED -> throw KretaException.Authentication()
            else -> throw KretaException.Http(response.status)
        }
        return TokenResponse.parse(bounded(response.body))
    }

    private fun bounded(body: ByteArray): ByteArray {
        if (body.size > KretaConfig.MAX_RESPONSE_BYTES) throw KretaException.BadResponse()
        return body
    }

    private companion object {
        val SUCCESS = 200..299
        const val BAD_REQUEST = 400
        const val UNAUTHORIZED = 401
    }
}
