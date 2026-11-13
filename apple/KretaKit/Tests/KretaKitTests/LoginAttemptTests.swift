import Foundation
import Testing
@testable import KretaKit

@Suite("Login attempt")
struct LoginAttemptTests {
    /// The parameters KRÉTA will see after it decodes `ReturnUrl`.
    private func authorizeParameters(_ attempt: LoginAttempt) throws -> [String: String] {
        let login = try #require(URLComponents(url: attempt.url, resolvingAgainstBaseURL: false))
        #expect(login.host == "idp.e-kreta.hu")
        #expect(login.path == "/Account/Login")
        let returnURL = try #require(login.queryItems?.first { $0.name == "ReturnUrl" }?.value)
        #expect(returnURL.hasPrefix("/connect/authorize/callback?"))
        let callback = try #require(URLComponents(string: "https://idp.e-kreta.hu\(returnURL)"))
        return Dictionary(
            (callback.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        ) { first, _ in first }
    }

    @Test("builds the hosted login URL with PKCE and the mobile client")
    func buildsLoginURL() throws {
        let attempt = try LoginAttempt(institution: " School-A ", username: "72345678901")
        let parameters = try authorizeParameters(attempt)

        #expect(parameters["redirect_uri"] == KretaConfig.redirectURI)
        #expect(parameters["client_id"] == KretaConfig.clientID)
        #expect(parameters["response_type"] == "code")
        #expect(parameters["scope"] == KretaConfig.scopes)
        #expect(parameters["state"] == attempt.state)
        #expect(parameters["nonce"] == attempt.nonce)
        #expect(parameters["code_challenge_method"] == "S256")
        #expect(parameters["code_challenge"] == Encoding.base64URL(Encoding.sha256(attempt.verifier)))
        #expect(parameters["institute_code"] == "school-a")
        #expect(parameters["login_hint"] == "72345678901")
    }

    @Test("leaves out the optional hints when they are not given")
    func omitsOptionalHints() throws {
        let parameters = try authorizeParameters(try LoginAttempt(institution: "  "))
        #expect(parameters["institute_code"] == nil)
        #expect(parameters["login_hint"] == nil)
    }

    @Test("every attempt gets its own secrets")
    func uniqueSecrets() throws {
        let first = try LoginAttempt()
        let second = try LoginAttempt()
        #expect(first.verifier != second.verifier)
        #expect(first.state != second.state)
        #expect(first.nonce != second.nonce)
        #expect(first.verifier.count >= 43)
    }

    @Test("refuses an institution code that could leave the official domain")
    func rejectsBadInstitutionInURL() {
        #expect(throws: KretaError.invalidInstitution) {
            try LoginAttempt(institution: "evil.example")
        }
    }

    @Test("accepts the exact callback and returns its code")
    func acceptsCallback() throws {
        let attempt = try LoginAttempt()
        let redirect = URL(string: "\(KretaConfig.redirectURI)?code=abc%2B1&state=\(attempt.state)")!
        #expect(try attempt.authorizationCode(from: redirect) == "abc+1")
        #expect(LoginAttempt.isRedirect(redirect))
    }

    @Test(
        "rejects callbacks that are not exactly ours",
        arguments: [
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
        ]
    )
    func rejectsForgedCallback(template: String) throws {
        let attempt = try LoginAttempt()
        let redirect = try #require(URL(string: template.replacingOccurrences(of: "STATE", with: attempt.state)))
        #expect(throws: KretaError.loginRejected) {
            try attempt.authorizationCode(from: redirect)
        }
    }

    @Test("an attempt expires after fifteen minutes")
    func expires() throws {
        let started = Fixture.date(16, 8)
        let attempt = try LoginAttempt(now: started)
        let redirect = URL(string: "\(KretaConfig.redirectURI)?code=c&state=\(attempt.state)")!
        #expect(try attempt.authorizationCode(from: redirect, now: started.addingTimeInterval(899)) == "c")
        #expect(throws: KretaError.loginRejected) {
            try attempt.authorizationCode(from: redirect, now: started.addingTimeInterval(901))
        }
    }

    @Test("only the redirect itself is intercepted")
    func recognisesRedirect() {
        #expect(!LoginAttempt.isRedirect(URL(string: "https://idp.e-kreta.hu/Account/Login")!))
        #expect(!LoginAttempt.isRedirect(URL(string: "https://mobil.e-kreta.hu/")!))
    }

    @Test("normalizes valid institution codes")
    func normalizesInstitution() throws {
        #expect(try InstitutionCode.validate(" SCHOOL-123 ") == "school-123")
        #expect(try InstitutionCode.validate("a") == "a")
    }

    @Test(
        "rejects invalid institution codes",
        arguments: ["", "  ", "../evil", "x.evil", "x:443", "x@evil", "-x", "x-", "árvíz", "a b",
                    String(repeating: "a", count: 64)]
    )
    func rejectsInstitution(code: String) {
        #expect(throws: KretaError.invalidInstitution) {
            try InstitutionCode.validate(code)
        }
    }
}
