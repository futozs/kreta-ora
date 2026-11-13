import KretaKit
import SwiftUI

// Board-styled pieces shared by the app, the widgets and the watch.

/// "8:00–8:45"
func timeRange(_ lesson: Lesson) -> String {
    "\(KretaDate.timeString(lesson.start))–\(KretaDate.timeString(lesson.end))"
}

/// Live countdown to the bell or to the start of the next lesson.
struct Countdown: View {
    let summary: StatusSummary

    var body: some View {
        if let target = summary.countdownTo {
            // Spelled out as a key so the timer stays a live Text, not a string.
            let timer = Text(target, style: .timer)
            let text: LocalizedStringKey = summary.isInLesson ? "még \(timer)" : "\(timer) múlva"
            Text(text).monospacedDigit()
        }
    }
}

/// Tracked capitals above a headline on the board.
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(1.2)
            .foregroundStyle(.chalkYellow)
            .lineLimit(1)
    }
}

/// The second line under a lesson name: time, room, and who substitutes.
struct LessonDetail: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(timeRange(lesson)).monospacedDigit()
                if let room = lesson.room {
                    Text(room)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.chalk.opacity(0.14), in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.chalk)
            if let substitute = lesson.substituteTeacher {
                Label(substitute, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.chalkBlue)
                    .lineLimit(1)
            }
        }
    }
}

/// One line of a day list on the board.
struct BoardLessonRow: View {
    let lesson: Lesson
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(lesson.index.map { "\($0)." } ?? "·")
                .font(.caption.weight(.heavy))
                .foregroundStyle(isCurrent ? .chalkYellow : .chalkDim)
                .frame(width: 18, alignment: .trailing)
            Text(KretaDate.timeString(lesson.start))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.chalkDim)
                .frame(width: 38, alignment: .leading)
            Text(lesson.displayName)
                .font(.subheadline.weight(isCurrent ? .bold : .regular))
                .strikethrough(lesson.isCancelled)
                .foregroundStyle(nameColor)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let room = lesson.room, !lesson.isCancelled {
                Text(room)
                    .font(.caption)
                    .foregroundStyle(.chalkDim)
                    .lineLimit(1)
            }
        }
    }

    private var nameColor: Color {
        if lesson.isCancelled { return .chalkRed }
        return lesson.isSubstituted ? .chalkBlue : .chalk
    }
}

/// Shown when there is nothing to draw: signed out, or no lessons ahead.
struct EmptyBoard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Kréta Óra")
            Text(text)
                .font(.lessonTitle(.headline))
                .foregroundStyle(.chalk)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
