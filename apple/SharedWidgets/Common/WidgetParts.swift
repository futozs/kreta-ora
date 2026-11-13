import KretaKit
import SwiftUI
import WidgetKit

/// The neutral card for "signed out" and "nothing left".
struct WidgetNote: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            Text(title)
                .kretaFont(KretaType.headline)
                .foregroundStyle(Palette.text)
                .lineLimit(2)
            Text(message)
                .kretaFont(KretaType.small)
                .foregroundStyle(Palette.textDim)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

/// The whole day as a bar: one rounded segment per lesson in its subject's
/// colour, a cancelled one only an outline, so its length and gaps read at a glance.
struct DayBar: View {
    let segments: [Segment]
    var height: CGFloat = 12
    var gap: CGFloat = 4
    var outline: Color = Palette.widgetOutline

    struct Segment: Hashable {
        /// Nil for a cancelled lesson.
        let color: Color?
    }

    init(lessons: [Lesson], height: CGFloat = 12, outline: Color = Palette.widgetOutline) {
        self.segments = lessons.map { Segment(color: $0.isCancelled ? nil : Subjects.color($0.name)) }
        self.height = height
        self.outline = outline
    }

    init(segments: [Segment], height: CGFloat = 12, outline: Color = Palette.widgetOutline) {
        self.segments = segments
        self.height = height
        self.outline = outline
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if let color = segment.color {
                    Capsule().fill(color)
                } else {
                    Capsule().strokeBorder(outline, lineWidth: 1.5)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A countdown that the system ticks by itself, with its label beside it.
struct WidgetCountdown: View {
    let model: NextLessonModel
    let now: Date
    var style: KretaTextStyle = KretaType.countdown
    var labelStyle: KretaTextStyle = KretaType.strong
    var color: Color = Palette.ink
    var labelColor: Color = Palette.inkMuted

    var body: some View {
        // Beside the time when it fits, under it in a narrow widget.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                valueText
                labelText
            }
            VStack(alignment: .leading, spacing: 0) {
                valueText
                labelText
            }
        }
    }

    private var valueText: some View {
        value
            .kretaFont(style, scalesWithDynamicType: false)
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    private var labelText: some View {
        Text(label)
            .kretaFont(labelStyle, scalesWithDynamicType: false)
            .foregroundStyle(labelColor)
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder private var value: some View {
        switch model.phase {
        case .running:
            Text(timerInterval: model.lesson.start...model.lesson.end, countsDown: true)
        case .soon:
            Text(timerInterval: min(now, model.lesson.start)...model.lesson.start, countsDown: true)
        case .later:
            Text(KretaDate.timeString(model.lesson.start))
        }
    }

    private var label: String {
        switch model.phase {
        case .running: L10n.left
        case .soon: L10n.widgetStartsIn
        case .later: Formatting.dayWord(model.lesson.start, now: now)
        }
    }
}

/// The system's own timer-driven bar, tinted to sit on a subject colour.
struct WidgetTimerBar: View {
    let interval: ClosedRange<Date>
    var tint: Color = Palette.ink

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            .progressViewStyle(.linear)
            .tint(tint)
            .accessibilityHidden(true)
    }
}
