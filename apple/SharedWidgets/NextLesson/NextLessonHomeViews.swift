#if os(iOS)
import KretaKit
import SwiftUI
import WidgetKit

/// The lesson that matters now, drawn as the app draws it: a block in the
/// subject's colour with a countdown the system ticks every second. Small
/// is the block alone; medium puts the next lessons beside it as tiles;
/// large stacks them under it.
struct NextLessonHomeView: View {
    let entry: TimetableEntry
    let family: WidgetFamily

    static let gap: CGFloat = 6

    var body: some View {
        if entry.schedule == nil {
            WidgetNote(title: L10n.appName, message: L10n.widgetSignedOut)
                .padding(16)
        } else if let model = entry.nextLesson {
            content(model)
        } else {
            WidgetNote(title: L10n.widgetNextName, message: L10n.nothingLeft)
                .padding(16)
        }
    }

    @ViewBuilder private func content(_ model: NextLessonModel) -> some View {
        switch family {
        case .systemMedium where !model.following.isEmpty:
            GeometryReader { proxy in
                // The block takes three fifths, the tiles the rest, as on Android.
                let blockWidth = (proxy.size.width - Self.gap) * 0.6
                HStack(spacing: Self.gap) {
                    MainBlock(model: model, now: entry.date, layout: .split)
                        .frame(width: blockWidth)
                    VStack(spacing: Self.gap) {
                        ForEach(model.following.prefix(3)) { lesson in
                            FollowTile(lesson: lesson, isRoomy: model.following.count < 3)
                        }
                    }
                }
            }
            .padding(Self.gap)
        case .systemMedium:
            MainBlock(model: model, now: entry.date, layout: .wide)
                .padding(Self.gap)
        case .systemLarge, .systemExtraLarge:
            VStack(spacing: Self.gap) {
                MainBlock(model: model, now: entry.date, layout: .wide)
                ForEach(model.following.prefix(3)) { lesson in
                    FollowRow(lesson: lesson)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(Self.gap)
        default:
            MainBlock(model: model, now: entry.date, layout: .narrow, isFlush: true)
        }
    }

    /// Small widgets are the block itself; the others hold blocks on the app's ground.
    static func background(for entry: TimetableEntry, family: WidgetFamily) -> Color {
        if family == .systemSmall, let model = entry.nextLesson {
            return Subjects.color(model.lesson.name)
        }
        return entry.schedule == nil || entry.nextLesson == nil ? Palette.surface : Palette.background
    }
}

private struct MainBlock: View {
    enum Layout {
        /// Number, name and times in a row, as in the app.
        case wide
        /// Narrow: the number goes, the times join the detail line.
        case narrow
        /// Beside the tiles: the number stays, the times join the detail line.
        case split
    }

    let model: NextLessonModel
    let now: Date
    let layout: Layout
    /// Fills the widget edge to edge, so it needs no shape of its own.
    var isFlush = false

    private var lesson: Lesson { model.lesson }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 8)
            WidgetCountdown(
                model: model,
                now: now,
                style: KretaType.countdown.size(countdownSize),
                labelStyle: KretaType.strong.size(layout == .split ? 13 : 15).weight(500)
            )
            if model.phase == .running {
                WidgetTimerBar(interval: lesson.start...lesson.end)
                    .padding(.top, 10)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if !isFlush {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Subjects.color(lesson.name))
            }
        }
    }

    private var countdownSize: CGFloat {
        switch layout {
        case .wide: 46
        case .narrow: 34
        case .split: 36
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            if layout != .narrow {
                Text(Formatting.number(lesson))
                    .kretaFont(KretaType.number, scalesWithDynamicType: false)
                    .frame(width: 40, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.displayName)
                    .kretaFont(nameStyle, scalesWithDynamicType: false)
                    .lineLimit(layout == .wide ? 2 : 1)
                LessonDetailText(detail: LessonDetail(lesson, withTime: layout != .wide), scalesWithDynamicType: false)
                    .foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if layout == .wide {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(KretaDate.timeString(lesson.start))
                        .kretaFont(KretaType.time, scalesWithDynamicType: false)
                    Text(KretaDate.timeString(lesson.end))
                        .kretaFont(KretaType.time.weight(400), scalesWithDynamicType: false)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.leading, 10)
            }
        }
    }

    private var nameStyle: KretaTextStyle {
        switch layout {
        case .wide: KretaType.blockTitleLarge
        case .narrow: KretaType.blockTitleLarge.size(21)
        case .split: KretaType.blockTitleLarge.size(22)
        }
    }
}

/// A later lesson as a tile beside the current one: start time over the name.
private struct FollowTile: View {
    let lesson: Lesson
    let isRoomy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lesson.isCancelled ? L10n.lessonCancelled : KretaDate.timeString(lesson.start))
                .kretaFont(KretaType.time.size(17).weight(800), scalesWithDynamicType: false)
                .foregroundStyle(lesson.isCancelled ? Palette.danger : Palette.ink)
            Text(lesson.displayName)
                .kretaFont(KretaType.strong, scalesWithDynamicType: false)
                .strikethrough(lesson.isCancelled)
                .foregroundStyle(lesson.isCancelled ? Palette.textDim : Palette.ink)
                .lineLimit(isRoomy ? 2 : 1)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { FollowShape(lesson: lesson, cornerRadius: 16) }
    }
}

/// A later lesson of the day as a row under the current one.
private struct FollowRow: View {
    let lesson: Lesson

    var body: some View {
        HStack(spacing: 0) {
            Text(Formatting.number(lesson))
                .kretaFont(KretaType.number.size(19), scalesWithDynamicType: false)
                .frame(width: 40, alignment: .leading)
            Text(lesson.displayName)
                .kretaFont(KretaType.blockTitle.size(18), scalesWithDynamicType: false)
                .strikethrough(lesson.isCancelled)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(lesson.isCancelled ? L10n.lessonCancelled : KretaDate.timeString(lesson.start))
                .kretaFont(lesson.isCancelled ? KretaType.button : KretaType.time.weight(800), scalesWithDynamicType: false)
                .foregroundStyle(lesson.isCancelled ? Palette.danger : Palette.ink)
        }
        .foregroundStyle(lesson.isCancelled ? Palette.textDim : Palette.ink)
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .frame(height: 50)
        .background { FollowShape(lesson: lesson, cornerRadius: 18) }
    }
}

private struct FollowShape: View {
    let lesson: Lesson
    let cornerRadius: CGFloat

    var body: some View {
        if lesson.isCancelled {
            DashedOutline(cornerRadius: cornerRadius, color: Palette.widgetOutline)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Subjects.color(lesson.name))
        }
    }
}
#endif
