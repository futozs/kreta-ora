import KretaKit
import SwiftUI

/// What the strip needs to know about one day.
struct StripDay: Hashable {
    let date: Date
    /// A lesson of this day that is still ahead has been cancelled.
    let hasCancellation: Bool
}

/// The week of the selected day, one cell per day, on a floating glass bar.
/// The selected day sits on a solid chalk-yellow disc, today wears a ring,
/// and a red dot warns of a cancelled lesson before the day is even opened.
struct WeekStrip: View {
    let days: [StripDay]
    let selected: Date
    let today: Date
    let onSelect: (Date) -> Void

    @Namespace private var disc

    private static let letters = ["H", "K", "Sze", "Cs", "P", "Szo", "V"]

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    cell(day)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .animation(.snappy(duration: 0.28), value: selected)
    }

    private func cell(_ day: StripDay) -> some View {
        let isSelected = day.date == selected
        let isToday = day.date == today
        return Button { onSelect(day.date) } label: {
            VStack(spacing: 6) {
                Text(Self.letters[KretaDate.weekdayIndex(day.date)])
                    .kretaFont(KretaType.strong, scalesWithDynamicType: false)
                    .foregroundStyle(isSelected ? Palette.text : Palette.textFaint)
                Text("\(KretaDate.dayOfMonth(day.date))")
                    .kretaFont(KretaType.blockTitle, scalesWithDynamicType: false)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Palette.ink : Palette.text)
                    .frame(width: 46, height: 46)
                    .background {
                        if isSelected {
                            Circle()
                                .fill(Palette.accent)
                                .matchedGeometryEffect(id: "disc", in: disc)
                        } else if isToday {
                            Circle().strokeBorder(Palette.text, lineWidth: 1.5)
                        }
                    }
                Circle()
                    .fill(day.hasCancellation ? Palette.danger : .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(KretaDate.weekdayName(day.date)), \(KretaDate.shortDate(day.date))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
