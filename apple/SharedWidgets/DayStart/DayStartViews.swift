import KretaKit
import SwiftUI
import WidgetKit

/// The time is the widget, set as large as the space allows. Under it: the
/// first lesson, and the whole day as a bar of subject colours.
struct DayStartHomeView: View {
    let entry: TimetableEntry
    let family: WidgetFamily

    var body: some View {
        if entry.schedule == nil {
            WidgetNote(title: L10n.appName, message: L10n.widgetSignedOut)
        } else if let card = entry.dayStart {
            content(card)
        } else {
            WidgetNote(title: L10n.widgetDayStartName, message: L10n.nothingLeft)
        }
    }

    private func content(_ card: DayStartCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.label)
                .kretaFont(KretaType.body.weight(500), scalesWithDynamicType: false)
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
            Text(card.time)
                .kretaFont(KretaType.countdown.size(timeSize), scalesWithDynamicType: false)
                .tracking(-timeSize * 0.04)
                .monospacedDigit()
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 4)
            Text(card.title)
                .kretaFont(KretaType.blockTitle.size(18).weight(800), scalesWithDynamicType: false)
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            if isTall, let detail = card.detail {
                Text(detail)
                    .kretaFont(KretaType.small, scalesWithDynamicType: false)
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            DayBar(lessons: card.lessons)
                .padding(.top, 10)
            footer(card)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func footer(_ card: DayStartCard) -> some View {
        if let alert = card.alert {
            Text(alert)
                .kretaFont(KretaType.strong, scalesWithDynamicType: false)
                .foregroundStyle(Palette.danger)
                .lineLimit(1)
        } else if let footnote = card.footnote {
            Text(footnote)
                .kretaFont(KretaType.small.weight(500), scalesWithDynamicType: false)
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
        }
    }

    // Sized by family rather than measured: the widget renderer crashes on
    // GeometryReader. These are the sizes the Android rule (height left over,
    // and the width "88:88" needs) gives inside the standard margins.
    private var isTall: Bool {
        #if os(iOS)
        family == .systemLarge || family == .systemExtraLarge
        #else
        false
        #endif
    }

    private var timeSize: CGFloat {
        isTall ? 120 : 46
    }
}

struct DayStartAccessoryView: View {
    let entry: TimetableEntry

    var body: some View {
        if let card = entry.dayStart {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(card.time)
                        .kretaFont(KretaType.countdown.size(26), scalesWithDynamicType: false)
                        .monospacedDigit()
                    Text(card.label)
                        .kretaFont(KretaType.small.size(12), scalesWithDynamicType: false)
                        .foregroundStyle(.secondary)
                }
                Text(card.title)
                    .kretaFont(KretaType.small.size(12).weight(700), scalesWithDynamicType: false)
                    .lineLimit(1)
                DayBar(lessons: card.lessons, height: 6, outline: .secondary)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(entry.schedule == nil ? L10n.widgetSignedOut : L10n.nothingLeft)
                .kretaFont(KretaType.small, scalesWithDynamicType: false)
        }
    }
}
