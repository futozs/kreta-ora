import KretaKit
import SwiftUI

@main
struct KretaOraWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .task { model.start() }
        }
    }
}

struct WatchRootView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        if let schedule = model.schedule {
            TimelineView(.everyMinute) { context in
                TabView {
                    WatchNowView(summary: StatusSummary(schedule: schedule, now: context.date))
                        .containerBackground(Color.board.gradient, for: .tabView)
                    WatchDayView(day: schedule.focusDay(at: context.date), now: context.date)
                        .containerBackground(Color.boardDeep.gradient, for: .tabView)
                }
                .tabViewStyle(.verticalPage)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(.chalkYellow)
                Text("Jelentkezz be a Kréta Óra appban a telefonodon.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

/// First page: the lesson that matters and the countdown, readable at a glance.
private struct WatchNowView: View {
    let summary: StatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: summary.label)
            if let lesson = summary.lesson {
                Text(lesson.displayName)
                    .font(.lessonTitle(.title3))
                    .foregroundStyle(.chalk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Countdown(summary: summary)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.chalkYellow)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
                LessonDetail(lesson: lesson)
                if let following = summary.following {
                    Text("Utána: \(following.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.chalkDim)
                        .lineLimit(1)
                }
            } else {
                Text("Nincs több órád a következő napokban.")
                    .font(.headline)
                    .foregroundStyle(.chalk)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
    }
}

/// Second page: the whole day as a list.
private struct WatchDayView: View {
    let day: DaySummary?
    let now: Date

    var body: some View {
        if let day, !day.lessons.isEmpty {
            List {
                Section {
                    ForEach(day.lessons) { lesson in
                        BoardLessonRow(lesson: lesson, isCurrent: lesson.isActive && lesson.contains(now))
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(ChangeFormatter.dayLabel(day.day, relativeTo: now))
                        .foregroundStyle(.chalkYellow)
                }
            }
            .listStyle(.plain)
        } else {
            Text("Nincs megjeleníthető nap.")
                .font(.footnote)
                .foregroundStyle(.chalkDim)
        }
    }
}
