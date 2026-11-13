package hu.kretaora.core.auth

import hu.kretaora.core.KretaConfig
import hu.kretaora.core.model.InstantSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Duration
import java.time.Instant

@Serializable
data class Account(
    /** Stable local identifier derived from institution and user. */
    val id: String,
    val institutionCode: String,
    val userName: String,
    val displayName: String,
)

@Serializable
data class TokenSet(
    val accessToken: String,
    val refreshToken: String,
    @Serializable(with = InstantSerializer::class) val expiresAt: Instant,
) {
    fun isFresh(now: Instant): Boolean = Duration.between(now, expiresAt) > KretaConfig.TOKEN_LEEWAY

    /** Never prints the tokens. */
    override fun toString(): String = "TokenSet(expiresAt=$expiresAt)"
}

@Serializable
data class Session(val account: Account, val tokens: TokenSet) {
    /** The session as JSON, for an encrypted store to persist. */
    fun toJson(): String = json.encodeToString(serializer(), this)

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** Null when the text is not a stored session. */
        fun fromJson(text: String): Session? =
            try {
                json.decodeFromString(serializer(), text)
            } catch (_: SerializationException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
    }
}

/** Where the signed-in session lives. Production uses an encrypted file. */
interface SessionStore {
    fun load(): Session?
    fun save(session: Session)
    fun clear()
}

/** Keeps the session in memory only. Used by tests and previews. */
class InMemorySessionStore(session: Session? = null) : SessionStore {
    private val lock = Any()
    private var session: Session? = session

    override fun load(): Session? = synchronized(lock) { session }

    override fun save(session: Session) {
        synchronized(lock) { this.session = session }
    }

    override fun clear() {
        synchronized(lock) { session = null }
    }
}
