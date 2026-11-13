import Foundation

/// The JSON body of `connect/token`.
struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        idToken = try container.decodeIfPresent(String.self, forKey: .idToken)
        // KRÉTA has been seen sending the lifetime both as a number and as text.
        if let seconds = try? container.decode(Int.self, forKey: .expiresIn) {
            expiresIn = seconds
        } else if let seconds = Int(try container.decode(String.self, forKey: .expiresIn)) {
            expiresIn = seconds
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .expiresIn, in: container, debugDescription: "expires_in is not a number"
            )
        }
    }

    /// Builds the token set, keeping the previous refresh token when the
    /// server did not rotate it.
    func tokenSet(previous: TokenSet?, now: Date) throws -> TokenSet {
        let refresh = [refreshToken, previous?.refreshToken]
            .compactMap { $0 }
            .first { !$0.isEmpty }
        guard !accessToken.isEmpty, let refresh else { throw KretaError.badResponse }
        return TokenSet(
            accessToken: accessToken,
            refreshToken: refresh,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

/// The claims of the identity token that the login needs.
///
/// The token arrives over TLS straight from the token endpoint, so the claims
/// are read without an independent signature check.
struct IDTokenClaims: Sendable {
    let nonce: String?
    let audiences: [String]
    let institutionCode: String?
    let userName: String?
    let userID: String?
    let name: String?

    init(jwt: String) throws {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let payload = Encoding.base64URLDecode(String(parts[1])),
            let claims = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        else { throw KretaError.badResponse }

        func text(_ key: String) -> String? {
            switch claims[key] {
            case let value as String: value.isEmpty ? nil : value
            case let value as NSNumber: value.stringValue
            default: nil
            }
        }

        nonce = text("nonce")
        institutionCode = text("kreta:institute_code")
        userName = text("kreta:user_name")
        userID = text("kreta:institute_user_id")
        name = text("name")
        switch claims["aud"] {
        case let value as String: audiences = [value]
        case let values as [Any]: audiences = values.compactMap { $0 as? String }
        default: audiences = []
        }
    }
}
