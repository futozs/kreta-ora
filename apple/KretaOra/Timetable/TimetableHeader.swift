import KretaKit
import SwiftUI

/// The day on screen named large, its date and shape under it, and the way
/// to the account on a glass circle.
struct TimetableHeader: View {
    let day: Date
    let today: Date
    let schedule: Schedule?
    let initials: String
    let isSyncing: Bool
    let onAccount: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.weekdayTitle(day))
                    .kretaFont(KretaType.dayTitle)
                    .foregroundStyle(Palette.text)
                    .contentTransition(.opacity)
                    .id(day)
                    .transition(.opacity)
                summaryLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: day)

            accountButton
                .padding(.top, 6)
        }
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    /// "Ma, november 13. · 8:00–14:10, 6 óra · 1 óra elmarad", the cancelled part in red.
    private var summaryLine: some View {
        let summary = schedule.flatMap { Formatting.summary($0, day: day) }
        let plain = [Formatting.dateLine(day, today: today), summary?.span]
            .compactMap { $0 }
            .joined(separator: Formatting.separator)
        // Non-breaking spaces keep "1 óra elmarad" together when the line wraps.
        let cancelled = summary?.cancelled.map { " ·\u{00A0}" + $0.replacingOccurrences(of: " ", with: "\u{00A0}") } ?? ""
        return Text("\(Text(plain))\(Text(cancelled).foregroundStyle(Palette.danger).font(KretaType.strong.font()))")
            .kretaFont(KretaType.small)
            .foregroundStyle(Palette.textDim)
    }

    private var accountButton: some View {
        Button(action: onAccount) {
            ZStack {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Palette.text)
                } else {
                    Text(initials)
                        .kretaFont(KretaType.strong, scalesWithDynamicType: false)
                        .foregroundStyle(Palette.text)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(L10n.account)
    }
}
