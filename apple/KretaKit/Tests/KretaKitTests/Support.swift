import Foundation
@testable import KretaKit

/// Scripted network. Each test decides what every request gets back.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let handler: @Sendable (URLRequest, Int) throws -> HTTPResponse

    /// `handler` receives the request and how many requests came before it.
    init(_ handler: @escaping @Sendable (URLRequest, Int) throws -> HTTPResponse) {
        self.handler = handler
    }

    var requests: [URLRequest] { lock.withLock { recorded } }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let position = lock.withLock {
            recorded.append(request)
            return recorded.count - 1
        }
        return try handler(request, position)
    }
}

extension HTTPResponse {
    static func json(_ text: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, body: Data(text.utf8))
    }
}

extension URLRequest {
    var isTokenRequest: Bool { url?.path.hasSuffix("/connect/token") == true }

    var form: [String: String] {
        guard let body = httpBody, let text = String(data: body, encoding: .utf8) else { return [:] }
        var components = URLComponents()
        components.percentEncodedQuery = text
        return Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        ) { first, _ in first }
    }
}

enum Fixture {
    /// Monday 2026-11-16, a school week. Times below are school time.
    static func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        KretaDate.calendar.date(
            from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
        )!
    }

    static func lesson(
        _ id: String,
        day: Int,
        index: Int,
        name: String = "matematika",
        teacher: String? = "Kiss Béla",
        substitute: String? = nil,
        room: String? = "12",
        cancelled: Bool = false,
        kind: Lesson.Kind = .lesson,
        topic: String? = nil
    ) -> Lesson {
        // 1st lesson 8:00, then one every 55 minutes, 45 minutes long.
        let start = date(day, 8, 0).addingTimeInterval(TimeInterval((index - 1) * 55 * 60))
        return Lesson(
            id: id,
            start: start,
            end: start.addingTimeInterval(45 * 60),
            name: name,
            index: index,
            teacher: teacher,
            substituteTeacher: substitute,
            room: room,
            topic: topic,
            kind: kind,
            isCancelled: cancelled
        )
    }

    /// A snapshot covering the two weeks starting Monday the 16th.
    static func snapshot(
        _ lessons: [Lesson],
        account: String = "account",
        from: Int = 16,
        to: Int = 30
    ) -> TimetableSnapshot {
        TimetableSnapshot(
            accountID: account,
            lessons: lessons,
            rangeStart: date(from),
            rangeEnd: date(to),
            syncedAt: date(from)
        )
    }

    static func jwt(_ claims: [String: Any]) -> String {
        let header = Encoding.base64URL(Data(#"{"alg":"RS256"}"#.utf8))
        let payload = Encoding.base64URL(try! JSONSerialization.data(withJSONObject: claims))
        return "\(header).\(payload).signature"
    }

    static func tokenJSON(
        access: String = "access-1",
        refresh: String? = "refresh-1",
        idToken: String? = nil,
        expiresIn: String = "1800"
    ) -> String {
        let fields: [String?] = [
            #""access_token":"\#(access)""#,
            refresh.map { #""refresh_token":"\#($0)""# },
            idToken.map { #""id_token":"\#($0)""# },
            #""expires_in":\#(expiresIn)"#,
        ]
        return "{" + fields.compactMap { $0 }.joined(separator: ",") + "}"
    }

    static let account = Account(
        id: "account", institutionCode: "school-a", userName: "72345678901", displayName: "Teszt Elek"
    )

    static func session(expiresAt: Date, access: String = "access-0", refresh: String = "refresh-0") -> Session {
        Session(
            account: account,
            tokens: TokenSet(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
        )
    }

    /// Shaped like a real `OrarendElemek` row.
    static func lessonJSON(
        uid: String = "101,TanitasiOra,2026-11-16T07:00:00Z",
        start: String = "2026-11-16T07:00:00Z",
        end: String = "2026-11-16T07:45:00Z",
        state: String = "Naplozott",
        type: String = "TanitasiOra",
        substitute: String = "null"
    ) -> String {
        """
        {
          "Uid": "\(uid)",
          "Datum": "2026-11-15T23:00:00Z",
          "KezdetIdopont": "\(start)",
          "VegIdopont": "\(end)",
          "Nev": "matematika",
          "Oraszam": 1,
          "OraEvesSorszama": 42,
          "OsztalyCsoport": {"Uid": "837", "Nev": "10.A"},
          "TanarNeve": "Kiss Béla",
          "Tantargy": {"Uid": "368", "Nev": "matematika", "Kategoria": {"Uid": "1", "Nev": "matematika"}},
          "Tema": " ",
          "TeremNeve": "12",
          "Tipus": {"Uid": "2,TanitasiOra", "Nev": "\(type)", "Leiras": "Tanítási óra"},
          "Allapot": {"Uid": "1,\(state)", "Nev": "\(state)", "Leiras": "\(state)"},
          "HelyettesTanarNeve": \(substitute),
          "HaziFeladatUid": null,
          "BejelentettSzamonkeresUid": "5512",
          "IsDigitalisOra": false
        }
        """
    }
}

func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("kretakit-\(UUID().uuidString)")
}
