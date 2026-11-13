import Foundation

/// Turns a finished web login into a session, and renews sessions.
public struct AuthService: Sendable {
    private let api: KretaAPI

    public init(api: KretaAPI = KretaAPI()) {
        self.api = api
    }

    /// Exchanges the authorization code from the redirect for tokens and
    /// checks that the identity token belongs to this attempt.
    public func completeLogin(
        attempt: LoginAttempt,
        redirect: URL,
        now: Date = Date()
    ) async throws -> Session {
        let code = try attempt.authorizationCode(from: redirect, now: now)
        let response: TokenResponse
        do {
            response = try await api.exchangeCode(code, verifier: attempt.verifier)
        } catch KretaError.authentication {
            throw KretaError.loginRejected
        }

        guard let idToken = response.idToken else { throw KretaError.badResponse }
        let claims = try IDTokenClaims(jwt: idToken)
        guard
            claims.nonce == attempt.nonce,
            claims.audiences.isEmpty || claims.audiences.contains(KretaConfig.clientID)
        else { throw KretaError.loginRejected }
        guard
            let rawInstitution = claims.institutionCode,
            let userName = claims.userName,
            let userID = claims.userID
        else { throw KretaError.badResponse }

        let institution = try InstitutionCode.validate(rawInstitution)
        let account = Account(
            id: Encoding.hex(Encoding.sha256("\(institution)\u{0}\(userID)")),
            institutionCode: institution,
            userName: userName,
            displayName: claims.name ?? userName
        )
        return Session(account: account, tokens: try response.tokenSet(previous: nil, now: now))
    }

    /// Uses the refresh token. A rejected refresh means the user has to sign
    /// in again.
    public func refresh(_ session: Session, now: Date = Date()) async throws -> Session {
        let response: TokenResponse
        do {
            response = try await api.refreshToken(
                session.tokens.refreshToken,
                institution: session.account.institutionCode
            )
        } catch KretaError.authentication {
            throw KretaError.sessionExpired
        }
        return Session(
            account: session.account,
            tokens: try response.tokenSet(previous: session.tokens, now: now)
        )
    }
}
