package hu.kretaora.core

/** Everything the core can fail with. Messages are Hungarian and safe to show. */
sealed class KretaException(message: String) : Exception(message) {
    /** The institution code is not a single valid DNS label. */
    class InvalidInstitution : KretaException("Érvénytelen intézménykód.")

    /** The login callback or the identity token did not match the attempt. */
    class LoginRejected : KretaException("A bejelentkezés nem sikerült. Próbáld újra.")

    /** The server rejected the access token. */
    class Authentication : KretaException("A munkamenet lejárt. Jelentkezz be újra.")

    /** The refresh token is no longer accepted; the user has to sign in again. */
    class SessionExpired : KretaException("A munkamenet lejárt. Jelentkezz be újra.")

    /** There is no stored session. */
    class NotLoggedIn : KretaException("Nincs bejelentkezett fiók.")

    /** The server answered with an unexpected status code. */
    class Http(val status: Int) : KretaException("A KRÉTA szerver hibát jelzett ($status).")

    /** The response body could not be understood. */
    class BadResponse : KretaException("A KRÉTA szerver válasza nem értelmezhető.")
}
