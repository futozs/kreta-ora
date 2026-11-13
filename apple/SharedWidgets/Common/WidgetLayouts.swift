import SwiftUI

// The system's widget renderer crashes on GeometryReader: it lays widgets
// out with unbounded proposals, a reader's child placed from such a size
// trips an assertion, and the crash takes every widget on the screen (and in
// a stack) down with it. These layouts do the same jobs and fall back to a
// sane size instead.

/// Two views side by side, the first taking a fixed share of the width.
struct SplitLayout: Layout {
    var ratio: CGFloat
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: finite(proposal.width, or: 320), height: finite(proposal.height, or: 150))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let available = max(bounds.width - spacing * CGFloat(max(subviews.count - 1, 0)), 0)
        let first = (available * ratio).rounded()
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = index == 0 ? first : max(available - first, 0)
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }
}

/// Lays each child along the width at the share of a span it was given with
/// `spanShare(start:length:)`, as a timeline draws events.
struct SpanLayout: Layout {
    var height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: finite(proposal.width, or: 200), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let share = subview[SpanShareKey.self]
            let width = max(bounds.width * share.length, 0)
            subview.place(
                at: CGPoint(x: bounds.minX + bounds.width * share.start, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
        }
    }
}

struct SpanShare {
    var start: CGFloat = 0
    var length: CGFloat = 0
}

private struct SpanShareKey: LayoutValueKey {
    static let defaultValue = SpanShare()
}

extension View {
    /// Where this child sits in a `SpanLayout`, both values as a share of the width.
    func spanShare(start: CGFloat, length: CGFloat) -> some View {
        layoutValue(key: SpanShareKey.self, value: SpanShare(start: clampedShare(start), length: clampedShare(length)))
    }
}

private func clampedShare(_ value: CGFloat) -> CGFloat {
    value.isFinite ? min(max(value, 0), 1) : 0
}

private func finite(_ value: CGFloat?, or fallback: CGFloat) -> CGFloat {
    guard let value, value.isFinite, value >= 0 else { return fallback }
    return value
}
