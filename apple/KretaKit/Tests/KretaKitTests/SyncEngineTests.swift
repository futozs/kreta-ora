import Foundation
import Testing
@testable import KretaKit

@Suite("Sync engine and storage")
struct SyncEngineTests {
    /// Monday 7:00 of the fixture week.
    private let now = Fixture.date(16, 7)
    private let directory = temporaryDirectory()

    private var snapshots: SnapshotStore { SnapshotStore(directory: directory) }

    private func engine(
        _ transport: FakeTransport,
        sessions: any SessionStore,
        at time: Date? = nil
    ) -> SyncEngine {
        let moment = time ?? now
        return SyncEngine(
            api: KretaAPI(transport: transport),
            sessions: sessions,
            snapshots: snapshots,
            clock: { moment }
        )
    }

    private func timetable(_ rows: String...) -> HTTPResponse {
        .json("[\(rows.joined(separator: ","))]")
    }

    private var freshSession: Session { Fixture.session(expiresAt: now.addingTimeInterval(1800)) }

    @Test("without a session there is nothing to sync")
    func notLoggedIn() async {
        let transport = FakeTransport { _, _ in .json("[]") }
        await #expect(throws: KretaError.notLoggedIn) {
            try await engine(transport, sessions: InMemorySessionStore()).sync()
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("fetches the sync window with the mobile headers and stores the snapshot")
    func fetchesAndStores() async throws {
        let transport = FakeTransport { _, _ in .json("[\(Fixture.lessonJSON())]") }

        let result = try await engine(transport, sessions: InMemorySessionStore(freshSession)).sync()

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.url?.absoluteString
            == "https://school-a.e-kreta.hu/ellenorzo/v3/sajat/OrarendElemek?datumTol=2026-11-09&datumIg=2026-12-06")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-0")
        #expect(request.value(forHTTPHeaderField: "apiKey") == KretaConfig.apiKey)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == KretaConfig.userAgent)

        #expect(result.changes.isEmpty)
        #expect(result.snapshot.lessons.count == 1)
        #expect(result.snapshot.accountID == "account")
        #expect(result.snapshot.rangeStart == Fixture.date(9))
        #expect(KretaDate.dayString(result.snapshot.rangeEnd) == "2026-12-07")
        #expect(result.snapshot.syncedAt == now)
        #expect(snapshots.load() == result.snapshot)
    }

    @Test("the second sync reports what changed")
    func reportsChanges() async throws {
        let sessions = InMemorySessionStore(freshSession)
        let transport = FakeTransport { _, position in
            .json("[\(Fixture.lessonJSON(state: position == 0 ? "Naplozott" : "Elmaradt"))]")
        }
        let engine = engine(transport, sessions: sessions)

        #expect(try await engine.sync().changes.isEmpty)
        let changes = try await engine.sync().changes
        #expect(changes.map(\.kind) == [.cancelled])
        #expect(try await engine.sync().changes.isEmpty)
    }

    @Test("an expiring token is refreshed and saved before the timetable is fetched")
    func refreshesExpiringToken() async throws {
        let sessions = InMemorySessionStore(Fixture.session(expiresAt: now.addingTimeInterval(30)))
        let transport = FakeTransport { request, _ in
            request.isTokenRequest
                ? .json(Fixture.tokenJSON(access: "access-1", refresh: "refresh-1"))
                : .json("[]")
        }

        _ = try await engine(transport, sessions: sessions).sync()

        #expect(transport.requests.map(\.isTokenRequest) == [true, false])
        #expect(transport.requests[0].form["refresh_token"] == "refresh-0")
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
        #expect(sessions.load()?.tokens.refreshToken == "refresh-1")
        #expect(sessions.load()?.tokens.expiresAt == now.addingTimeInterval(1800))
    }

    @Test("a rejected access token is rotated once and the fetch retried once")
    func retriesAfterUnauthorized() async throws {
        let sessions = InMemorySessionStore(freshSession)
        let transport = FakeTransport { request, _ in
            if request.isTokenRequest { return .json(Fixture.tokenJSON(access: "access-1")) }
            let authorized = request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1"
            return authorized ? .json("[]") : .json("{}", status: 401)
        }

        _ = try await engine(transport, sessions: sessions).sync()

        #expect(transport.requests.map(\.isTokenRequest) == [false, true, false])
        #expect(sessions.load()?.tokens.accessToken == "access-1")
    }

