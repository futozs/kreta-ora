import Foundation

/// Fixed parameters of the KRÉTA student mobile protocol.
///
/// These are the public values the official student app uses. The API key is
/// not a secret: every client sends the same one.
public enum KretaConfig {
    public static let clientID = "kreta-ellenorzo-student-mobile-android"
    public static let redirectURI = "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect"
    public static let scopes = [
        "openid", "email", "offline_access",
        "kreta-ellenorzo-webapi.public",
        "kreta-eugyintezes-webapi.public",
        "kreta-fileservice-webapi.public",
        "kreta-mobile-global-webapi.public",
        "kreta-dkt-webapi.public",
        "kreta-ier-webapi.public",
    ].joined(separator: " ")
    public static let userAgent = "hu.ekreta.student/5.15.0/KretaOra/13/33"
    public static let apiKey = "21ff6c25-d1da-4a68-a811-c881a6057463"
    public static let identityProvider = URL(string: "https://idp.e-kreta.hu")!
    public static let timeZone = TimeZone(identifier: "Europe/Budapest")!

    /// A started login must be finished within this window.
    public static let loginAttemptLifetime: TimeInterval = 15 * 60
    /// Access tokens are refreshed this long before they actually expire.
    public static let tokenLeeway: TimeInterval = 60
    /// Upper bound for a JSON response body.
    public static let maxResponseBytes = 16 * 1024 * 1024
}
