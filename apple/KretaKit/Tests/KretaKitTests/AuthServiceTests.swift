import Foundation
import Testing
@testable import KretaKit

@Suite("Auth service")
struct AuthServiceTests {
    private let now = Fixture.date(16, 8)

    private func claims(nonce: String, audience: Any = KretaConfig.clientID) -> [String: Any] {
        [
            "nonce": nonce,
            "aud": audience,
            "kreta:institute_code": "School-A",
            "kreta:user_name": "72345678901",
            "kreta:institute_user_id": 4711,
            "name": "Teszt Elek",
        ]
    }

    private func redirect(for attempt: LoginAttempt) -> URL {
        URL(string: "\(KretaConfig.redirectURI)?code=the-code&state=\(attempt.state)")!
    }

    private func service(_ transport: FakeTransport) -> AuthService {
        AuthService(api: KretaAPI(transport: transport))
    }

    @Test("exchanges the code with the verifier and builds the session")
    func completesLogin() async throws {
        let attempt = try LoginAttempt(now: now)
        let idToken = Fixture.jwt(claims(nonce: attempt.nonce, audience: ["other", KretaConfig.clientID]))
        let transport = FakeTransport { _, _ in .json(Fixture.tokenJSON(idToken: idToken)) }

        let session = try await service(transport).completeLogin(
            attempt: attempt, redirect: redirect(for: attempt), now: now
        )

        #expect(session.account.institutionCode == "school-a")
        #expect(session.account.userName == "72345678901")
        #expect(session.account.displayName == "Teszt Elek")
        #expect(session.account.id.count == 64)
        #expect(session.tokens.accessToken == "access-1")
        #expect(session.tokens.refreshToken == "refresh-1")
        #expect(session.tokens.expiresAt == now.addingTimeInterval(1800))

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://idp.e-kreta.hu/connect/token")
        #expect(request.httpMethod == "POST")
        #expect(request.form["code"] == "the-code")
        #expect(request.form["code_verifier"] == attempt.verifier)
        #expect(request.form["redirect_uri"] == KretaConfig.redirectURI)
        #expect(request.form["client_id"] == KretaConfig.clientID)
        #expect(request.form["grant_type"] == "authorization_code")
    }

    @Test("accepts a token lifetime sent as text")
    func acceptsTextLifetime() async throws {
        let attempt = try LoginAttempt(now: now)
        let idToken = Fixture.jwt(claims(nonce: attempt.nonce))
        let transport = FakeTransport { _, _ in
            .json(Fixture.tokenJSON(idToken: idToken, expiresIn: #""3600""#))
        }
        let session = try await service(transport).completeLogin(
            attempt: attempt, redirect: redirect(for: attempt), now: now
        )
        #expect(session.tokens.expiresAt == now.addingTimeInterval(3600))
    }

    @Test("rejects an identity token minted for another attempt")
    func rejectsWrongNonce() async throws {
        let attempt = try LoginAttempt(now: now)
        let idToken = Fixture.jwt(claims(nonce: "someone-else"))
        let transport = FakeTransport { _, _ in .json(Fixture.tokenJSON(idToken: idToken)) }
        await #expect(throws: KretaError.loginRejected) {
            try await service(transport).completeLogin(attempt: attempt, redirect: redirect(for: attempt), now: now)
        }
    }

    @Test("rejects an identity token for another client")
    func rejectsWrongAudience() async throws {
        let attempt = try LoginAttempt(now: now)
        let idToken = Fixture.jwt(claims(nonce: attempt.nonce, audience: "another-client"))
        let transport = FakeTransport { _, _ in .json(Fixture.tokenJSON(idToken: idToken)) }
        await #expect(throws: KretaError.loginRejected) {
            try await service(transport).completeLogin(attempt: attempt, redirect: redirect(for: attempt), now: now)
        }
    }

    @Test("a refused code is a rejected login, and no request is sent for a forged callback")
    func rejectsRefusedCode() async throws {
        let attempt = try LoginAttempt(now: now)
        let refusing = FakeTransport { _, _ in .json(#"{"error":"invalid_grant"}"#, status: 400) }
        await #expect(throws: KretaError.loginRejected) {
            try await service(refusing).completeLogin(attempt: attempt, redirect: redirect(for: attempt), now: now)
        }

        let untouched = FakeTransport { _, _ in .json("{}") }
        let forged = URL(string: "\(KretaConfig.redirectURI)?code=c&state=forged")!
        await #expect(throws: KretaError.loginRejected) {
            try await service(untouched).completeLogin(attempt: attempt, redirect: forged, now: now)
        }
        #expect(untouched.requests.isEmpty)
    }

    @Test(
        "malformed token responses are bad responses",
        arguments: [
            #"{"access_token":"a","refresh_token":"r","expires_in":60}"#,
            #"{"access_token":"a","refresh_token":"r","expires_in":60,"id_token":"not-a-jwt"}"#,
            #"{"access_token":"a","refresh_token":"r","expires_in":"soon","id_token":"a.b.c"}"#,
            "<html>maintenance</html>",
        ]
    )
    func rejectsMalformedResponse(body: String) async throws {
        let attempt = try LoginAttempt(now: now)
        let transport = FakeTransport { _, _ in .json(body) }
        await #expect(throws: KretaError.badResponse) {
            try await service(transport).completeLogin(attempt: attempt, redirect: redirect(for: attempt), now: now)
        }
    }

    @Test("identity token without the KRÉTA claims is a bad response")
    func rejectsMissingClaims() async throws {
        let attempt = try LoginAttempt(now: now)
        let idToken = Fixture.jwt(["nonce": attempt.nonce])
        let transport = FakeTransport { _, _ in .json(Fixture.tokenJSON(idToken: idToken)) }
        await #expect(throws: KretaError.badResponse) {
            try await service(transport).completeLogin(attempt: attempt, redirect: redirect(for: attempt), now: now)
        }
    }

    @Test("refresh sends the refresh grant and keeps the old refresh token when none comes back")
    func refreshes() async throws {
        let transport = FakeTransport { _, _ in .json(Fixture.tokenJSON(access: "access-2", refresh: nil)) }
        let old = Fixture.session(expiresAt: now)

        let renewed = try await service(transport).refresh(old, now: now)

        #expect(renewed.account == old.account)
        #expect(renewed.tokens.accessToken == "access-2")
        #expect(renewed.tokens.refreshToken == "refresh-0")
        let form = try #require(transport.requests.first).form
        #expect(form["grant_type"] == "refresh_token")
        #expect(form["refresh_token"] == "refresh-0")
        #expect(form["institute_code"] == "school-a")
        #expect(form["client_id"] == KretaConfig.clientID)
    }

    @Test("a rejected refresh token means the session expired", arguments: [400, 401])
    func refreshRejected(status: Int) async {
        let transport = FakeTransport { _, _ in .json("{}", status: status) }
        await #expect(throws: KretaError.sessionExpired) {
            try await service(transport).refresh(Fixture.session(expiresAt: now), now: now)
        }
    }

    @Test("a server error during refresh is not treated as an expired session")
    func refreshServerError() async {
        let transport = FakeTransport { _, _ in .json("{}", status: 503) }
        await #expect(throws: KretaError.http(503)) {
            try await service(transport).refresh(Fixture.session(expiresAt: now), now: now)
        }
    }
}
