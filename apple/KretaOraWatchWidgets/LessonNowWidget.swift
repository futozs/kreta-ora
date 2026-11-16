import AppIntents
import KretaKit
import SwiftUI
import WidgetKit

/// The lesson the Smart Stack brings to the top by itself, without the user
/// adding a widget: from the break before a lesson until its bell.
struct LessonNowWidget: Widget {
    var body: some WidgetConfiguration {
        RelevanceConfiguration(kind: WidgetKind.lessonNow, provider: LessonNowProvider()) { entry in
            Group {
                if let model = entry.model {
                    WatchLessonCard(model: model, now: entry.now)
                } else {
                    Text(L10n.nothingLeft)
                        .kretaFont(KretaType.small, scalesWithDynamicType: false)
                }
            }
            .containerBackground(for: .widget) {
                WatchLessonCard.background(for: entry.model)
            }
        }
        .configurationDisplayName(L10n.widgetNowName)
        .description(L10n.widgetNowDescription)
    }
}

/// One lesson in one of its two windows. The system picks the configuration
/// whose window holds the current time, so the break and the lesson itself
/// are separate configurations with their own countdowns.
struct LessonNowIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Óra most"
    static let isDiscoverable = false

    @Parameter(title: "Kezdés")
    var start: Date?

    @Parameter(title: "Tart")
    var isRunning: Bool?

    init() {}

    init(start: Date, isRunning: Bool) {
        self.start = start
        self.isRunning = isRunning
    }
}

struct LessonNowEntry: RelevanceEntry {
    let model: NextLessonModel?
    let now: Date
}

struct LessonNowProvider: RelevanceEntriesProvider {
    /// Before the day's first lesson, or after a free period, the card comes up this early.
    static let lead: TimeInterval = 15 * 60
    /// The phone sends about a week; a few school days ahead is plenty, and the
    /// app asks for fresh relevance after every sync.
    private static let horizon: TimeInterval = 4 * 24 * 3600

    func relevance() async -> WidgetRelevance<LessonNowIntent> {
        guard let schedule = TimetableProvider.storedSchedule() else { return WidgetRelevance([]) }
        let now = Date()
        let lessons = schedule.activeLessons.filter { $0.end > now && $0.start < now.addingTimeInterval(Self.horizon) }
        var attributes: [WidgetRelevanceAttribute<LessonNowIntent>] = []
        for lesson in lessons {
            let breakStart = Self.breakStart(before: lesson, in: schedule)
            if breakStart < lesson.start {
                attributes.append(WidgetRelevanceAttribute(
                    configuration: LessonNowIntent(start: lesson.start, isRunning: false),
                    context: .date(interval: DateInterval(start: breakStart, end: lesson.start), kind: .scheduled)
                ))
            }
            attributes.append(WidgetRelevanceAttribute(
                configuration: LessonNowIntent(start: lesson.start, isRunning: true),
                context: .date(interval: DateInterval(start: lesson.start, end: lesson.end), kind: .scheduled)
            ))
        }
        return WidgetRelevance(attributes)
    }

    func entry(configuration: LessonNowIntent, context: Context) async throws -> LessonNowEntry {
        if context.isPreview { return placeholder(context: context) }
        guard let schedule = TimetableProvider.storedSchedule(),
              let start = configuration.start,
              let lesson = schedule.activeLessons.first(where: { $0.start == start })
        else { return LessonNowEntry(model: nil, now: Date()) }
        // Built for the window, not for the moment the system asks, so a card
        // made a little early or late still shows the right countdown.
        let now = configuration.isRunning == true
            ? lesson.start
            : min(max(Date(), Self.breakStart(before: lesson, in: schedule)), lesson.start.addingTimeInterval(-1))
        return LessonNowEntry(model: NextLessonModel(schedule: schedule, now: now), now: now)
    }

    func placeholder(context: Context) -> LessonNowEntry {
        let sample = TimetableEntry.sample
        return LessonNowEntry(model: sample.nextLesson, now: sample.date)
    }

    /// The end of the lesson before on the same day, but at most `lead` earlier.
    private static func breakStart(before lesson: Lesson, in schedule: Schedule) -> Date {
        let earliest = lesson.start.addingTimeInterval(-lead)
        let previousEnd = schedule.lessons(on: lesson.start)
            .filter { $0.isActive && $0.end <= lesson.start }
            .map(\.end)
            .max()
        return max(earliest, previousEnd ?? earliest)
    }
}
