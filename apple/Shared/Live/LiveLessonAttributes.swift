#if os(iOS)
import ActivityKit
import Foundation
import KretaKit

/// The school day as a Live Activity. The state carries the whole day, so the
/// lock screen can pick the running or next lesson by itself between updates.
struct LiveLessonAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var lessons: [Segment]
    }

    /// One lesson of the day, as small as the 4 KB budget asks.
    struct Segment: Codable, Hashable, Sendable, Identifiable {
        let id: String
        let name: String
        let number: Int?
        /// Room and teacher, the substitute in place of the teacher.
        let detail: String
        let start: Date
        let end: Date
        /// Nil for a cancelled lesson: it is drawn as an outline.
        let swatch: SubjectSwatch?

        var isCancelled: Bool { swatch == nil }

        /// "3. Fizika"
        var title: String { [number.map(L10n.lessonNumber), name].compactMap { $0 }.joined(separator: " ") }

        var timeRange: String { "\(KretaDate.timeString(start))–\(KretaDate.timeString(end))" }
    }

    /// Start of the school day the activity belongs to.
    let day: Date
}

extension LiveLessonAttributes.ContentState {
    init(lessons: [Lesson]) {
        self.lessons = lessons.map { lesson in
            LiveLessonAttributes.Segment(
                id: lesson.id,
                name: lesson.displayName,
                number: lesson.index,
                detail: [lesson.room, lesson.substituteTeacher.map(L10n.substitute) ?? lesson.teacher]
                    .compactMap { $0 }
                    .joined(separator: Formatting.separator),
                start: lesson.start,
                end: lesson.end,
                swatch: lesson.isCancelled ? nil : SubjectPalette.swatch(for: lesson.name)
            )
        }
    }

    var start: Date { lessons.first?.start ?? .distantPast }
    var end: Date { lessons.last?.end ?? .distantPast }

    /// The running lesson, or the next one to start, at `now`.
    func focus(at now: Date) -> (segment: LiveLessonAttributes.Segment, isRunning: Bool)? {
        let held = lessons.filter { !$0.isCancelled }
        if let running = held.first(where: { $0.start <= now && now < $0.end }) { return (running, true) }
        return held.first { $0.start > now }.map { ($0, false) }
    }

    /// The next moment the picture changes, so the system redraws then.
    func nextBoundary(after now: Date) -> Date? {
        lessons.filter { !$0.isCancelled }.flatMap { [$0.start, $0.end] }.filter { $0 > now }.min()
    }
}
#endif
