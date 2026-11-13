import KretaKit
import SwiftUI

/// Who is signed in, how fresh the timetable is, the live lesson switch, and the way out.
struct AccountSheet: View {
    let account: Account?
    let syncedAt: Date?
    let onRefresh: () -> Void
    let onSignOut: () -> Void

    @State private var isLiveOn = LiveLessonController.shared.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(account?.displayName ?? "")
                    .kretaFont(KretaType.headline)
                    .foregroundStyle(Palette.text)
                Text(account?.institutionCode ?? "")
                    .kretaFont(KretaType.small)
                    .foregroundStyle(Palette.textDim)
                    .padding(.top, 4)
                if let syncedAt {
                    Text(L10n.syncedAt(
                        ChangeFormatter.dayLabel(syncedAt, relativeTo: Date()).lowercased(),
                        KretaDate.timeString(syncedAt)
                    ))
                    .kretaFont(KretaType.small)
                    .foregroundStyle(Palette.textDim)
                    .padding(.top, 18)
                }
                liveSwitch
                    .padding(.top, 22)
                actions
                    .padding(.top, 16)
                Text(L10n.accountNote)
                    .kretaFont(KretaType.small)
                    .foregroundStyle(Palette.textFaint)
                    .padding(.top, 22)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Turns the school-day Live Activity on or off.
    private var liveSwitch: some View {
        Toggle(isOn: $isLiveOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.liveToggleTitle)
                    .kretaFont(KretaType.strong)
                    .foregroundStyle(Palette.text)
                Text(L10n.liveToggleBody)
                    .kretaFont(KretaType.small)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .tint(Palette.accent)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sensoryFeedback(.selection, trigger: isLiveOn)
        .onChange(of: isLiveOn) { _, isOn in
            LiveLessonController.shared.setEnabled(isOn)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onRefresh) {
                Text(L10n.refresh)
                    .kretaFont(KretaType.button)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.glass)
            Button(action: onSignOut) {
                Text(L10n.signOut)
                    .kretaFont(KretaType.button)
                    .foregroundStyle(Palette.danger)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .contentShape(Capsule())
            }
            .buttonStyle(.pressable)
        }
    }
}
