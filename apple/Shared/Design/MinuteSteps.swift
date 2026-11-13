import SwiftUI

/// Redraws a "N perc múlva" text exactly when its rounded-up minute count
/// changes: on every whole minute before `target`, counted from `target`.
struct MinuteSteps: TimelineSchedule {
    let target: Date

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next: Date? = startDate
        return AnyIterator {
            guard let current = next else { return nil }
            let remaining = target.timeIntervalSince(current)
            if remaining <= 0 {
                next = nil
            } else {
                // The next moment the remaining time crosses a whole minute.
                let steps = (remaining / 60).rounded(.up) - 1
                next = target.addingTimeInterval(-steps * 60)
            }
            return current
        }
    }
}
