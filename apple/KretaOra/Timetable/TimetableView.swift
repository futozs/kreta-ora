import KretaKit
import SwiftUI

/// The main screen: what is happening now on the board, anything that
/// changed, then the coming days.
struct TimetableView: View {
    @Environment(AppModel.self) private var model
    let account: Account
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            // The minute tick keeps "now" and the day list honest while open.
            TimelineView(.everyMinute) { context in
                content(now: context.date)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Órarend")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Label("Beállítások", systemImage: "person.crop.circle")
                    }
                }
            }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $showsSettings) {
                SettingsView(account: account)
            }
        }
    }

    private func content(now: Date) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }
                if let schedule = model.schedule {
                    NowCard(summary: StatusSummary(schedule: schedule, now: now))
                    if !model.recentChanges.isEmpty {
                        ChangesSection(changes: model.recentChanges, now: now)
                    }
                    let days = schedule.upcomingDays(from: now)
                    if days.isEmpty {
                        Text("A következő hetekre nincs óra a KRÉTA-ban.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(days, id: \.day) { day in
                        DaySection(day: day, now: now)
                    }
                } else if model.isSyncing {
                    ProgressView("Órarend letöltése…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
}

/// The blackboard at the top: the lesson that matters, with a live countdown.
private struct NowCard: View {
    let summary: StatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: summary.label)
                Spacer()
                Countdown(summary: summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.chalkYellow)
            }
            if let lesson = summary.lesson {
                Text(lesson.displayName)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.chalk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                LessonDetail(lesson: lesson)
                if let teacher = lesson.teacher, !lesson.isSubstituted {
                    Text(teacher)
                        .font(.caption)
                        .foregroundStyle(.chalkDim)
                }
                if let following = summary.following {
                    Divider().overlay(.chalk.opacity(0.2)).padding(.vertical, 6)
                    HStack(spacing: 8) {
                        Text("UTÁNA")
                            .font(.eyebrow)
                            .tracking(1.2)
                            .foregroundStyle(.chalkDim)
                        Text(following.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.chalk)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text([KretaDate.timeString(following.start), following.room].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.chalkDim)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Mára és a következő hetekre nincs több órád.")
                    .font(.lessonTitle(.headline))
                    .foregroundStyle(.chalk)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.board, .boardDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color(red: 0.55, green: 0.40, blue: 0.24), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

/// What the last syncs found, so a change is visible even if the banner was
/// swiped away.
private struct ChangesSection: View {
    let changes: [TimetableChange]
    let now: Date

    var body: some View {
        let formatter = ChangeFormatter(now: now)
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Változások", detail: "\(changes.count)")
            ForEach(changes) { change in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(change.kind))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint(change.kind))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatter.title(for: change))
                            .font(.subheadline.weight(.semibold))
                        Text(formatter.body(for: change))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(tint(change.kind).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func icon(_ kind: TimetableChange.Kind) -> String {
        switch kind {
        case .cancelled, .removed: "xmark.circle.fill"
        case .restored, .added: "plus.circle.fill"
        case .teacher: "arrow.triangle.2.circlepath.circle.fill"
        case .time: "clock.fill"
        case .room: "door.left.hand.open"
        }
    }

    private func tint(_ kind: TimetableChange.Kind) -> Color {
        switch kind {
        case .cancelled, .removed: .red
        case .restored, .added: .green
        case .teacher, .time, .room: .blue
        }
    }
}

private struct DaySection: View {
    let day: DaySummary
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(
                text: ChangeFormatter.dayLabel(day.day, relativeTo: now).capitalizedSentence,
                detail: day.span
            )
            VStack(spacing: 0) {
                ForEach(day.lessons) { lesson in
                    LessonRow(lesson: lesson, isCurrent: lesson.isActive && lesson.contains(now), isOver: lesson.end <= now)
                    if lesson.id != day.lessons.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct LessonRow: View {
    let lesson: Lesson
    let isCurrent: Bool
    let isOver: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(lesson.index.map { "\($0)" } ?? "·")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(isCurrent ? Color.board : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.displayName)
                    .font(.body.weight(isCurrent ? .bold : .medium))
                    .strikethrough(lesson.isCancelled)
                    .foregroundStyle(lesson.isCancelled ? Color.red : Color.primary)
                status
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeRange(lesson))
                    .font(.footnote.monospacedDigit())
                if let room = lesson.room, !lesson.isCancelled {
                    Text(room)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isCurrent ? Color.chalkYellow.opacity(0.22) : Color.clear)
        .opacity(isOver ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }

    /// The line under the name: what is unusual about this lesson, otherwise
    /// just the teacher.
    @ViewBuilder private var status: some View {
        if lesson.isCancelled {
            Text("Elmarad")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        } else if let substitute = lesson.substituteTeacher {
            Label("Helyettesít: \(substitute)", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .lineLimit(1)
        } else if lesson.hasTest {
            Label("Számonkérés", systemImage: "pencil.and.list.clipboard")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        } else if let teacher = lesson.teacher {
            Text(teacher)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct SectionTitle: View {
    let text: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "wifi.exclamationmark")
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension String {
    /// "péntek (nov. 20.)" → "Péntek (nov. 20.)"
    var capitalizedSentence: String {
        prefix(1).uppercased(with: Locale(identifier: "hu_HU")) + dropFirst()
    }
}
