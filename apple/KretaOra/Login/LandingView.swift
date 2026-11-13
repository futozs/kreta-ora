import KretaKit
import SwiftUI

/// The first screen. It asks the question the app answers, shows three blocks
/// of a real-looking morning so the idea lands without a word of explanation,
/// and offers one button. Nothing to type: the school is picked on KRÉTA's page.
struct LandingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SampleMorning()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            Text(L10n.landingHeadline)
                .kretaFont(KretaType.display)
                .foregroundStyle(Palette.text)
                .padding(.top, 34)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.landingBody)
                .kretaFont(KretaType.body)
                .foregroundStyle(Palette.textDim)
                .padding(.top, 14)
                .padding(.trailing, 24)
            if let message = model.message {
                Text(message)
                    .kretaFont(KretaType.small)
                    .foregroundStyle(Palette.danger)
                    .padding(.top, 18)
            }
            AccentPill(title: L10n.landingButton, isFullWidth: true, verticalPadding: 20) {
                model.startLogin()
            }
            .disabled(model.isSigningIn)
            .padding(.top, 26)
            Text(L10n.landingPrivacy)
                .kretaFont(KretaType.small)
                .foregroundStyle(Palette.textFaint)
                .padding(.top, 16)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 22)
        .background(Palette.background.ignoresSafeArea())
    }
}

/// A slice of a school morning in the app's own blocks: one lesson running,
/// one cancelled, one still to come. They rise into place once, one after
/// another, and then stay put.
private struct SampleMorning: View {
    @State private var lessons = SampleMorning.make(now: Date())
    @State private var hasRisen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let entrance = 0.42
    private static let stagger = 0.09
    private static let rise: CGFloat = 28

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(lessons.enumerated()), id: \.element.lesson.id) { index, item in
                LessonBlock(lesson: item.lesson, mode: item.mode)
                    .opacity(hasRisen ? 1 : 0)
                    .offset(y: hasRisen ? 0 : Self.rise)
                    .animation(
                        .timingCurve(0.4, 0, 0.2, 1, duration: Self.entrance).delay(Double(index) * Self.stagger),
                        value: hasRisen
                    )
            }
        }
        // Decoration: a screen reader should not read invented lessons as the user's timetable.
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                hasRisen = true
            } else {
                withAnimation { hasRisen = true }
            }
        }
    }

    /// Three invented lessons around the current moment, so the sample shows a live countdown.
    private static func make(now: Date) -> [(lesson: Lesson, mode: BlockMode)] {
        let running = now.addingTimeInterval(-21 * 60)
        // Keep the sample inside one day even when the app is opened around midnight.
        let fitsToday = KretaDate.isSameDay(running, now.addingTimeInterval(3 * 3600))
        let anchor = fitsToday ? running : KretaDate.startOfDay(now).addingTimeInterval(9 * 3600)
        func lesson(_ id: String, _ offset: TimeInterval, _ name: String, _ index: Int, _ room: String, cancelled: Bool = false) -> Lesson {
            let start = anchor.addingTimeInterval(offset * 60)
            return Lesson(
                id: id, start: start, end: start.addingTimeInterval(45 * 60), name: name,
                index: index, room: room, isCancelled: cancelled
            )
        }
        return [
            (lesson("sample-2", 0, "Matematika", 2, "204"), fitsToday ? .running : .upcoming),
            (lesson("sample-3", 55, "Fizika", 3, "Labor", cancelled: true), .upcoming),
            (lesson("sample-4", 110, "Angol nyelv", 4, "21"), .upcoming),
        ]
    }
}