    @Test("a token that keeps being rejected does not loop")
    func noRetryLoop() async {
        let transport = FakeTransport { request, _ in
            request.isTokenRequest ? .json(Fixture.tokenJSON()) : .json("{}", status: 401)
        }
        await #expect(throws: KretaError.authentication) {
            try await engine(transport, sessions: InMemorySessionStore(freshSession)).sync()
        }
        #expect(transport.requests.count == 3)
    }

    @Test("a dead refresh token ends the session but keeps the cached timetable")
    func sessionExpired() async throws {
        let cached = Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)])
        try snapshots.save(cached)
        let sessions = InMemorySessionStore(Fixture.session(expiresAt: now))
        let transport = FakeTransport { _, _ in .json(#"{"error":"invalid_grant"}"#, status: 400) }

        await #expect(throws: KretaError.sessionExpired) {
            try await engine(transport, sessions: sessions).sync()
        }
        #expect(snapshots.load() == cached)
        #expect(sessions.load()?.tokens.refreshToken == "refresh-0")
    }

    @Test("a server error leaves the previous snapshot in place")
    func serverErrorKeepsSnapshot() async throws {
        let cached = Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)])
        try snapshots.save(cached)
        let transport = FakeTransport { _, _ in .json("oops", status: 500) }

        await #expect(throws: KretaError.http(500)) {
            try await engine(transport, sessions: InMemorySessionStore(freshSession)).sync()
        }
        #expect(snapshots.load() == cached)
    }

    @Test("a rotated refresh token survives a failed save")
    func keepsRotatedTokenWhenSaveFails() async throws {
        let sessions = FailingSaveStore(Fixture.session(expiresAt: now))
        let transport = FakeTransport { request, _ in
            request.isTokenRequest ? .json(Fixture.tokenJSON(access: "access-1", refresh: "refresh-1")) : .json("[]")
        }
        let engine = engine(transport, sessions: sessions)

        await #expect(throws: FailingSaveStore.Failure.self) { try await engine.sync() }
        sessions.allowSaving()
        _ = try await engine.sync()

        // The second sync used the rotated token instead of the dead stored one.
        #expect(transport.requests.map(\.isTokenRequest) == [true, false])
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
    }

    @Test("two triggers at once spend the refresh token only once")
    func concurrentSyncsShareOneRefresh() async throws {
        let sessions = InMemorySessionStore(Fixture.session(expiresAt: now))
        let arrived = Gate()
        let release = Gate()
        let transport = FakeTransport { request, _ in
            guard request.isTokenRequest else { return .json("[]") }
            await arrived.open()
            await release.wait()
            return .json(Fixture.tokenJSON(access: "access-1", refresh: "refresh-1"))
        }
        let engine = engine(transport, sessions: sessions)

        let first = Task { try await engine.sync() }
        await arrived.wait()
        let second = Task { try await engine.sync() }
        // Give an unserialized second sync every chance to start its own refresh.
        try await Task.sleep(for: .milliseconds(80))
        await release.open()
        _ = try await first.value
        _ = try await second.value

        let refreshes = transport.requests.filter(\.isTokenRequest)
        #expect(refreshes.count == 1)
        #expect(refreshes.first?.form["refresh_token"] == "refresh-0")
        #expect(sessions.load()?.tokens.refreshToken == "refresh-1")
    }

    @Test("a sync in flight cannot bring the session back after signing out")
    func signOutWaitsForRunningSync() async throws {
        let sessions = InMemorySessionStore(freshSession)
        let arrived = Gate()
        let release = Gate()
        let transport = FakeTransport { _, _ in
            await arrived.open()
            await release.wait()
            return .json("[\(Fixture.lessonJSON())]")
        }
        let engine = engine(transport, sessions: sessions)
        let order = EventLog()

        let sync = Task { try await engine.sync { _ in await order.add("published") } }
        await arrived.wait()
        let signOut = Task { try await engine.signOut { await order.add("cleared") } }
        try await Task.sleep(for: .milliseconds(80))
        await release.open()
        _ = try await sync.value
        try await signOut.value

        #expect(sessions.load() == nil)
        #expect(snapshots.load() == nil)
        #expect(await order.events == ["published", "cleared"])
    }

    @Test("an empty answer while lessons are still ahead is not believed")
    func emptyResponseKeepsKnownTimetable() async throws {
        let cached = Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)])
        try snapshots.save(cached)
        let transport = FakeTransport { _, _ in .json("[]") }

        let result = try await engine(transport, sessions: InMemorySessionStore(freshSession)).sync()

        #expect(result.changes.isEmpty)
        #expect(result.snapshot == cached)
        #expect(snapshots.load() == cached)
    }

    @Test("an answer with only events is treated the same way")
    func eventsOnlyResponseKeepsKnownTimetable() async throws {
        let cached = Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)])
        try snapshots.save(cached)
        let transport = FakeTransport { _, _ in .json("[\(Fixture.lessonJSON(type: "TanevRendjeEsemeny"))]") }

        let result = try await engine(transport, sessions: InMemorySessionStore(freshSession)).sync()

        #expect(result.snapshot == cached)
    }

    @Test("an empty answer is accepted once the known lessons have passed")
    func emptyResponseAcceptedLater() async throws {
        try snapshots.save(Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)]))
        let transport = FakeTransport { _, _ in .json("[]") }
        let afterTheLesson = Fixture.date(17, 12)
        let sessions = InMemorySessionStore(Fixture.session(expiresAt: afterTheLesson.addingTimeInterval(1800)))

        let result = try await engine(transport, sessions: sessions, at: afterTheLesson).sync()

        #expect(result.changes.isEmpty)
        #expect(result.snapshot.lessons.isEmpty)
        #expect(snapshots.load()?.syncedAt == afterTheLesson)
    }

    @Test("another account's timetable does not block an empty answer")
    func emptyResponseForNewAccount() async throws {
        try snapshots.save(Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)], account: "someone-else"))
        let transport = FakeTransport { _, _ in .json("[]") }

        let result = try await engine(transport, sessions: InMemorySessionStore(freshSession)).sync()

        #expect(result.snapshot.accountID == "account")
        #expect(result.snapshot.lessons.isEmpty)
    }

    @Test("sign-out still clears the timetable and tells the app when the keychain fails")
    func signOutCleansUpDespiteFailure() async throws {
        try snapshots.save(Fixture.snapshot([Fixture.lesson("a", day: 17, index: 1)]))
        let transport = FakeTransport { _, _ in .json("[]") }
        let engine = engine(transport, sessions: FailingClearStore())
        let order = EventLog()

        await #expect(throws: FailingClearStore.Failure.self) {
            try await engine.signOut { await order.add("cleared") }
        }

        #expect(snapshots.load() == nil)
        #expect(await order.events == ["cleared"])
    }

    @Test("signing out clears the session and the timetable")
    func signOut() async throws {
        let sessions = InMemorySessionStore(freshSession)
        let transport = FakeTransport { _, _ in .json("[\(Fixture.lessonJSON())]") }
        let engine = engine(transport, sessions: sessions)
        _ = try await engine.sync()

        try await engine.signOut()

        #expect(sessions.load() == nil)
        #expect(snapshots.load() == nil)
        try await engine.signOut()
    }

    @Test("an unreadable snapshot file behaves like a first launch")
    func corruptSnapshot() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("timetable.json"))
        #expect(snapshots.load() == nil)
    }

    @Test("an institution code from storage is validated before any request")
    func validatesStoredInstitution() async {
        let tampered = Session(
            account: Account(id: "x", institutionCode: "evil.example/", userName: "u", displayName: "u"),
            tokens: TokenSet(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(1800))
        )
        let transport = FakeTransport { _, _ in .json("[]") }
        await #expect(throws: KretaError.invalidInstitution) {
            try await engine(transport, sessions: InMemorySessionStore(tampered)).sync()
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("token freshness uses a safety margin")
    func tokenFreshness() {
        let tokens = TokenSet(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(61))
        #expect(tokens.isFresh(at: now))
        #expect(!tokens.isFresh(at: now.addingTimeInterval(1)))
    }

    @Test("errors have Hungarian messages")
    func errorMessages() {
        let errors: [KretaError] = [
            .invalidInstitution, .loginRejected, .authentication, .sessionExpired,
            .notLoggedIn, .http(503), .badResponse,
        ]
        #expect(errors.allSatisfy { $0.errorDescription?.isEmpty == false })
        #expect(KretaError.http(503).errorDescription?.contains("503") == true)
    }
}

/// Records the order in which callbacks ran.
private actor EventLog {
    private(set) var events: [String] = []

    func add(_ event: String) { events.append(event) }
}

/// A session store that cannot be cleared.
private struct FailingClearStore: SessionStore {
    struct Failure: Error {}

    func load() -> Session? { nil }
    func save(_ session: Session) {}
    func clear() throws { throw Failure() }
}

/// A session store whose writes fail until told otherwise.
private final class FailingSaveStore: SessionStore, @unchecked Sendable {
    struct Failure: Error {}

    private let lock = NSLock()
    private var session: Session?
    private var canSave = false

    init(_ session: Session) { self.session = session }

    func allowSaving() { lock.withLock { canSave = true } }

    func load() -> Session? { lock.withLock { session } }

    func save(_ session: Session) throws {
        try lock.withLock {
            guard canSave else { throw Failure() }
            self.session = session
        }
    }

    func clear() { lock.withLock { session = nil } }
}
