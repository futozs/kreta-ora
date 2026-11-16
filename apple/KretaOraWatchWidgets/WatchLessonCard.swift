import KretaKit
import SwiftUI
import WidgetKit

/// The lesson in the Smart Stack and the rectangular complication: subject and
/// number on top, the live countdown big in the middle, and under it how far
/// the lesson has got or where it will be.
struct WatchLessonCard: View {
    let model: NextLessonModel
    let now: Date

    private var lesson: Lesson { model.lesson }
    private var color: Color { Subjects.color(lesson.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: SubjectSymbol.name(for: lesson.name))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                    .widgetAccentable()
                Text([Formatting.number(lesson), lesson.displayName].filter { !$0.isEmpty }.joined(separator: " "))
                    .kretaFont(KretaType.blockTitle.size(15), scalesWithDynamicType: false)
                    .lineLimit(1)
            }
            WidgetCountdown(
                model: model,
                now: now,
                style: KretaType.countdown.size(28),
                labelStyle: KretaType.small.size(13),
                color: .primary,
                labelColor: .secondary
            )
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder private var footer: some View {
        if model.phase == .running {
            HStack(spacing: 6) {
                WidgetTimerBar(interval: lesson.start...lesson.end, tint: color)
                    .widgetAccentable()
                Text(KretaDate.timeString(lesson.end))
                    .kretaFont(KretaType.time.size(12), scalesWithDynamicType: false)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text([lesson.room, Formatting.timeRange(lesson)].compactMap { $0 }.joined(separator: Formatting.separator))
                .kretaFont(KretaType.small.size(12), scalesWithDynamicType: false)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// The Smart Stack draws this behind the card; on a watch face the system drops it.
    static func background(for model: NextLessonModel?) -> some View {
        let color = model.map { Subjects.color($0.lesson.name) } ?? .clear
        return LinearGradient(
            colors: [color.opacity(0.42), color.opacity(0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
