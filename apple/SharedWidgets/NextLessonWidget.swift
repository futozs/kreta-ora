import KretaKit
import SwiftUI
import WidgetKit

/// The lesson that matters right now, with a live countdown.
struct NextLessonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.nextLesson, provider: TimetableProvider()) { entry in
            NextLessonView(entry: entry)
                .containerBackground(for: .widget) { Color.board }
        }
        .configurationDisplayName("Következő óra")
        .description("Mi megy most, mi jön utána, és mennyi van még hátra.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner]
        #else
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        #endif
    }
}

struct NextLessonView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    var body: some View {
        #if os(watchOS)
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        default: rectangular
        }
        #else
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
        #endif
    }

    // MARK: Lock screen and watch face

    /// "8:00 Matematika · 12"
    private var inline: some View {
        Text(inlineText)
    }

    private var inlineText: String {
        guard let lesson = entry.summary?.lesson else { return entry.emptyText }
        let room = lesson.room.map { " · \($0)" } ?? ""
        return "\(KretaDate.timeString(lesson.start)) \(lesson.displayName)\(room)"
    }

    @ViewBuilder private var circular: some View {
        if let summary = entry.summary, let lesson = summary.lesson {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(lesson.index.map { "\($0). óra" } ?? summary.label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(KretaDate.timeString(lesson.start))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 3)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark")
            }
        }
    }

    @ViewBuilder private var rectangular: some View {
        if let summary = entry.summary, let lesson = summary.lesson {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(summary.label)
                    Spacer(minLength: 2)
                    Countdown(summary: summary)
                }
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
                Text(lesson.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text([timeRange(lesson), lesson.room, lesson.substituteTeacher].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(entry.emptyText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    #if os(watchOS)
    @ViewBuilder private var corner: some View {
        if let lesson = entry.summary?.lesson {
            Text(KretaDate.timeString(lesson.start))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .widgetLabel(lesson.displayName)
        } else {
            Image(systemName: "checkmark")
                .widgetLabel(entry.emptyText)
        }
    }
    #endif

    // MARK: Home screen

    #if !os(watchOS)
    @ViewBuilder private var small: some View {
        if let summary = entry.summary, let lesson = summary.lesson {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: summary.label)
                Text(lesson.displayName)
                    .font(.lessonTitle())
                    .foregroundStyle(.chalk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                LessonDetail(lesson: lesson)
                Countdown(summary: summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.chalkYellow)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyBoard(text: entry.emptyText)
        }
    }

    @ViewBuilder private var medium: some View {
        if let summary = entry.summary, let lesson = summary.lesson {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: summary.label)
                    Text(lesson.displayName)
                        .font(.lessonTitle(.title2))
                        .foregroundStyle(.chalk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    LessonDetail(lesson: lesson)
                    Countdown(summary: summary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.chalkYellow)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Rectangle()
                    .fill(.chalk.opacity(0.18))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Utána")
                    if let following = summary.following {
                        Text(following.displayName)
                            .font(.lessonTitle(.headline))
                            .foregroundStyle(.chalk)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        LessonDetail(lesson: following)
                    } else {
                        Text("Ez az utolsó óra")
                            .font(.subheadline)
                            .foregroundStyle(.chalkDim)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            EmptyBoard(text: entry.emptyText)
        }
    }
    #endif
}
