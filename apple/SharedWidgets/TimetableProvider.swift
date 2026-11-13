import Foundation
import KretaKit
import WidgetKit

/// What a widget draws at one moment. Everything is derived from the stored
/// timetable, so widgets never touch the network.
struct TimetableEntry: TimelineEntry {
    let date: Date
    /// Nil until the user has signed in and the first sync has finished.
    let schedule: Schedule?

    var summary: StatusSummary? {
        schedule.map { StatusSummary(schedule: $0, now: date) }
    }

    /// The next school day after today.
    var nextDay: DaySummary? {
        schedule?.nextSchoolDay(after: date)
    }

    /// Today while lessons remain, otherwise the next school day.
    var focusDay: DaySummary? {
        schedule?.focusDay(at: date)
    }

    var emptyText: String {
        schedule == nil ? "Jelentkezz be az appban" : "Nincs több óra"
    }
}

extension TimetableEntry {
    /// Shown in the widget gallery and while a real entry loads.
    static var sample: TimetableEntry {
        let now = Date()
        let day = KretaDate.startOfDay(now)
        func lesson(_ index: Int, _ name: String, _ room: String, offset: TimeInterval) -> Lesson {
            let start = now.addingTimeInterval(offset)
            return Lesson(
                id: "sample-\(index)", start: start, end: start.addingTimeInterval(45 * 60),
                name: name, index: index, teacher: "Kiss Béla", room: room
            )
        }
        let lessons = [
            lesson(2, "matematika", "12", offset: -20 * 60),
            lesson(3, "történelem", "204", offset: 35 * 60),
            lesson(4, "angol nyelv", "21", offset: 90 * 60),
            Lesson(
                id: "sample-next",
                start: KretaDate.addingDays(1, to: day).addingTimeInterval(8 * 3600),
                end: KretaDate.addingDays(1, to: day).addingTimeInterval(8 * 3600 + 45 * 60),
                name: "fizika", index: 1, teacher: "Nagy Anna", room: "Fizika előadó"
            ),
        ]
        return TimetableEntry(date: now, schedule: Schedule(lessons: lessons))
    }
}

struct TimetableProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimetableEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        completion(context.isPreview ? .sample : TimetableEntry(date: Date(), schedule: storedSchedule()))
    }

    /// One entry per moment the picture changes: every lesson start and end,
    /// and midnight. The app reloads the timeline after each sync, so the
    /// reload policy only matters when the app has not run for a while.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let now = Date()
        let schedule = storedSchedule()
        let dates = schedule?.refreshDates(from: now) ?? [now]
        let entries = dates.map { TimetableEntry(date: $0, schedule: schedule) }
        // With a single entry `.atEnd` would mean "ask again immediately" and
        // burn the widget's reload budget in a loop, so wait instead.
        let policy: TimelineReloadPolicy = entries.count > 1
            ? .atEnd
            : .after(now.addingTimeInterval(Self.idleReloadInterval))
        completion(Timeline(entries: entries, policy: policy))
    }

    /// How long a widget with nothing to schedule waits before looking again.
    private static let idleReloadInterval: TimeInterval = 6 * 3600

    private func storedSchedule() -> Schedule? {
        AppEnvironment.snapshots.load()?.schedule
    }
}
