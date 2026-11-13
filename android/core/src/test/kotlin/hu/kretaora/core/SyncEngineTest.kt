package hu.kretaora.core

import hu.kretaora.core.auth.Account
import hu.kretaora.core.auth.InMemorySessionStore
import hu.kretaora.core.auth.Session
import hu.kretaora.core.auth.SessionStore
import hu.kretaora.core.auth.TokenSet
import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.net.HttpRequest
import hu.kretaora.core.net.HttpResponse
import hu.kretaora.core.net.HttpTransport
import hu.kretaora.core.net.KretaApi
import hu.kretaora.core.sync.SyncEngine
import hu.kretaora.core.timetable.SnapshotStore
import hu.kretaora.core.timetable.TimetableChange
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File
import java.io.IOException
import java.time.Instant

class SyncEngineTest {
    /** Monday 7:00 of the fixture week. */
    private val now = Fixture.date(16, 7)
    private val directory = temporaryDirectory()
    private val snapshots = SnapshotStore(directory)
    private val freshSession = Fixture.session(expiresAt = now.plusSeconds(1800))

    private fun engine(transport: FakeTransport, sessions: SessionStore, at: Instant = now) =
        SyncEngine(KretaApi(transport), sessions, snapshots, clock = { at })

    @Test
    fun `without a session there is nothing to sync`() = runTest {
        val transport = FakeTransport { _, _ -> json("[]") }
        expectThrows<KretaException.NotLoggedIn> { engine(transport, InMemorySessionStore()).sync() }
        assertTrue(transport.requests.isEmpty())
    }

    @Test
    fun `fetches the sync window with the mobile headers and stores the snapshot`() = runTest {
        val transport = FakeTransport { _, _ -> json("[${Fixture.lessonJson()}]") }

        val result = engine(transport, InMemorySessionStore(freshSession)).sync()

        val request = transport.requests.single()
        assertEquals(
            "https://school-a.e-kreta.hu/ellenorzo/v3/sajat/OrarendElemek?datumTol=2026-11-09&datumIg=2026-12-06",
            request.url,
        )
        assertEquals("GET", request.method)
        assertEquals("Bearer access-0", request.headers["Authorization"])
        assertEquals(KretaConfig.API_KEY, request.headers["apiKey"])
        assertEquals(KretaConfig.USER_AGENT, request.headers["User-Agent"])
        assertEquals("application/json", request.headers["Accept"])

        assertTrue(result.changes.isEmpty())
        assertEquals(1, result.snapshot.lessons.size)
        assertEquals("account", result.snapshot.accountId)
        assertEquals(Fixture.date(9), result.snapshot.rangeStart)
        assertEquals("2026-12-07", KretaDate.dayString(result.snapshot.rangeEnd))
        assertEquals(now, result.snapshot.syncedAt)
        assertEquals(result.snapshot, snapshots.load())
    }

    @Test
    fun `the second sync reports what changed`() = runTest {
        val transport = FakeTransport { _, position ->
            json("[${Fixture.lessonJson(state = if (position == 0) "Naplozott" else "Elmaradt")}]")
        }
        val engine = engine(transport, InMemorySessionStore(freshSession))

        assertTrue(engine.sync().changes.isEmpty())
        assertEquals(listOf(TimetableChange.Kind.CANCELLED), engine.sync().changes.map { it.kind })
        assertTrue(engine.sync().changes.isEmpty())
    }

    @Test
    fun `an expiring token is refreshed and saved before the timetable is fetched`() = runTest {
        val sessions = InMemorySessionStore(Fixture.session(expiresAt = now.plusSeconds(30)))
        val transport = FakeTransport { request, _ ->
            if (request.isTokenRequest) json(Fixture.tokenJson("access-1", "refresh-1")) else json("[]")
        }

        engine(transport, sessions).sync()

        assertEquals(listOf(true, false), transport.requests.map { it.isTokenRequest })
        assertEquals("refresh-0", transport.requests[0].form["refresh_token"])
        assertEquals("Bearer access-1", transport.requests[1].headers["Authorization"])
        assertEquals("refresh-1", sessions.load()?.tokens?.refreshToken)
        assertEquals(now.plusSeconds(1800), sessions.load()?.tokens?.expiresAt)
    }

    @Test
    fun `a rejected access token is rotated once and the fetch retried once`() = runTest {
        val sessions = InMemorySessionStore(freshSession)
        val transport = FakeTransport { request, _ ->
            when {
                request.isTokenRequest -> json(Fixture.tokenJson(access = "access-1"))
                request.headers["Authorization"] == "Bearer access-1" -> json("[]")
                else -> json("{}", status = 401)
            }
        }

        engine(transport, sessions).sync()

        assertEquals(listOf(false, true, false), transport.requests.map { it.isTokenRequest })
        assertEquals("access-1", sessions.load()?.tokens?.accessToken)
    }

