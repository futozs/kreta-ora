import KretaKit
import SwiftUI

/// "35 perc szünet" between two lessons far enough apart.
struct GapNote: View {
    let minutes: Int

    var body: some View {
        Text(L10n.gap(minutes))
            .kretaFont(KretaType.small)
            .foregroundStyle(Palette.textFaint)
            .padding(.leading, 56)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A school-year event of the day, for example a holiday.
struct EventNote: View {
    let event: Lesson

    var body: some View {
        Text(event.displayName)
            .kretaFont(KretaType.strong)
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.outline, lineWidth: 1.5)
            )
    }
}

struct EmptyDay: View {
    let day: Date
    let schedule: Schedule?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.emptyTitle)
                .kretaFont(KretaType.dayTitle)
                .foregroundStyle(Palette.text)
            Text(bodyText)
                .kretaFont(KretaType.body)
                .foregroundStyle(Palette.textDim)
        }
        .padding(.horizontal, 8)
        .padding(.top, 36)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyText: String {
        guard let next = schedule?.firstLessonOfNextSchoolDay(after: day) else { return L10n.emptyBody }
        return L10n.emptyNext(KretaDate.weekdayName(next.start), KretaDate.timeString(next.start), next.displayName)
    }
}

/// A placeholder block while the first timetable is on its way.
struct SkeletonBlock: View {
    @State private var isDim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LessonBlock.shape
            .fill(Palette.surface)
            .frame(height: 74)
            .opacity(isDim ? 0.45 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { isDim = true }
            }
            .accessibilityHidden(true)
    }
}

/// The stored session stopped working. The timetable below is the last one saved.
struct SignInAgainNote: View {
    let onSignInAgain: () -> Void

    var body: some View {
        NoteCard {
            Text(L10n.errorSessionExpired)
                .kretaFont(KretaType.body)
                .foregroundStyle(Palette.text)
            AccentPill(title: L10n.signInAgain, action: onSignInAgain)
        }
    }
}

/// A one-time suggestion at the top of the day: a sentence, a yes and a not now.
struct OfferNote: View {
    let text: String
    let allow: String
    let onAllow: () -> Void
    let onLater: () -> Void

    var body: some View {
        NoteCard(spacing: 14) {
            Text(text)
                .kretaFont(KretaType.body)
                .foregroundStyle(Palette.text)
            HStack(spacing: 8) {
                AccentPill(title: allow, action: onAllow)
                Button(action: onLater) {
                    Text(L10n.later)
                        .kretaFont(KretaType.button)
                        .foregroundStyle(Palette.textDim)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

private struct NoteCard<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: LessonBlock.shape)
            .padding(.bottom, 6)
    }
}

/// The chalk-yellow pill: the one primary action of a place.
struct AccentPill: View {
    let title: String
    var isFullWidth = false
    var verticalPadding: CGFloat = 12
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .kretaFont(KretaType.button)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .background(Palette.accent, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
    }
}
