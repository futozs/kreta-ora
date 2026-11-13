import KretaKit
import SwiftUI

/// The days side by side, swiped like on the phone. The crown scrolls the
/// day; a glass button in the toolbar jumps back to today.
struct WatchDayPager: View {
    let snapshot: TimetableSnapshot

    @State private var selected: Date?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let today = KretaDate.startOfDay(now)
            let schedule = snapshot.schedule
            let days = snapshot.pagerDays().isEmpty ? DayPlan.schoolWeek(of: today) : snapshot.pagerDays()
            let initial = days[DayPlan.initialIndex(of: days, schedule: schedule, now: now)]
            let shown = selected.flatMap { days.contains($0) ? $0 : nil } ?? initial

            NavigationStack {
                TabView(selection: Binding(get: { shown }, set: { selected = $0 })) {
                    ForEach(days, id: \.self) { day in
                        WatchDayPage(day: day, today: today, schedule: schedule, now: now)
                            .tag(day)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .containerBackground(Palette.background, for: .navigation)
                .toolbar {
                    if days.contains(today), shown != today {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation(.snappy) { selected = today }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .accessibilityLabel(L10n.backToToday)
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: shown)
            }
        }
    }
}

/// One day: its name, its date and shape, then the lessons as blocks.
private struct WatchDayPage: View {
    let day: Date
    let today: Date
    let schedule: Schedule
    let now: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                header
                ForEach(schedule.events(on: day)) { event in
                    Text(event.displayName)
                        .kretaFont(KretaType.strong.size(12))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outline, lineWidth: 1.5))
                }
                let rows = DayPlan.rows(schedule, day: day, now: now)
                if rows.isEmpty {
                    empty
                } else {
                    ForEach(rows) { row in
                        switch row {
                        case .block(let lesson, let mode): WatchLessonBlock(lesson: lesson, mode: mode)
                        case .gap(let minutes, _):
                            Text(L10n.gap(minutes))
                                .kretaFont(KretaType.small.size(12))
                                .foregroundStyle(Palette.textFaint)
                                .padding(.leading, 30)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Formatting.weekdayTitle(day))
                .kretaFont(KretaType.dayTitle.size(28))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            let summary = Formatting.summary(schedule, day: day)
            Text("\(Text(Formatting.dateLine(day, today: today)))\(Text(summary?.cancelled.map { Formatting.separator + $0 } ?? "").foregroundStyle(Palette.danger))")
                .kretaFont(KretaType.small.size(12))
                .foregroundStyle(Palette.textDim)
                .lineLimit(2)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.emptyTitle)
                .kretaFont(KretaType.headline.size(20))
                .foregroundStyle(Palette.text)
            if let next = schedule.firstLessonOfNextSchoolDay(after: day) {
                Text(L10n.emptyNext(KretaDate.weekdayName(next.start), KretaDate.timeString(next.start), next.displayName))
                    .kretaFont(KretaType.small.size(13))
                    .foregroundStyle(Palette.textDim)
            } else {
                Text(L10n.emptyBody)
                    .kretaFont(KretaType.small.size(13))
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}
