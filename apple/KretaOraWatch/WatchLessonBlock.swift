import KretaKit
import SwiftUI

/// The phone's lesson block, cut to the wrist: the same colours and modes,
/// fewer words.
struct WatchLessonBlock: View {
    let lesson: Lesson
    let mode: BlockMode

    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    private static let numberWidth: CGFloat = 24

    var body: some View {
        if mode == .past {
            past
        } else if lesson.isCancelled {
            cancelled
        } else {
            filled
        }
    }

    private var filled: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Formatting.number(lesson))
                    .kretaFont(KretaType.number.size(16))
                    .frame(width: Self.numberWidth, alignment: .leading)
                Text(lesson.displayName)
                    .kretaFont(mode == .upcoming ? KretaType.blockTitle.size(15) : KretaType.blockTitleLarge.size(18))
                    .lineLimit(mode == .upcoming ? 1 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if mode == .upcoming {
                    Text(KretaDate.timeString(lesson.start))
                        .kretaFont(KretaType.time.size(13))
                }
            }
            if mode != .upcoming {
                LessonDetailText(detail: LessonDetail(lesson, withTime: true), style: KretaType.small.size(11.5))
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.leading, Self.numberWidth)
            } else if lesson.isSubstituted || lesson.hasTest {
                LessonDetailText(detail: LessonDetail(lesson), style: KretaType.small.size(11.5))
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.leading, Self.numberWidth)
            }
            footer
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, mode == .upcoming ? 8 : 10)
        .background(Subjects.color(lesson.name), in: Self.shape)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var footer: some View {
        switch mode {
        case .running:
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(timerInterval: lesson.start...lesson.end, countsDown: true)
                    .kretaFont(KretaType.countdown.size(30))
                    .monospacedDigit()
                Text(L10n.left)
                    .kretaFont(KretaType.strong.size(11.5))
                    .foregroundStyle(Palette.inkMuted)
            }
            .padding(.top, 4)
            TimerBar(interval: lesson.start...lesson.end, height: 6)
                .padding(.top, 2)
        case .upNext:
            TimelineView(MinuteSteps(target: lesson.start)) { context in
                Text(Formatting.startsIn(minutes: Formatting.minutesRoundedUp(lesson.start.timeIntervalSince(context.date))))
                    .kretaFont(KretaType.strong.size(12))
            }
            .padding(.leading, Self.numberWidth)
            .padding(.top, 2)
        case .upcoming, .past:
            EmptyView()
        }
    }

    private var past: some View {
        HStack(spacing: 0) {
            Text(Formatting.number(lesson))
                .kretaFont(KretaType.strong.size(12))
                .foregroundStyle(Palette.textFaint)
                .frame(width: Self.numberWidth, alignment: .leading)
            Text(lesson.displayName)
                .kretaFont(KretaType.small.size(12))
                .strikethrough(lesson.isCancelled)
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(KretaDate.timeString(lesson.start))
                .kretaFont(KretaType.time.size(12).weight(400))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var cancelled: some View {
        HStack(spacing: 0) {
            Text(Formatting.number(lesson))
                .kretaFont(KretaType.number.size(16))
                .foregroundStyle(Palette.textFaint)
                .frame(width: Self.numberWidth, alignment: .leading)
            Text(lesson.displayName)
                .kretaFont(KretaType.blockTitle.size(15))
                .strikethrough()
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.lessonCancelled)
                .kretaFont(KretaType.button.size(12))
                .foregroundStyle(Palette.danger)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .overlay(DashedOutline(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
