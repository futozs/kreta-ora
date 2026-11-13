import Foundation
import KretaKit
import WidgetKit

/// What a widget draws at one moment. Everything is derived from the stored
/// timetable, so widgets never touch the network.
struct TimetableEntry: TimelineEntry {
    let date: Date
    /// Nil until the user has signed in and the first sync has finished.
    let schedule: Schedule?
    var relevance: TimelineEntryRelevance?

    var nextLesson: NextLessonModel? {
        schedule.flatMap { NextLessonModel(schedule: $0, now: date) }
    }

    var dayStart: DayStartCard? {
        schedule.flatMap { DayStartCard(schedule: $0, now: date) }
    }

    /// Shown in the widget gallery and while a real entry loads.
    static var sample: TimetableEntry {
        let now = Date()
        return TimetableEntry(date: now, schedule: DemoTimetable.snapshot(now: now).schedule)
    }
}

struct TimetableProvider: TimelineProvider {
    /// How long a widget with nothing to schedule waits before looking again.
    private static let idleReloadInterval: TimeInterval = 6 * 3600
    private static let horizon: TimeInterval = 36 * 3600
    private static let maxEntries = 64

    func placeholder(in context: Context) -> TimetableEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        completion(context.isPreview ? .sample : TimetableEntry(date: Date(), schedule: storedSchedule()))
    }

    /// One entry per moment the picture changes: every lesson start and end,
    /// an hour before each start (the countdown begins), and midnight. The app
    /// reloads the timeline after each sync, so the policy only matters when
    /// the app has not run for a while.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let now = Date()
        let schedule = storedSchedule()
        let dates = schedule.map { Self.dates($0, now: now) } ?? [now]
        let entries = dates.map { date in
            TimetableEntry(date: date, schedule: schedule, relevance: schedule.map { Self.relevance($0, at: date) })
        }
        // With a single entry `.atEnd` would mean "ask again immediately" and
        // burn the widget's reload budget in a loop, so wait instead.
        let policy: TimelineReloadPolicy = entries.count > 1
            ? .atEnd
            : .after(now.addingTimeInterval(Self.idleReloadInterval))
        completion(Timeline(entries: entries, policy: policy))
    }

    private static func dates(_ schedule: Schedule, now: Date) -> [Date] {
        let boundaries = schedule.refreshDates(from: now, horizon: horizon)
        let openings = NextLessonModel.windowOpenings(schedule, from: now, horizon: horizon)
        return Array(Set(boundaries + openings).sorted().prefix(maxEntries))
    }

    /// High while a lesson runs or is about to, so the Smart Stack brings the widget up then.
    private static func relevance(_ schedule: Schedule, at date: Date) -> TimelineEntryRelevance {
        guard let model = NextLessonModel(schedule: schedule, now: date) else {
            return TimelineEntryRelevance(score: 0)
        }
        switch model.phase {
        case .running:
            return TimelineEntryRelevance(score: 80, duration: model.lesson.end.timeIntervalSince(date))
        case .soon:
            return TimelineEntryRelevance(score: 100, duration: model.lesson.start.timeIntervalSince(date))
        case .later:
            return TimelineEntryRelevance(score: 5)
        }
    }

    private func storedSchedule() -> Schedule? {
        #if DEBUG
        if LaunchOptions.usesDemoData { return DemoTimetable.snapshot().schedule }
        #endif
        return AppEnvironment.snapshots.load()?.schedule
    }
}
