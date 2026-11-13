import KretaKit
import SwiftUI

/// The timetable: one day per page, swiped sideways. The header names the day
/// on screen, the glass strip under it shows where that day sits in its week.
struct TimetableScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var selected: Date? = LaunchOptions.pageOffset.map {
        KretaDate.addingDays($0, to: KretaDate.startOfDay(Date()))
    }
    @State private var showsAccount = LaunchOptions.opensAccount
    @State private var offersLiveLesson = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showsAccount) {
            AccountSheet(
                account: model.account,
                syncedAt: model.snapshot?.syncedAt,
                onRefresh: { Task { await model.refresh() } },
                onSignOut: {
                    showsAccount = false
                    Task { await model.signOut() }
                }
            )
        }
        .onAppear { offersLiveLesson = LivePreferences.isOfferDue }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { offersLiveLesson = LivePreferences.isOfferDue }
        }
    }

    private func content(now: Date) -> some View {
        let today = KretaDate.startOfDay(now)
        let schedule = model.snapshot?.schedule
        let days = Self.days(snapshot: model.snapshot, today: today)
        let shown = selected.flatMap { days.contains($0) ? $0 : nil }
            ?? days[DayPlan.initialIndex(of: days, schedule: schedule, now: now)]

        return DayPager(
            days: days,
            selection: Binding(get: { shown }, set: { selected = $0 }),
            page: { day in
                DayPage(
                    day: day,
                    schedule: schedule,
                    now: now,
                    needsSignIn: model.needsSignIn,
                    offer: offer,
                    onRefresh: { await model.refresh() },
                    onSignInAgain: { model.signInAgain() }
                )
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                TimetableHeader(
                    day: shown,
                    today: today,
                    schedule: schedule,
                    initials: Formatting.initials(model.account?.displayName ?? ""),
                    isSyncing: model.isSyncing && model.snapshot == nil,
                    onAccount: { showsAccount = true }
                )
                WeekStrip(
                    days: DayPlan.week(of: shown, in: days).map {
                        StripDay(date: $0, hasCancellation: DayPlan.hasCancellationAhead(schedule, on: $0, now: now))
                    },
                    selected: shown,
                    today: today,
                    onSelect: { day in withAnimation(.snappy) { selected = day } }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .overlay(alignment: .bottom) {
            bottomLayer(showsToday: days.contains(today) && shown != today, today: today)
        }
    }

    private func bottomLayer(showsToday: Bool, today: Date) -> some View {
        VStack(spacing: 10) {
            if showsToday {
                Button {
                    withAnimation(.snappy) { selected = today }
                } label: {
                    Text(L10n.backToToday)
                        .kretaFont(KretaType.button)
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .sensoryFeedback(.selection, trigger: showsToday)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // A session problem already has its own note at the top of the day.
            MessageToast(text: model.needsSignIn ? nil : model.message, onDismiss: model.dismissMessage)
        }
        .padding(16)
        .animation(.snappy, value: showsToday)
    }

    private var offer: OfferNote? {
        guard offersLiveLesson, !model.needsSignIn else { return nil }
        return OfferNote(
            text: L10n.liveOfferBody,
            allow: L10n.liveOfferAllow,
            onAllow: {
                LiveLessonController.shared.setEnabled(true)
                withAnimation(.snappy) { offersLiveLesson = false }
            },
            onLater: {
                LivePreferences.dismissOffer()
                withAnimation(.snappy) { offersLiveLesson = false }
            }
        )
    }

    /// The pager's days, or the school week before the first timetable arrives.
    private static func days(snapshot: TimetableSnapshot?, today: Date) -> [Date] {
        let days = snapshot?.pagerDays() ?? []
        return days.isEmpty ? DayPlan.schoolWeek(of: today) : days
    }
}

/// Days side by side, one screen wide each, snapping page by page.
private struct DayPager<Page: View>: View {
    let days: [Date]
    @Binding var selection: Date
    @ViewBuilder let page: (Date) -> Page

    @State private var position: Date?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    page(day)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $position)
        .onAppear { position = selection }
        .onChange(of: position) { _, day in
            if let day, day != selection { selection = day }
        }
        .onChange(of: selection) { _, day in
            if position != day { withAnimation(.snappy) { position = day } }
        }
        .sensoryFeedback(.selection, trigger: position)
    }
}
