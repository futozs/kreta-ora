import ActivityKit
import Foundation
import KretaKit
import os
import Synchronization

/// Keeps the school-day Live Activity in step with the timetable.
///
/// It is opt-in. It appears an hour before the first lesson and goes after the
/// last. iOS gives an app no clock of its own in the background, so the next
/// day's activity is requested ahead with a start date, and the activity's
/// state carries the whole day so the lock screen can move from lesson to
/// lesson without the app. Every time the app runs (launch, foreground, sync,
/// background refresh) the activity is brought up to date.
final class LiveLessonController: Sendable {
    static let shared = LiveLessonController()

    private typealias LiveActivity = Activity<LiveLessonAttributes>

    private struct State {
        var lastSnapshot: TimetableSnapshot?
        /// Activities this app asked for, with their day.
        var requested: [String: Date] = [:]
        /// Activities this app ended; their disappearance is not the user's doing.
        var endedByApp = Set<String>()
    }

    private let state = Mutex(State())
    private let logger = Logger(subsystem: "hu.kretaora", category: "live")

    var isEnabled: Bool { LivePreferences.isEnabled }

    func setEnabled(_ isEnabled: Bool) {
        LivePreferences.isEnabled = isEnabled
        update(snapshot: state.withLock { $0.lastSnapshot })
    }

    func update(snapshot: TimetableSnapshot?, now: Date = Date()) {
        state.withLock { $0.lastSnapshot = snapshot }
        Task { await self.apply(snapshot: snapshot, now: now) }
    }

    private func apply(snapshot: TimetableSnapshot?, now: Date) async {
        let activities = LiveActivity.activities
        noteDismissals(present: activities)
        guard
            LivePreferences.isEnabled,
            ActivityAuthorizationInfo().areActivitiesEnabled,
            let schedule = snapshot?.schedule,
            let day = Self.day(to: schedule, now: now),
            let window = LiveDay.window(schedule, on: day),
            !LivePreferences.isHidden(on: day)
        else {
            await end(activities)
            return
        }

        let contentState = LiveLessonAttributes.ContentState(lessons: schedule.lessons(on: day))
        let content = ActivityContent(
            state: contentState,
            staleDate: contentState.nextBoundary(after: max(now, window.lowerBound)),
            relevanceScore: 1
        )
        let currentID = activities.first { $0.attributes.day == day && $0.activityState != .ended }?.id
        await end(activities.filter { $0.id != currentID })
        if let current = activities.first(where: { $0.id == currentID }) {
            await current.update(content)
        } else {
            request(day: day, content: content, startsAt: window.lowerBound, now: now)
        }
    }

    /// Today until its last lesson ends, then the next school day.
    private static func day(to schedule: Schedule, now: Date) -> Date? {
        let today = KretaDate.startOfDay(now)
        if let window = LiveDay.window(schedule, on: today), now < window.upperBound { return today }
        return schedule.nextSchoolDay(after: now)?.day
    }

    private func request(
        day: Date,
        content: ActivityContent<LiveLessonAttributes.ContentState>,
        startsAt start: Date,
        now: Date
    ) {
        let attributes = LiveLessonAttributes(day: day)
        do {
            let activity: LiveActivity
            if start > now, let first = content.state.focus(at: start)?.segment {
                // Requested ahead: iOS shows it at the start date with a short alert.
                let alert = AlertConfiguration(
                    title: LocalizedStringResource(stringLiteral: L10n.liveStartAlertTitle(KretaDate.timeString(first.start))),
                    body: LocalizedStringResource(stringLiteral: first.title),
                    sound: .default
                )
                activity = try LiveActivity.request(
                    attributes: attributes, content: content, pushType: nil,
                    style: .standard, alertConfiguration: alert, start: start
                )
            } else {
                activity = try LiveActivity.request(attributes: attributes, content: content, pushType: nil)
            }
            let id = activity.id
            state.withLock { $0.requested[id] = day }
        } catch {
            logger.error("Could not start the live lesson: \(error.localizedDescription)")
        }
    }

    private func end(_ activities: [LiveActivity]) async {
        for activity in activities {
            let id = activity.id
            state.withLock { _ = $0.endedByApp.insert(id) }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// An activity this app started for today that the user swiped away
    /// hides the live lesson for the rest of that day, like on Android.
    private func noteDismissals(present activities: [LiveActivity]) {
        let present = Dictionary(activities.map { ($0.id, $0.activityState) }, uniquingKeysWith: { first, _ in first })
        let dismissedDays = state.withLock { state -> [Date] in
            let gone = state.requested.filter { id, _ in
                !state.endedByApp.contains(id) && (present[id] == nil || present[id] == .dismissed)
            }
            gone.keys.forEach { state.requested[$0] = nil }
            return Array(gone.values)
        }
        for day in dismissedDays where KretaDate.isSameDay(day, Date()) {
            LivePreferences.hide(on: day)
            logger.info("Live lesson dismissed for the day")
        }
    }
}
