import KretaKit
import SwiftUI

/// One day of the pager: its lessons stacked as colour blocks, top to bottom
/// in the order they happen. Pulling down refreshes the timetable.
struct DayPage: View {
    let day: Date
    let schedule: Schedule?
    let now: Date
    let needsSignIn: Bool
    var offer: OfferNote?
    let onRefresh: () async -> Void
    let onSignInAgain: () -> Void

    private static let skeletonBlocks = 6

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if needsSignIn {
                    SignInAgainNote(onSignInAgain: onSignInAgain)
                }
                if let offer {
                    offer
                }
                ForEach(schedule?.events(on: day) ?? []) { event in
                    EventNote(event: event)
                }
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 132)
        }
        .scrollIndicators(.hidden)
        .refreshable { await onRefresh() }
    }

    @ViewBuilder private var content: some View {
        if let schedule {
            let rows = DayPlan.rows(schedule, day: day, now: now)
            if rows.isEmpty {
                EmptyDay(day: day, schedule: schedule)
            } else {
                ForEach(rows) { row in
                    switch row {
                    case .block(let lesson, let mode): LessonBlock(lesson: lesson, mode: mode)
                    case .gap(let minutes, _): GapNote(minutes: minutes)
                    }
                }
            }
        } else {
            ForEach(0..<Self.skeletonBlocks, id: \.self) { _ in SkeletonBlock() }
        }
    }
}
