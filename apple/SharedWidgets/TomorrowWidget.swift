import KretaKit
import SwiftUI
import WidgetKit

/// When the next school day starts, and with what.
struct TomorrowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.tomorrow, provider: TimetableProvider()) { entry in
            TomorrowView(entry: entry)
                .containerBackground(for: .widget) { Color.board }
        }
        .configurationDisplayName("Holnapi kezdés")
        .description("Mikor és mivel kezdődik a következő tanítási nap.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryRectangular, .accessoryCircular, .accessoryInline]
        #else
        [.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        #endif
    }
}

struct TomorrowView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    private var day: DaySummary? { entry.nextDay }

    /// "Holnap", or the weekday when the next school day is further away.
    private var dayName: String {
        guard let first = day?.first else { return "Holnap" }
        return ChangeFormatter.dayLabel(first.start, relativeTo: entry.date) == "Holnap"
            ? "Holnap"
            : KretaDate.weekdayName(first.start)
    }

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: small
        }
    }

    /// "Holnap 8:00 Fizika"
    private var inline: some View {
        Text(inlineText)
    }

    private var inlineText: String {
        guard let first = day?.first else { return entry.emptyText }
        return "\(dayName) \(KretaDate.timeString(first.start)) \(first.displayName)"
    }

    @ViewBuilder private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let first = day?.first {
                VStack(spacing: 0) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 11))
                    Text(KretaDate.timeString(first.start))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 3)
            } else {
                Image(systemName: "moon.zzz")
            }
        }
    }

    @ViewBuilder private var rectangular: some View {
        if let day, let first = day.first {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(dayName) · \(KretaDate.timeString(first.start))")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text([first.displayName, first.room].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .lineLimit(1)
                Text(warning(day) ?? day.span ?? "")
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

    @ViewBuilder private var small: some View {
        if let day, let first = day.first {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "\(dayName) kezdés")
                Text(KretaDate.timeString(first.start))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.chalk)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text([first.displayName, first.room].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.chalk)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let warning = warning(day) {
                    Text(warning)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(day.cancelledCount > 0 ? .chalkRed : .chalkBlue)
                        .lineLimit(1)
                }
                if let span = day.span {
                    Text(span)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.chalkDim)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyBoard(text: entry.emptyText)
        }
    }

    /// "1 óra elmarad" or "2 helyettesítés", when there is something to warn about.
    private func warning(_ day: DaySummary) -> String? {
        if day.cancelledCount > 0 { return "\(day.cancelledCount) óra elmarad" }
        if day.substitutedCount > 0 { return "\(day.substitutedCount) helyettesítés" }
        return nil
    }
}
