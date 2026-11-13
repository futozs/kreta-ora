package hu.kretaora.core.sync

import hu.kretaora.core.KretaException
import hu.kretaora.core.auth.AuthService
import hu.kretaora.core.auth.Session
import hu.kretaora.core.auth.SessionStore
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.net.KretaApi
import hu.kretaora.core.timetable.Schedule
import hu.kretaora.core.timetable.SnapshotStore
import hu.kretaora.core.timetable.TimetableChange
import hu.kretaora.core.timetable.TimetableDiff
import hu.kretaora.core.timetable.TimetableSnapshot
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.LocalDate

data class SyncResult(
    val snapshot: TimetableSnapshot,
    /** What changed since the previous sync. Empty on the first one. */
    val changes: List<TimetableChange>,
)

/**
 * Fetches the timetable, keeps the session alive, and reports what changed.
 *
 * Every trigger goes through [sync]: opening the app, pull to refresh, the
 * background worker, and later a push message.
 *
 * Operations run strictly one after another behind a mutex. Without it two
 * syncs could spend the same refresh token, and a sync in flight could write
 * a session back after the user signed out.
 */
class SyncEngine(
    private val api: KretaApi = KretaApi(),
    private val sessions: SessionStore,
    private val snapshots: SnapshotStore,
    private val clock: () -> Instant = Instant::now,
) {
    private val auth = AuthService(api)
    private val mutex = Mutex()

    /**
     * Survives a failed store write: a rotated refresh token must not be
     * lost, because the old one no longer works.
     */
    private var rotated: Session? = null

    /**
     * Syncs once. [afterwards] runs before the next queued operation starts,
     * so whatever it publishes cannot be overtaken by a later sign-out.
     */
    suspend fun sync(afterwards: suspend (SyncResult) -> Unit = {}): SyncResult = mutex.withLock {
        val result = performSync()
        afterwards(result)
        result
    }

    /**
     * Forgets the session and the cached timetable. [afterwards] runs even
     * when part of the clean-up failed, so other surfaces are always told.
     */
    suspend fun signOut(afterwards: suspend () -> Unit = {}) = mutex.withLock {
        val outcome = runCatching { performSignOut() }
        afterwards()
        outcome.getOrThrow()
    }

    private suspend fun performSync(): SyncResult {
        val now = clock()
        val stored = currentSession() ?: throw KretaException.NotLoggedIn()
        val session = if (stored.tokens.isFresh(now)) stored else renew(stored)

        val (from, to) = Schedule.syncRange(now)
        val lessons = try {
            fetch(session, from, to)
        } catch (_: KretaException.Authentication) {
            // The token was revoked early. Rotate once and retry once.
            fetch(renew(session), from, to)
        }

        val previous = snapshots.load()
        if (previous != null && isSuspiciouslyEmpty(lessons, previous, session, now)) {
            return SyncResult(previous, emptyList())
        }

        val snapshot = TimetableSnapshot(
            accountId = session.account.id,
            lessons = lessons,
            rangeStart = KretaDate.startOfDay(from),
            rangeEnd = KretaDate.startOfDay(to.plusDays(1)),
            syncedAt = now,
        )
        val changes = TimetableDiff.changes(previous, snapshot, now)
        snapshots.save(snapshot)
        return SyncResult(snapshot, changes)
    }

    /**
     * A response without a single lesson, while lessons we already know are
     * still ahead, is far more likely a server hiccup than a wiped timetable.
     * Believing it would announce every lesson as removed now and as new on
     * the next good sync. The known timetable is kept instead; once its
     * lessons have passed, an empty answer is accepted.
     */
    private fun isSuspiciouslyEmpty(
        lessons: List<Lesson>,
        previous: TimetableSnapshot,
        session: Session,
        now: Instant,
    ): Boolean =
        previous.accountId == session.account.id &&
            lessons.none { it.kind == Lesson.Kind.LESSON } &&
            previous.lessons.any { it.kind == Lesson.Kind.LESSON && it.end > now }

    private fun performSignOut() {
        rotated = null
        // Try both, so a failing session store cannot leave the timetable behind.
        val sessionOutcome = runCatching { sessions.clear() }
        val snapshotOutcome = runCatching { snapshots.clear() }
        sessionOutcome.getOrThrow()
        snapshotOutcome.getOrThrow()
    }

    private fun currentSession(): Session? = rotated ?: sessions.load()

    private suspend fun renew(session: Session): Session {
        val renewed = auth.refresh(session, clock())
        rotated = renewed
        sessions.save(renewed)
        rotated = null
        return renewed
    }

    private suspend fun fetch(session: Session, from: LocalDate, to: LocalDate): List<Lesson> =
        api.timetable(
            institution = session.account.institutionCode,
            accessToken = session.tokens.accessToken,
            from = from,
            to = to,
        )
}
