import Foundation

/// One timetable entry, already normalized from the KRÉTA payload.
public struct Lesson: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// A regular lesson.
        case lesson
        /// A free slot placeholder (`UresOra`).
        case empty
        /// A school-year event such as a holiday (`TanevRendjeEsemeny`).
        case event
    }

    public let id: String
    public let start: Date
    public let end: Date
    public let name: String
    /// Position in the day (1st lesson, 2nd lesson, …) when the school numbers it.
    public let index: Int?
    public let teacher: String?
    public let substituteTeacher: String?
    public let room: String?
    public let topic: String?
    public let group: String?
    public let kind: Kind
    public let isCancelled: Bool
    public let hasTest: Bool
    public let hasHomework: Bool

    public init(
        id: String,
        start: Date,
        end: Date,
        name: String,
        index: Int? = nil,
        teacher: String? = nil,
        substituteTeacher: String? = nil,
        room: String? = nil,
        topic: String? = nil,
        group: String? = nil,
        kind: Kind = .lesson,
        isCancelled: Bool = false,
        hasTest: Bool = false,
        hasHomework: Bool = false
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.name = name
        self.index = index
        self.teacher = teacher
        self.substituteTeacher = substituteTeacher
        self.room = room
        self.topic = topic
        self.group = group
        self.kind = kind
        self.isCancelled = isCancelled
        self.hasTest = hasTest
        self.hasHomework = hasHomework
    }

    /// A lesson that actually takes place.
    public var isActive: Bool { kind == .lesson && !isCancelled }

    public var isSubstituted: Bool { substituteTeacher != nil }

    /// The teacher who will actually be in the room.
    public var effectiveTeacher: String? { substituteTeacher ?? teacher }

    /// Subject name with a capital first letter, as KRÉTA stores them lowercase.
    public var displayName: String {
        name.capitalizedFirst
    }

    public func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

// MARK: - KRÉTA payload

extension Lesson {
    /// Decodes the `OrarendElemek` array. Rows that cannot be understood are
    /// skipped, so one odd entry cannot hide the whole timetable.
    static func decodeList(_ data: Data) throws -> [Lesson] {
        guard let rows = try? JSONDecoder().decode([LossyRow].self, from: data) else {
            throw KretaError.badResponse
        }
        return rows.compactMap(\.lesson).sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }
}

private struct LossyRow: Decodable {
    let lesson: Lesson?

    init(from decoder: Decoder) throws {
        lesson = (try? decoder.container(keyedBy: AnyKey.self)).flatMap(Lesson.init(row:))
    }
}

private struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ name: String) { stringValue = name }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private typealias Row = KeyedDecodingContainer<AnyKey>

private extension KeyedDecodingContainer where K == AnyKey {
    /// A non-empty, trimmed string; numbers are accepted too.
    func text(_ name: String) -> String? {
        let key = AnyKey(name)
        let raw: String?
        if let value = try? decode(String.self, forKey: key) {
            raw = value
        } else if let value = try? decode(Int.self, forKey: key) {
            raw = String(value)
        } else {
            raw = nil
        }
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func int(_ name: String) -> Int? {
        let key = AnyKey(name)
        if let value = try? decode(Int.self, forKey: key) { return value }
        return (try? decode(String.self, forKey: key)).flatMap(Int.init)
    }

    /// The `Nev` and `Leiras` of a nested reference object, or the plain
    /// string when the server sends one.
    func reference(_ name: String) -> (name: String?, description: String?) {
        if let nested = try? nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey(name)) {
            return (nested.text("Nev"), nested.text("Leiras"))
        }
        return (text(name), nil)
    }
}

private extension Lesson {
    init?(row: Row) {
        guard
            let id = row.text("Uid"),
            let start = row.text("KezdetIdopont").flatMap(KretaDate.parse),
            let end = row.text("VegIdopont").flatMap(KretaDate.parse),
            end > start
        else { return nil }

        let type = row.reference("Tipus").name
        let state = row.reference("Allapot")
        let stateText = [state.name, state.description].compactMap { $0 }.joined(separator: " ")

        self.init(
            id: id,
            start: start,
            end: end,
            name: row.text("Nev") ?? row.reference("Tantargy").name ?? "Óra",
            index: row.int("Oraszam"),
            teacher: row.text("TanarNeve"),
            substituteTeacher: row.text("HelyettesTanarNeve"),
            room: row.text("TeremNeve"),
            topic: row.text("Tema"),
            group: row.reference("OsztalyCsoport").name,
            kind: Self.kind(type),
            isCancelled: stateText.range(of: "elmarad", options: .caseInsensitive) != nil,
            hasTest: row.text("BejelentettSzamonkeresUid") != nil,
            hasHomework: row.text("HaziFeladatUid") != nil
        )
    }

    static func kind(_ type: String?) -> Kind {
        switch type {
        case "UresOra": .empty
        case "TanevRendjeEsemeny": .event
        default: .lesson
        }
    }
}
