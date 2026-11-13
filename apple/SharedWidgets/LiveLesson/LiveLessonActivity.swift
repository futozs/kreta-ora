#if os(iOS)
import ActivityKit
import AppIntents
import KretaKit
import SwiftUI
import WidgetKit

/// The school day on the lock screen, in the Dynamic Island and, through the
/// small family, in the watch's Smart Stack.
struct LiveLessonActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveLessonAttributes.self) { context in
            LiveLessonLockScreen(state: context.state, now: Date())
                .activityBackgroundTint(Palette.background)
                .activitySystemActionForegroundColor(Palette.text)
        } dynamicIsland: { context in
            let state = context.state
            let focus = state.focus(at: Date())
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let focus { SubjectDot(segment: focus.segment, size: 12).padding(.leading, 6).padding(.top, 6) }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let focus { LiveCountdown(focus: focus).kretaFont(KretaType.time.size(22).weight(800)) }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let focus { LiveTitle(focus: focus).lineLimit(1) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveDayBar(state: state).padding(.top, 6)
                }
            } compactLeading: {
                if let focus { SubjectDot(segment: focus.segment, size: 10) }
            } compactTrailing: {
                if let focus {
                    LiveCountdown(focus: focus)
                        .kretaFont(KretaType.time.size(14).weight(800), scalesWithDynamicType: false)
                        .frame(maxWidth: 48)
                }
            } minimal: {
                if let focus {
                    ProgressView(
                        timerInterval: focus.isRunning ? focus.segment.start...focus.segment.end : Date()...focus.segment.start,
                        countsDown: !focus.isRunning
                    ) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular)
                    .tint(focus.segment.swatch.map(Subjects.color) ?? Palette.text)
                }
            }
            .keylineTint(focus?.segment.swatch.map(Subjects.color))
        }
        .supplementalActivityFamilies([.small])
    }
}

/// The lock-screen card: what runs or comes next, the time left, the day as a bar.
struct LiveLessonLockScreen: View {
    let state: LiveLessonAttributes.ContentState
    let now: Date
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        if let focus = state.focus(at: now) {
            VStack(alignment: .leading, spacing: activityFamily == .small ? 6 : 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        LiveTitle(focus: focus)
                            .lineLimit(1)
                        Text(focus.isRunning ? focus.segment.detail : [focus.segment.timeRange, focus.segment.detail]
                            .filter { !$0.isEmpty }.joined(separator: Formatting.separator))
                            .kretaFont(KretaType.small, scalesWithDynamicType: false)
                            .foregroundStyle(Palette.textDim)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        LiveCountdown(focus: focus)
                            .kretaFont(KretaType.countdown.size(activityFamily == .small ? 22 : 34), scalesWithDynamicType: false)
                            .foregroundStyle(Palette.text)
                        Text(focus.isRunning ? L10n.left : L10n.widgetStartsIn)
                            .kretaFont(KretaType.small.size(12), scalesWithDynamicType: false)
                            .foregroundStyle(Palette.textDim)
                    }
                }
                LiveDayBar(state: state)
                if activityFamily != .small {
                    Button(intent: HideLiveLessonIntent()) {
                        Text(L10n.liveHideToday)
                            .kretaFont(KretaType.strong, scalesWithDynamicType: false)
                            .foregroundStyle(Palette.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(activityFamily == .small ? 10 : 16)
        } else {
            Text(L10n.liveDayOver)
                .kretaFont(KretaType.headline, scalesWithDynamicType: false)
                .foregroundStyle(Palette.text)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LiveTitle: View {
    let focus: (segment: LiveLessonAttributes.Segment, isRunning: Bool)

    var body: some View {
        Text(focus.isRunning ? focus.segment.title : L10n.liveNextTitle(focus.segment.title))
            .kretaFont(KretaType.blockTitle, scalesWithDynamicType: false)
            .foregroundStyle(Palette.text)
    }
}

private struct LiveCountdown: View {
    let focus: (segment: LiveLessonAttributes.Segment, isRunning: Bool)

    var body: some View {
        Group {
            if focus.isRunning {
                Text(timerInterval: focus.segment.start...focus.segment.end, countsDown: true)
            } else {
                Text(timerInterval: min(Date(), focus.segment.start)...focus.segment.start, countsDown: true)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

private struct SubjectDot: View {
    let segment: LiveLessonAttributes.Segment
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(segment.swatch.map(Subjects.color) ?? Palette.textFaint)
            .frame(width: size, height: size)
    }
}

/// The day from the first bell to the last: each lesson a segment as long as
/// it lasts, breaks as space. What has passed is in full colour, the rest
/// faded; the system moves the boundary by itself.
struct LiveDayBar: View {
    let state: LiveLessonAttributes.ContentState
    private let height: CGFloat = 10

    var body: some View {
        let start = state.start
        let end = max(state.end, start.addingTimeInterval(60))
        GeometryReader { proxy in
            let segments = bar(width: proxy.size.width, start: start, end: end)
            segments
                .opacity(0.35)
                .overlay {
                    segments.mask(alignment: .leading) {
                        ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .scaleEffect(x: 1, y: 8, anchor: .center)
                    }
                }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, start: Date, end: Date) -> some View {
        let total = end.timeIntervalSince(start)
        return ZStack(alignment: .leading) {
            ForEach(state.lessons) { segment in
                let x = width * segment.start.timeIntervalSince(start) / total
                let length = max(width * segment.end.timeIntervalSince(segment.start) / total - 2, 2)
                Group {
                    if let swatch = segment.swatch {
                        Capsule().fill(Subjects.color(swatch))
                    } else {
                        Capsule().strokeBorder(Palette.textFaint, lineWidth: 1.5)
                    }
                }
                .frame(width: length, height: height)
                .offset(x: x)
            }
        }
        .frame(width: width, height: height, alignment: .leading)
    }
}
#endif
