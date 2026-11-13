import KretaKit
import SwiftUI

/// One lesson as a block of its subject's colour. A cancelled lesson loses
/// its fill and keeps only a dashed outline: the slot is still there, but
/// nothing is in it. A lesson that is over shrinks to one quiet line, so what
/// is left in colour is what is still ahead.
struct LessonBlock: View {
    let lesson: Lesson
    let mode: BlockMode

    static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    static let numberWidth: CGFloat = 40

    var body: some View {
        Group {
            if mode == .past {
                PastRow(lesson: lesson)
            } else if lesson.isCancelled {
                CancelledBlock(lesson: lesson)
            } else {
                FilledBlock(lesson: lesson, mode: mode)
            }
        }
        .animation(.snappy, value: mode)
    }
}

private struct FilledBlock: View {
    let lesson: Lesson
    let mode: BlockMode

    private var isEmphasized: Bool { mode == .running || mode == .upNext }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text(Formatting.number(lesson))
                    .kretaFont(KretaType.number)
                    .frame(width: LessonBlock.numberWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    Text(lesson.displayName)
                        .kretaFont(isEmphasized ? KretaType.blockTitleLarge : KretaType.blockTitle)
                        .lineLimit(isEmphasized ? 2 : 1)
                    LessonDetailText(detail: LessonDetail(lesson))
                        .foregroundStyle(Palette.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(KretaDate.timeString(lesson.start))
                        .kretaFont(KretaType.time)
                    Text(KretaDate.timeString(lesson.end))
                        .kretaFont(KretaType.time.weight(400))
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.leading, 10)
            }
            switch mode {
            case .running: RunningFooter(lesson: lesson)
            case .upNext: UpNextFooter(lesson: lesson)
            case .upcoming, .past: EmptyView()
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 15)
        .background(Subjects.color(lesson.name), in: LessonBlock.shape)
        .accessibilityElement(children: .combine)
    }
}

/// The live part of the running lesson: time left, and how far the lesson has got.
private struct RunningFooter: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(timerInterval: lesson.start...lesson.end, countsDown: true)
                    .kretaFont(KretaType.countdown)
                    .monospacedDigit()
                Text(L10n.left)
                    .kretaFont(KretaType.strong)
                    .foregroundStyle(Palette.inkMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.left))
            .accessibilityValue(Text(timerInterval: lesson.start...lesson.end, countsDown: true))
            TimerBar(interval: lesson.start...lesson.end)
        }
        .padding(.top, 16)
    }
}

private struct UpNextFooter: View {
    let lesson: Lesson

    var body: some View {
        TimelineView(MinuteSteps(target: lesson.start)) { context in
            Text(Formatting.startsIn(minutes: Formatting.minutesRoundedUp(lesson.start.timeIntervalSince(context.date))))
                .kretaFont(KretaType.strong)
                .padding(.leading, LessonBlock.numberWidth)
                .padding(.top, 12)
        }
    }
}

/// A lesson that is over: one quiet line, its colour given back.
private struct PastRow: View {
    let lesson: Lesson

    var body: some View {
        HStack(spacing: 0) {
            Text(Formatting.number(lesson))
                .kretaFont(KretaType.strong)
                .foregroundStyle(Palette.textFaint)
                .frame(width: LessonBlock.numberWidth, alignment: .leading)
            Text(lesson.displayName)
                .kretaFont(KretaType.small)
                .strikethrough(lesson.isCancelled)
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Formatting.timeRange(lesson))
                .kretaFont(KretaType.time.weight(400))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

/// The slot of a lesson that will not be held: an outline with the name crossed out.
private struct CancelledBlock: View {
    let lesson: Lesson

    var body: some View {
        HStack(spacing: 0) {
            Text(Formatting.number(lesson))
                .kretaFont(KretaType.number)
                .foregroundStyle(Palette.textFaint)
                .frame(width: LessonBlock.numberWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text(lesson.displayName)
                    .kretaFont(KretaType.blockTitle)
                    .strikethrough()
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
                Text(Formatting.timeRange(lesson))
                    .kretaFont(KretaType.small)
                    .foregroundStyle(Palette.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.lessonCancelled)
                .kretaFont(KretaType.button)
                .foregroundStyle(Palette.danger)
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 15)
        .overlay(DashedOutline())
        .accessibilityElement(children: .combine)
    }
}
