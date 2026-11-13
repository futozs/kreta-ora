import KretaKit
import SwiftUI
import WidgetKit

struct NextLessonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.nextLesson, provider: TimetableProvider()) { entry in
            NextLessonEntryView(entry: entry)
        }
        .configurationDisplayName(L10n.widgetNextName)
        .description(L10n.widgetNextDescription)
        .supportedFamilies(Self.families)
        .contentMarginsDisabled()
    }

    #if os(iOS)
    private static let families: [WidgetFamily] = [
        .systemSmall, .systemMedium, .systemLarge,
        .accessoryRectangular, .accessoryCircular, .accessoryInline,
    ]
    #else
    private static let families: [WidgetFamily] = [
        .accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline,
    ]
    #endif
}

struct NextLessonEntryView: View {
    let entry: TimetableEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        #if os(iOS)
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            NextLessonHomeView(entry: entry, family: family)
                .containerBackground(for: .widget) {
                    NextLessonHomeView.background(for: entry, family: family)
                }
        #endif
        default:
            NextLessonAccessoryView(entry: entry, family: family)
                .containerBackground(for: .widget) { Color.clear }
        }
    }
}