    @Test
    fun `a token that keeps being rejected does not loop`() = runTest {
        val transport = FakeTransport { request, _ ->
            if (request.isTokenRequest) json(Fixture.tokenJson()) else json("{}", status = 401)
        }
        expectThrows<KretaException.Authentication> {
            engine(transport, InMemorySessionStore(freshSession)).sync()
        }
        assertEquals(3, transport.requests.size)
    }

    @Test
    fun `a dead refresh token ends the session but keeps the cached timetable`() = runTest {
        val cached = Fixture.snapshot(listOf(Fixture.lesson("a", day = 17, index = 1)))
        snapshots.save(cached)
        val sessions = InMemorySessionStore(Fixture.session(expiresAt = now))
        val transport = FakeTransport { _, _ -> json("""{"error":"invalid_grant"}""", status = 400) }

        expectThrows<KretaException.SessionExpired> { engine(transport, sessions).sync() }

        assertEquals(cached, snapshots.load())
        assertEquals("refresh-0", sessions.load()?.tokens?.refreshToken)
    }

    @Test
    fun `a server error leaves the previous snapshot in place`() = runTest {
        val cached = Fixture.snapshot(listOf(Fixture.lesson("a", day = 17, index = 1)))
        snapshots.save(cached)
        val transport = FakeTransport { _, _ -> json("oops", status = 500) }

        val error = expectThrows<KretaException.Http> {
            engine(transport, InMemorySessionStore(freshSession)).sync()
        }

        assertEquals(500, error.status)
        assertEquals(cached, snapshots.load())
    }

    @Test
    fun `a rotated refresh token survives a failed save`() = runTest {
        val sessions = FailingSaveStore(Fixture.session(expiresAt = now))
        val transport = FakeTransport { request, _ ->
            if (request.isTokenRequest) json(Fixture.tokenJson("access-1", "refresh-1")) else json("[]")
        }
        val engine = engine(transport, sessions)

        expectThrows<IOException> { engine.sync() }
        sessions.allowSaving()
        engine.sync()

        // The second sync used the rotated token instead of the dead stored one.
        assertEquals(listOf(true, false), transport.requests.map { it.isTokenRequest })
        assertEquals("Bearer access-1", transport.requests[1].headers["Authorization"])
    }

    @Test
    fun `concurrent syncs refresh the token only once`() = runTest {
        val sessions = InMemorySessionStore(Fixture.session(expiresAt = now))
        val transport = FakeTransport { request, _ ->
            if (request.isTokenRequest) json(Fixture.tokenJson("access-1", "refresh-1", expiresIn = "1800")) else json("[]")
        }
        val engine = engine(transport, sessions)

        List(4) { async { engine.sync() } }.awaitAll()

        assertEquals(1, transport.requests.count { it.isTokenRequest })
        assertEquals(4, transport.requests.count { !it.isTokenRequest })
    }

    @Test
    fun `an empty answer while lessons are still ahead keeps the known timetable`() = runTest {
        val cached = Fixture.snapshot(listOf(Fixture.lesson("a", day = 17, index = 1)))
        snapshots.save(cached)
        val transport = FakeTransport { _, _ -> json("[]") }

        val result = engine(transport, InMemorySessionStore(freshSession)).sync()

        assertEquals(cached, result.snapshot)
        assertTrue(result.changes.isEmpty())
        assertEquals(cached, snapshots.load())
    }

    @Test
    fun `an empty answer is accepted once the known lessons have passed`() = runTest {
        snapshots.save(Fixture.snapshot(listOf(Fixture.lesson("a", day = 17, index = 1))))
        val transport = FakeTransport { _, _ -> json("[]") }
        val later = Fixture.date(18, 7)

        val sessions = InMemorySessionStore(Fixture.session(expiresAt = later.plusSeconds(1800)))

        val result = engine(transport, sessions, at = later).sync()

        assertTrue(result.snapshot.lessons.isEmpty())
        assertTrue(result.changes.isEmpty())
        assertEquals(later, snapshots.load()?.syncedAt)
    }

