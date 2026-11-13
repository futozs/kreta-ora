import Foundation

/// One thing that changed about an upcoming lesson.
public struct TimetableChange: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case cancelled
        /// A cancelled lesson will be held after all.
        case restored
        /// The teacher or the substitute changed.
        case teacher
        case time
        case room
        case added
        case removed
    }

    public let kind: Kind
    /// The lesson as it is now, or the removed lesson.
    public let lesson: Lesson
    /// The lesson as it was, when there was one.
    public let previous: Lesson?

    public init(kind: Kind, lesson: Lesson, previous: Lesson? = nil) {
        self.kind = kind
        self.lesson = lesson
        self.previous = previous
    }

    public var id: String { "\(kind.rawValue):\(lesson.id)" }
}

public enum TimetableDiff {
    /// Changes worth telling the student about.
    ///
    /// - The first snapshot of an account is a silent baseline.
    /// - Only lessons that have not ended yet count.
    /// - Days outside the previously seen window are new, not "added", so a
    ///   week rolling into view stays silent.
    /// - A lesson whose identifier changed but which sits in the same slot
    ///   with the same subject is compared as one lesson.
    public static func changes(
        from old: TimetableSnapshot?,
        to new: TimetableSnapshot,
        now: Date
    ) -> [TimetableChange] {
        guard let old, old.accountID == new.accountID else { return [] }

        let oldByID = index(old.lessons)
        let newByID = index(new.lessons)
        func isUpcoming(_ lesson: Lesson) -> Bool { lesson.end > now }

        let modified = newByID.values.compactMap { lesson -> TimetableChange? in
            guard isUpcoming(lesson), let before = oldByID[lesson.id] else { return nil }
            return classify(before, lesson)
        }

        let appeared = newByID.values.filter {
            oldByID[$0.id] == nil && isUpcoming($0) && old.covers($0.start)
        }
        let vanished = oldByID.values.filter {
            newByID[$0.id] == nil && isUpcoming($0) && new.covers($0.start)
        }

        let appearedBySlot = Dictionary(appeared.map { (Slot($0), $0) }) { first, _ in first }
        let moved = vanished.compactMap { before -> (Lesson, Lesson)? in
            appearedBySlot[Slot(before)].map { (before, $0) }
        }
        let movedOld = Set(moved.map(\.0.id))
        let movedNew = Set(moved.map(\.1.id))

        let replaced = moved.compactMap { classify($0.0, $0.1) }
        let added = appeared
            .filter { !movedNew.contains($0.id) && !$0.isCancelled }
            .map { TimetableChange(kind: .added, lesson: $0) }
        let removed = vanished
            .filter { !movedOld.contains($0.id) && !$0.isCancelled }
            .map { TimetableChange(kind: .removed, lesson: $0) }

        return (modified + replaced + added + removed)
            .sorted { ($0.lesson.start, $0.id) < ($1.lesson.start, $1.id) }
    }

    /// The most important difference between two versions of one lesson, or
    /// nil when nothing the student cares about changed.
    static func classify(_ before: Lesson, _ after: Lesson) -> TimetableChange? {
        let kind: TimetableChange.Kind? =
            if before.isCancelled != after.isCancelled {
                after.isCancelled ? .cancelled : .restored
            } else if after.isCancelled {
                nil
            } else if before.start != after.start || before.end != after.end {
                .time
            } else if before.substituteTeacher != after.substituteTeacher || before.teacher != after.teacher {
                .teacher
            } else if before.room != after.room {
                .room
            } else {
                nil
            }
        return kind.map { TimetableChange(kind: $0, lesson: after, previous: before) }
    }

    /// Only real lessons take part. Free-slot placeholders are noise, and a
    /// school-year event such as a day off is not a lesson that was added.
    private static func index(_ lessons: [Lesson]) -> [String: Lesson] {
        Dictionary(lessons.filter { $0.kind == .lesson }.map { ($0.id, $0) }) { first, _ in first }
    }
}

/// Identifies "the same lesson" across an identifier change.
private struct Slot: Hashable {
    let day: String
    let position: String
    let name: String

    init(_ lesson: Lesson) {
        day = KretaDate.dayString(lesson.start)
        position = lesson.index.map(String.init) ?? KretaDate.timeString(lesson.start)
        name = lesson.name.lowercased()
    }
}
