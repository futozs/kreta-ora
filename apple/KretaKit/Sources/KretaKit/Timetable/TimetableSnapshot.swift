import Foundation

/// The last timetable the app saw, plus the window it covers. Widgets and the
/// watch render from this; the diff compares against it.
public struct TimetableSnapshot: Codable, Equatable, Sendable {
    public let accountID: String
    public let lessons: [Lesson]
    /// Start of the first covered school day.
    public let rangeStart: Date
    /// Start of the day after the last covered school day.
    public let rangeEnd: Date
    public let syncedAt: Date

    public init(accountID: String, lessons: [Lesson], rangeStart: Date, rangeEnd: Date, syncedAt: Date) {
        self.accountID = accountID
        self.lessons = lessons
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.syncedAt = syncedAt
    }

    public var schedule: Schedule { Schedule(lessons: lessons) }

    public func covers(_ date: Date) -> Bool {
        rangeStart <= date && date < rangeEnd
    }
}

/// Persists the snapshot as one JSON file, written atomically. Point it at the
/// App Group container so the app, the widgets and the watch share it.
public struct SnapshotStore: Sendable {
    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("timetable.json")
    }

    /// The store in a shared App Group container, or nil when the group is
    /// not available to this process.
    public static func appGroup(_ identifier: String) -> SnapshotStore? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)
            .map(SnapshotStore.init(directory:))
    }

    /// The stored snapshot, or nil when there is none or it is unreadable.
    /// An unreadable file behaves like a first launch: the next sync rebuilds
    /// it silently.
    public func load() -> TimetableSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
    }

    public func save(_ snapshot: TimetableSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
