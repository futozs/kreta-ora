#if DEBUG
import KretaKit
import SwiftUI
import WidgetKit

/// Renders the widgets and the Live Activity at their real sizes inside the
/// app, so they can be checked in the simulator without a home screen.
/// Opened with the `-WidgetGallery` launch argument.
struct WidgetGallery: View {
    private let entry = TimetableEntry.sample
    private let soonEntry: TimetableEntry = {
        let now = Date()
        let schedule = DemoTimetable.snapshot(now: now).schedule
        // Twenty minutes before today's first lesson, to show the "múlva kezdődik" state.
        let next = schedule.firstLesson(on: now).map { $0.start.addingTimeInterval(-20 * 60) } ?? now
        return TimetableEntry(date: next, schedule: schedule)
    }()

    private static let small = CGSize(width: 170, height: 170)
    private static let medium = CGSize(width: 364, height: 170)
    private static let large = CGSize(width: 364, height: 382)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // `-DemoPage 1` shows the second half, which does not fit one screen.
                if LaunchOptions.pageOffset == 1 {
                    secondHalf
                } else {
                    firstHalf
                }
            }
            .padding(19)
        }
        .background(Color(rgb: 0x3A4A5C).ignoresSafeArea())
    }

    @ViewBuilder private var firstHalf: some View {
                HStack(spacing: 16) {
                    widget(.systemSmall, size: Self.small) { NextLessonHomeView(entry: entry, family: .systemSmall) }
                        background: { NextLessonHomeView.background(for: entry, family: .systemSmall) }
                    widget(.systemSmall, size: Self.small, margins: 16) { DayStartHomeView(entry: entry, family: .systemSmall) }
                        background: { Palette.surface }
                }
                widget(.systemMedium, size: Self.medium) { NextLessonHomeView(entry: entry, family: .systemMedium) }
                    background: { NextLessonHomeView.background(for: entry, family: .systemMedium) }
                widget(.systemLarge, size: Self.large) { NextLessonHomeView(entry: entry, family: .systemLarge) }
                    background: { NextLessonHomeView.background(for: entry, family: .systemLarge) }
    }

    @ViewBuilder private var secondHalf: some View {
                // The countdown ticks on the real clock, so this state only reads right before the first lesson.
                if soonEntry.date > Date() {
                    widget(.systemMedium, size: Self.medium) { NextLessonHomeView(entry: soonEntry, family: .systemMedium) }
                        background: { NextLessonHomeView.background(for: soonEntry, family: .systemMedium) }
                }
                widget(.systemMedium, size: Self.medium, margins: 16) { DayStartHomeView(entry: entry, family: .systemMedium) }
                    background: { Palette.surface }
                liveActivity
                accessories
    }

    private func widget<Content: View, Background: View>(
        _ family: WidgetFamily,
        size: CGSize,
        margins: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder background: () -> Background
    ) -> some View {
        content()
            .padding(margins)
            .frame(width: size.width, height: size.height)
            .background(background())
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var liveActivity: some View {
        let schedule = DemoTimetable.snapshot().schedule
        let state = LiveLessonAttributes.ContentState(lessons: schedule.lessons(on: Date()))
        return LiveLessonLockScreen(state: state, now: Date())
            .frame(width: 364)
            .background(Palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var accessories: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                NextLessonAccessoryView(entry: entry, family: .accessoryRectangular)
                    .frame(width: 172, height: 76)
                NextLessonAccessoryView(entry: entry, family: .accessoryCircular)
                    .frame(width: 76, height: 76)
            }
            DayStartAccessoryView(entry: entry)
                .frame(width: 172, height: 76)
        }
        .foregroundStyle(.white)
    }
}
#endif
