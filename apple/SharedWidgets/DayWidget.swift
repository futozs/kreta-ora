#if !os(watchOS)
import KretaKit
import SwiftUI
import WidgetKit

/// The whole day on the board: today while lessons remain, then the next
/// school day.
struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.day, provider: TimetableProvider()) { entry in
            DayView(entry: entry)
                .containerBackground(for: .widget) { Color.board }
        }
        .configurationDisplayName("Napi órarend")
        .description("A mai nap órái, tanítás után a következő napé.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    private var rowLimit: Int { family == .systemLarge ? 9 : 4 }

    var body: some View {
        if let day = entry.focusDay, !day.lessons.isEmpty {
            let rows = visibleRows(day)
            VStack(alignment: .leading, spacing: family == .systemLarge ? 7 : 4) {
                HStack {
                    Eyebrow(text: ChangeFormatter.dayLabel(day.day, relativeTo: entry.date))
                    Spacer()
                    if let span = day.span {
                        Text(span)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.chalkDim)
                    }
                }
                ForEach(rows) { lesson in
                    BoardLessonRow(lesson: lesson, isCurrent: lesson.isActive && lesson.contains(entry.date))
                }
                if day.lessons.count > rows.count, rows.last?.id != day.lessons.last?.id {
                    Text("és még \(remaining(day, after: rows)) óra")
                        .font(.caption2)
                        .foregroundStyle(.chalkDim)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyBoard(text: entry.emptyText)
        }
    }

    /// As many lessons as fit, starting with the one running or coming next,
    /// so the list scrolls with the day instead of showing what is over.
    private func visibleRows(_ day: DaySummary) -> [Lesson] {
        let firstRelevant = day.lessons.firstIndex { $0.end > entry.date } ?? 0
        let start = min(firstRelevant, max(0, day.lessons.count - rowLimit))
        return Array(day.lessons[start...].prefix(rowLimit))
    }

    private func remaining(_ day: DaySummary, after rows: [Lesson]) -> Int {
        guard let last = rows.last, let index = day.lessons.firstIndex(of: last) else { return 0 }
        return day.lessons.count - index - 1
    }
}
#endif
