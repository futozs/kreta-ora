import KretaKit
import SwiftUI
import WidgetKit

/// "Mikor kezdünk?": when the next school day starts.
struct DayStartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.dayStart, provider: TimetableProvider()) { entry in
            DayStartEntryView(entry: entry)
        }
        .configurationDisplayName(L10n.widgetDayStartName)
        .description(L10n.widgetDayStartDescription)
        .supportedFamilies(Self.families)
    }

    #if os(iOS)
    private static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
    #else
    private static let families: [WidgetFamily] = [.accessoryRectangular]
    #endif
}

struct DayStartEntryView: View {
    let entry: TimetableEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                DayStartAccessoryView(entry: entry)
            } else {
                DayStartHomeView(entry: entry, family: family)
            }
        }
        .containerBackground(for: .widget) {
            family == .accessoryRectangular ? Color.clear : Palette.surface
        }
    }
}
