import Foundation

public enum KretaError: Error, Equatable, Sendable {
    /// The institution code is not a single valid DNS label.
    case invalidInstitution
    /// The login callback or the identity token did not match the attempt.
    case loginRejected
    /// The server rejected the access token.
    case authentication
    /// The refresh token is no longer accepted; the user has to sign in again.
    case sessionExpired
    /// There is no stored session.
    case notLoggedIn
    /// The server answered with an unexpected status code.
    case http(Int)
    /// The response body could not be understood.
    case badResponse
}

extension KretaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInstitution: "Érvénytelen intézménykód."
        case .loginRejected: "A bejelentkezés nem sikerült. Próbáld újra."
        case .authentication, .sessionExpired: "A munkamenet lejárt. Jelentkezz be újra."
        case .notLoggedIn: "Nincs bejelentkezett fiók."
        case .http(let status): "A KRÉTA szerver hibát jelzett (\(status))."
        case .badResponse: "A KRÉTA szerver válasza nem értelmezhető."
        }
    }
}
