import SwiftUI

/// A tap target that gives slightly under the finger and ticks the haptic
/// engine. Used instead of a highlight, which would wash over the colour blocks.
struct PressableStyle: ButtonStyle {
    private static let pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Self.pressedScale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed) { _, isPressed in isPressed }
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// A flat pill that fills with the elapsed part of an interval. A custom
/// progress style receives no fraction from a timer-driven `ProgressView`,
/// so the app's own bar keeps time with a timeline instead; widgets and the
/// lock screen use the system's timer bar (`WidgetTimerBar`).
struct TimerBar: View {
    let interval: ClosedRange<Date>
    var height: CGFloat = 8
    var fill: Color = Palette.ink
    var track: Color = Palette.ink.opacity(0.16)

    private static let step: TimeInterval = 2

    var body: some View {
        TimelineView(.periodic(from: interval.lowerBound, by: Self.step)) { context in
            ProgressView(value: fraction(at: context.date))
                .progressViewStyle(PillProgressStyle(height: height, fill: fill, track: track))
                .animation(.linear(duration: Self.step), value: context.date)
        }
    }

    private func fraction(at date: Date) -> Double {
        let total = max(interval.upperBound.timeIntervalSince(interval.lowerBound), 1)
        return min(max(date.timeIntervalSince(interval.lowerBound) / total, 0), 1)
    }
}

/// Draws a determinate progress as a flat pill. Timer-driven progress views
/// hand their fraction to the style as it changes.
struct PillProgressStyle: ProgressViewStyle {
    let height: CGFloat
    let fill: Color
    let track: Color

    func makeBody(configuration: Configuration) -> some View {
        let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)
        Capsule()
            .fill(track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(fill)
                        .frame(width: max(height, proxy.size.width * fraction))
                        .opacity(fraction > 0 ? 1 : 0)
                }
            }
            .accessibilityHidden(true)
    }
}

/// The dashed outline of a lesson that will not be held.
struct DashedOutline: View {
    var cornerRadius: CGFloat = 22
    var color: Color = Palette.textFaint
    var lineWidth: CGFloat = 1.5

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .inset(by: lineWidth / 2)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: [7, 6]))
    }
}
