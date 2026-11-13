import KretaKit
import SwiftUI
import WidgetKit

/// The next lesson on the lock screen, the watch face and the Smart Stack.
/// These faces tint everything themselves, so colour is only a hint here.
struct NextLessonAccessoryView: View {
    let entry: TimetableEntry
    let family: WidgetFamily

    var body: some View {
        if let model = entry.nextLesson {
            switch family {
            case .accessoryCircular: Circular(model: model, now: entry.date)
            case .accessoryInline: Inline(model: model, now: entry.date)
            #if os(watchOS)
            case .accessoryCorner: Corner(model: model, now: entry.date)
            #endif
            default: Rectangular(model: model, now: entry.date)
            }
        } else {
            Text(entry.schedule == nil ? L10n.widgetSignedOut : L10n.nothingLeft)
                .kretaFont(KretaType.small, scalesWithDynamicType: false)
                .lineLimit(3)
        }
    }
}

/// Name, countdown and how far the lesson has got.
private struct Rectangular: View {
    let model: NextLessonModel
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Subjects.color(model.lesson.name))
                    .frame(width: 7, height: 7)
                    .widgetAccentable()
                Text([Formatting.number(model.lesson), model.lesson.displayName].filter { !$0.isEmpty }.joined(separator: " "))
                    .kretaFont(KretaType.blockTitle.size(15), scalesWithDynamicType: false)
                    .lineLimit(1)
            }
            WidgetCountdown(
                model: model,
                now: now,
                style: KretaType.countdown.size(24),
                labelStyle: KretaType.small.size(12),
                color: .primary,
                labelColor: .secondary
            )
            if model.phase == .running {
                WidgetTimerBar(interval: model.lesson.start...model.lesson.end, tint: .primary)
                    .widgetAccentable()
            } else if let room = model.lesson.room {
                Text(room)
                    .kretaFont(KretaType.small.size(12), scalesWithDynamicType: false)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A ring that fills as the lesson runs, the time left inside.
private struct Circular: View {
    let model: NextLessonModel
    let now: Date

    var body: some View {
        switch model.phase {
        case .running:
            ProgressView(timerInterval: model.lesson.start...model.lesson.end, countsDown: true) {
                Text(Formatting.number(model.lesson))
            } currentValueLabel: {
                Text(timerInterval: model.lesson.start...model.lesson.end, countsDown: true, showsHours: false)
                    .kretaFont(KretaType.time.size(12).weight(800), scalesWithDynamicType: false)
                    .monospacedDigit()
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
        case .soon:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(Formatting.number(model.lesson))
                        .kretaFont(KretaType.number.size(15), scalesWithDynamicType: false)
                    Text(timerInterval: min(now, model.lesson.start)...model.lesson.start, countsDown: true, showsHours: false)
                        .kretaFont(KretaType.time.size(12).weight(800), scalesWithDynamicType: false)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
            }
        case .later:
            ZStack {
                AccessoryWidgetBackground()
                Text(KretaDate.timeString(model.lesson.start))
                    .kretaFont(KretaType.time.size(15).weight(800), scalesWithDynamicType: false)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

/// "Fizika · 23:57"
private struct Inline: View {
    let model: NextLessonModel
    let now: Date

    var body: some View {
        switch model.phase {
        case .running:
            Text("\(model.lesson.displayName) · \(Text(timerInterval: model.lesson.start...model.lesson.end, countsDown: true))")
        case .soon:
            Text("\(model.lesson.displayName) · \(Text(timerInterval: min(now, model.lesson.start)...model.lesson.start, countsDown: true))")
        case .later:
            Text("\(model.lesson.displayName) · \(Formatting.dayWord(model.lesson.start, now: now)) \(KretaDate.timeString(model.lesson.start))")
        }
    }
}

#if os(watchOS)
/// The countdown in the corner, the lesson's progress along the bezel.
private struct Corner: View {
    let model: NextLessonModel
    let now: Date

    var body: some View {
        Group {
            switch model.phase {
            case .running:
                Text(timerInterval: model.lesson.start...model.lesson.end, countsDown: true, showsHours: false)
                    .monospacedDigit()
            case .soon:
                Text(timerInterval: min(now, model.lesson.start)...model.lesson.start, countsDown: true, showsHours: false)
                    .monospacedDigit()
            case .later:
                Text(KretaDate.timeString(model.lesson.start))
            }
        }
        .kretaFont(KretaType.time.size(16).weight(800), scalesWithDynamicType: false)
        .widgetCurvesContent()
        .widgetLabel {
            if model.phase == .running {
                ProgressView(timerInterval: model.lesson.start...model.lesson.end, countsDown: false) {
                    Text(model.lesson.displayName)
                }
                .tint(Subjects.color(model.lesson.name))
            } else {
                Text(model.lesson.displayName)
            }
        }
    }
}
#endif
