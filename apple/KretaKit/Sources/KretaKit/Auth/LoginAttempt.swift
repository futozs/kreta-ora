import Foundation

public enum InstitutionCode {
    /// Normalizes an institution code and makes sure it is one DNS label, so it
    /// can never point requests outside `*.e-kreta.hu`.
    public static func validate(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bytes = Array(value.utf8)
        func isAlphanumeric(_ byte: UInt8) -> Bool {
            (byte >= 0x30 && byte <= 0x39) || (byte >= 0x61 && byte <= 0x7A)
        }
        guard
            let first = bytes.first, let last = bytes.last,
            bytes.count <= 63,
            isAlphanumeric(first), isAlphanumeric(last),
            bytes.allSatisfy({ isAlphanumeric($0) || $0 == 0x2D })
        else { throw KretaError.invalidInstitution }
        return value
    }
}

/// One sign-in attempt: the hosted KRÉTA login URL plus the PKCE verifier,
/// state and nonce that the callback and the token response must match.
public struct LoginAttempt: Sendable, Equatable, Identifiable {
    public let state: String
    public let nonce: String
    public let verifier: String
    public let createdAt: Date
    /// Open this in a web view. The password is typed on KRÉTA's own page.
    public let url: URL

    public var id: String { state }

    public init(
        institution: String? = nil,
        username: String? = nil,
        identityProvider: URL = KretaConfig.identityProvider,
        now: Date = Date()
    ) throws {
        let state = Encoding.randomToken()
        let nonce = Encoding.randomToken()
        let verifier = Encoding.randomToken()
        let challenge = Encoding.base64URL(Encoding.sha256(verifier))

        var parameters: [(String, String)] = [
            ("redirect_uri", KretaConfig.redirectURI),
            ("client_id", KretaConfig.clientID),
            ("response_type", "code"),
            ("prompt", "login"),
            ("state", state),
            ("nonce", nonce),
            ("scope", KretaConfig.scopes),
            ("code_challenge", challenge),
            ("code_challenge_method", "S256"),
            ("suppressed_prompt", "login"),
        ]
        if let username, !username.isEmpty {
            parameters.append(("login_hint", username))
        }
        if let institution, !institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parameters.append(("institute_code", try InstitutionCode.validate(institution)))
        }

        let returnURL = "/connect/authorize/callback?" + Encoding.formEncode(parameters)
        var base = identityProvider.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/Account/Login?ReturnUrl=\(Encoding.percentEncode(returnURL))") else {
            throw KretaError.loginRejected
        }

        self.state = state
        self.nonce = nonce
        self.verifier = verifier
        self.createdAt = now
        self.url = url
    }

    /// True when a navigation target is the OAuth redirect, which the web view
    /// must intercept instead of loading.
    public static func isRedirect(_ url: URL) -> Bool {
        guard
            let expected = URLComponents(string: KretaConfig.redirectURI),
            let actual = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return false }
        return actual.scheme == expected.scheme
            && actual.host == expected.host
            && (actual.port == nil || actual.port == 443)
            && actual.path == expected.path
    }

    /// Extracts the authorization code from the redirect, rejecting anything
    /// that is not exactly the expected callback for this attempt.
    public func authorizationCode(from redirect: URL, now: Date = Date()) throws -> String {
        guard
            now.timeIntervalSince(createdAt) <= KretaConfig.loginAttemptLifetime,
            Self.isRedirect(redirect),
            let components = URLComponents(url: redirect, resolvingAgainstBaseURL: false),
            components.user == nil, components.password == nil, components.fragment == nil
        else { throw KretaError.loginRejected }

        let items = components.queryItems ?? []
        let states = items.filter { $0.name == "state" }
        let codes = items.filter { $0.name == "code" }
        guard
            !items.contains(where: { $0.name == "error" }),
            states.count == 1, states[0].value == state,
            codes.count == 1, let code = codes[0].value, !code.isEmpty
        else { throw KretaError.loginRejected }
        return code
    }
}
