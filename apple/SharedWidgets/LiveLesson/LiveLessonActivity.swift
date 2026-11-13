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
            let focus = context.state.focus(at: Date())
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let focus {
                        SubjectBadge(segment: focus.segment, size: 52, showsNumber: true)
                            .padding(.leading, 4)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let focus {
                        VStack(alignment: .trailing, spacing: 0) {
                            LiveCountdown(focus: focus)
                                .kretaFont(KretaType.countdown.size(30), scalesWithDynamicType: false)
                                .foregroundStyle(Palette.text)
                            Text(focus.isRunning ? L10n.left : L10n.widgetStartsIn)
                                .kretaFont(KretaType.small.size(12), scalesWithDynamicType: false)
                                .foregroundStyle(Palette.textDim)
                        }
                        .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let focus {
                        VStack(alignment: .leading, spacing: 2) {
                            LiveTitle(focus: focus)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(focus.segment.detail)
                                .kretaFont(KretaType.small.size(13), scalesWithDynamicType: false)
                                .foregroundStyle(Palette.textDim)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveDayBar(state: context.state)
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                }
            } compactLeading: {
                if let focus {
                    SubjectIcon(segment: focus.segment)
                        .font(.system(size: 15, weight: .bold))
                        .padding(.leading, 2)
                }
            } compactTrailing: {
                if let focus {
                    // A fixed width keeps the island from resizing as the digits change.
                    LiveCountdown(focus: focus)
                        .kretaFont(KretaType.time.size(15).weight(800), scalesWithDynamicType: false)
                        .foregroundStyle(focus.segment.swatch.map(Subjects.color) ?? Palette.text)
                        .frame(width: countdownWidth(for: focus), alignment: .trailing)
                }
            } minimal: {
                if let focus {
                    SubjectIcon(segment: focus.segment)
                        .font(.system(size: 14, weight: .bold))
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
        if activityFamily == .small {
            LiveLessonSmall(state: state, now: now)
        } else if let focus = state.focus(at: now) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    SubjectBadge(segment: focus.segment, size: 44, showsNumber: false)
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
                            .kretaFont(KretaType.countdown.size(34), scalesWithDynamicType: false)
                            .foregroundStyle(Palette.text)
                        Text(focus.isRunning ? L10n.left : L10n.widgetStartsIn)
                            .kretaFont(KretaType.small.size(12), scalesWithDynamicType: false)
                            .foregroundStyle(Palette.textDim)
                    }
                }
                LiveDayBar(state: state)
                Button(intent: HideLiveLessonIntent()) {
                    Text(L10n.liveHideToday)
                        .kretaFont(KretaType.strong, scalesWithDynamicType: false)
                        .foregroundStyle(Palette.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        } else {
            Text(L10n.liveDayOver)
                .kretaFont(KretaType.headline, scalesWithDynamicType: false)
                .foregroundStyle(Palette.text)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The watch's Smart Stack (and CarPlay) card: the same block the app and the
/// widget show, in the subject's colour with near-black text, so it reads on
/// whatever background the system puts behind it. The watch may draw this
/// family on a light material and ignores the activity's background tint, so
/// the block brings its own fill instead of relying on palette text colours.
struct LiveLessonSmall: View {
    let state: LiveLessonAttributes.ContentState
    let now: Date

    var body: some View {
        Group {
            if let focus = state.focus(at: now) {
                block(focus)
                    .background(focus.segment.swatch.map(Subjects.color) ?? Palette.ink.opacity(0.08))
            } else {
                Text(L10n.liveDayOver)
                    .kretaFont(KretaType.blockTitle.size(16), scalesWithDynamicType: false)
                    .foregroundStyle(Palette.ink)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(Color(rgb: 0xF3F0E7))
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func block(_ focus: (segment: LiveLessonAttributes.Segment, isRunning: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: SubjectSymbol.name(for: focus.segment.name))
                    .font(.system(size: 13, weight: .bold))
                Text(focus.isRunning ? focus.segment.title : L10n.liveNextTitle(focus.segment.title))
                    .kretaFont(KretaType.blockTitle.size(16), scalesWithDynamicType: false)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Palette.ink)
            Text(focus.segment.detail)
                .kretaFont(KretaType.small.size(11), scalesWithDynamicType: false)
                .foregroundStyle(Palette.inkMuted)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                LiveCountdown(focus: focus)
                    .kretaFont(KretaType.countdown.size(26), scalesWithDynamicType: false)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    // Not fixedSize: the renderer cannot measure a ticking timer.
                    .layoutPriority(1)
                Text(focus.isRunning ? L10n.left : L10n.widgetStartsIn)
                    .kretaFont(KretaType.strong.size(11), scalesWithDynamicType: false)
                    .foregroundStyle(Palette.inkMuted)
                    .lineLimit(1)
            }
            if focus.isRunning {
                ProgressView(timerInterval: focus.segment.start...focus.segment.end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(Palette.ink)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

/// The subject's sign in its colour; an outline sign when the lesson is cancelled.
private struct SubjectIcon: View {
    let segment: LiveLessonAttributes.Segment

    var body: some View {
        Image(systemName: SubjectSymbol.name(for: segment.name))
            .foregroundStyle(segment.swatch.map(Subjects.color) ?? Palette.textFaint)
    }
}

/// A rounded square in the subject's colour with its sign, and the lesson
/// number under it where there is room.
private struct SubjectBadge: View {
    let segment: LiveLessonAttributes.Segment
    let size: CGFloat
    let showsNumber: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: SubjectSymbol.name(for: segment.name))
                .font(.system(size: size * 0.4, weight: .bold))
            if showsNumber, let number = segment.number {
                Text(L10n.lessonNumber(number))
                    .kretaFont(KretaType.number.size(size * 0.26), scalesWithDynamicType: false)
            }
        }
        .foregroundStyle(Palette.ink)
        .frame(width: size, height: size)
        .background(
            segment.swatch.map(Subjects.color) ?? Palette.textFaint,
            in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        )
    }
}

/// Room for "23:57" or, more than an hour ahead, "1:05:09".
private func countdownWidth(for focus: (segment: LiveLessonAttributes.Segment, isRunning: Bool)) -> CGFloat {
    let target = focus.isRunning ? focus.segment.end : focus.segment.start
    return target.timeIntervalSinceNow >= 3600 ? 60 : 44
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
        let segments = bar(start: start, end: end)
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
            .frame(height: height)
            .accessibilityHidden(true)
    }

    private func bar(start: Date, end: Date) -> some View {
        let total = end.timeIntervalSince(start)
        return SpanLayout(height: height) {
            ForEach(state.lessons) { segment in
                Group {
                    if let swatch = segment.swatch {
                        Capsule().fill(Subjects.color(swatch))
                    } else {
                        Capsule().strokeBorder(Palette.textFaint, lineWidth: 1.5)
                    }
                }
                // A hair of space between lessons that follow without a break.
                .padding(.trailing, 2)
                .spanShare(
                    start: segment.start.timeIntervalSince(start) / total,
                    length: segment.end.timeIntervalSince(segment.start) / total
                )
            }
        }
    }
}
#endif