    @Test
    fun `the follow-up of a sync finishes before a queued sign-out starts`() = runTest {
        val sessions = InMemorySessionStore(freshSession)
        val transport = FakeTransport { _, _ -> json("[${Fixture.lessonJson()}]") }
        val engine = engine(transport, sessions)
        val events = mutableListOf<String>()

        val syncing = async {
            engine.sync { result ->
                yield()
                events += "published ${result.snapshot.lessons.size}, signed in: ${sessions.load() != null}"
            }
        }
        val leaving = async { engine.signOut { events += "signed out" } }
        listOf(syncing, leaving).awaitAll()

        assertEquals(listOf("published 1, signed in: true", "signed out"), events)
    }

    @Test
    fun `a sign-out issued while a sync waits for the network leaves nothing behind`() = runTest {
        val sessions = InMemorySessionStore(Fixture.session(expiresAt = now))
        val network = CompletableDeferred<Unit>()
        val transport = object : HttpTransport {
            override suspend fun send(request: HttpRequest): HttpResponse {
                network.await()
                return if (request.isTokenRequest) json(Fixture.tokenJson()) else json("[${Fixture.lessonJson()}]")
            }
        }
        val engine = SyncEngine(KretaApi(transport), sessions, snapshots, clock = { now })

        val syncing = async { engine.sync() }
        yield()
        val leaving = async { engine.signOut() }
        yield()
        network.complete(Unit)
        listOf(syncing, leaving).awaitAll()

        assertNull(sessions.load())
        assertNull(snapshots.load())
    }

    @Test
    fun `sign-out clears the timetable and tells the others even when the session store fails`() = runTest {
        snapshots.save(Fixture.snapshot(listOf(Fixture.lesson("a", day = 17, index = 1))))
        val sessions = object : SessionStore {
            override fun load(): Session? = freshSession
            override fun save(session: Session) = Unit
            override fun clear(): Unit = throw IOException("keystore unavailable")
        }
        var told = false

        expectThrows<IOException> {
            engine(FakeTransport { _, _ -> json("[]") }, sessions).signOut { told = true }
        }

        assertTrue(told)
        assertNull(snapshots.load())
    }

    @Test
    fun `signing out clears the session and the timetable`() = runTest {
        val sessions = InMemorySessionStore(freshSession)
        val transport = FakeTransport { _, _ -> json("[${Fixture.lessonJson()}]") }
        val engine = engine(transport, sessions)
        engine.sync()

        engine.signOut()

        assertNull(sessions.load())
        assertNull(snapshots.load())
        engine.signOut()
    }

    @Test
    fun `an unreadable snapshot file behaves like a first launch`() {
        File(directory, "timetable.json").writeText("not json")
        assertNull(snapshots.load())
        File(directory, "timetable.json").writeText("""{"accountId": 1}""")
        assertNull(snapshots.load())
    }

    @Test
    fun `an institution code from storage is validated before any request`() = runTest {
        val tampered = Session(
            Account(id = "x", institutionCode = "evil.example/", userName = "u", displayName = "u"),
            TokenSet("a", "r", now.plusSeconds(1800)),
        )
        val transport = FakeTransport { _, _ -> json("[]") }
        expectThrows<KretaException.InvalidInstitution> {
            engine(transport, InMemorySessionStore(tampered)).sync()
        }
        assertTrue(transport.requests.isEmpty())
    }

    @Test
    fun `token freshness uses a safety margin`() {
        val tokens = TokenSet("a", "r", now.plusSeconds(61))
        assertTrue(tokens.isFresh(now))
        assertFalse(tokens.isFresh(now.plusSeconds(1)))
    }

    @Test
    fun `a session survives being turned into JSON and back`() {
        assertEquals(freshSession, Session.fromJson(freshSession.toJson()))
        assertNull(Session.fromJson("not json"))
        assertNull(Session.fromJson("""{"account": {}}"""))
    }

    @Test
    fun `errors have Hungarian messages`() {
        val errors = listOf(
            KretaException.InvalidInstitution(), KretaException.LoginRejected(), KretaException.Authentication(),
            KretaException.SessionExpired(), KretaException.NotLoggedIn(), KretaException.Http(503),
            KretaException.BadResponse(),
        )
        assertTrue(errors.all { !it.message.isNullOrEmpty() })
        assertTrue(KretaException.Http(503).message.orEmpty().contains("503"))
    }
}

/** A session store whose writes fail until told otherwise. */
private class FailingSaveStore(private var session: Session?) : SessionStore {
    private var canSave = false

    fun allowSaving() {
        canSave = true
    }

    override fun load(): Session? = session

    override fun save(session: Session) {
        if (!canSave) throw IOException("disk full")
        this.session = session
    }

    override fun clear() {
        session = null
    }
}
