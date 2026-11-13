package hu.kretaora.core.auth

import hu.kretaora.core.KretaConfig
import hu.kretaora.core.KretaException
import hu.kretaora.core.net.KretaApi
import java.time.Instant

/** Turns a finished web login into a session, and renews sessions. */
class AuthService(private val api: KretaApi = KretaApi()) {
    /**
     * Exchanges the authorization code from the redirect for tokens and
     * checks that the identity token belongs to this attempt.
     */
    suspend fun completeLogin(
        attempt: LoginAttempt,
        redirect: String,
        now: Instant = Instant.now(),
    ): Session {
        val code = attempt.authorizationCode(redirect, now)
        val response = try {
            api.exchangeCode(code, attempt.verifier)
        } catch (_: KretaException.Authentication) {
            throw KretaException.LoginRejected()
        }

        val claims = IdTokenClaims.parse(response.idToken ?: throw KretaException.BadResponse())
        val isForThisAttempt = claims.nonce == attempt.nonce &&
            (claims.audiences.isEmpty() || KretaConfig.CLIENT_ID in claims.audiences)
        if (!isForThisAttempt) throw KretaException.LoginRejected()
        if (claims.institutionCode == null || claims.userName == null || claims.userId == null) {
            throw KretaException.BadResponse()
        }

        val institution = InstitutionCode.validate(claims.institutionCode)
        val account = Account(
            id = Encoding.hex(Encoding.sha256("$institution\u0000${claims.userId}")),
            institutionCode = institution,
            userName = claims.userName,
            displayName = claims.name ?: claims.userName,
        )
        return Session(account, response.tokenSet(previous = null, now = now))
    }

    /**
     * Uses the refresh token. A rejected refresh means the user has to sign
     * in again.
     */
    suspend fun refresh(session: Session, now: Instant = Instant.now()): Session {
        val response = try {
            api.refreshToken(session.tokens.refreshToken, session.account.institutionCode)
        } catch (_: KretaException.Authentication) {
            throw KretaException.SessionExpired()
        }
        return Session(session.account, response.tokenSet(previous = session.tokens, now = now))
    }
}
