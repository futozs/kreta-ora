import SwiftUI

/// Blackboard and chalk: "kréta" means chalk, so the app looks like one.
/// A deep green board carries the surfaces that matter, chalk white carries
/// the text, and each chalk colour has exactly one meaning.
extension ShapeStyle where Self == Color {
    /// The blackboard.
    static var board: Color { Color(red: 0.086, green: 0.215, blue: 0.168) }
    /// The board's shadowed edge.
    static var boardDeep: Color { Color(red: 0.055, green: 0.145, blue: 0.115) }
    /// Primary text on the board.
    static var chalk: Color { Color(red: 0.965, green: 0.955, blue: 0.905) }
    /// Secondary text on the board.
    static var chalkDim: Color { Color(red: 0.965, green: 0.955, blue: 0.905).opacity(0.62) }
    /// Labels and the thing happening now.
    static var chalkYellow: Color { Color(red: 0.985, green: 0.825, blue: 0.365) }
    /// Cancelled.
    static var chalkRed: Color { Color(red: 0.975, green: 0.475, blue: 0.425) }
    /// Substituted or otherwise changed.
    static var chalkBlue: Color { Color(red: 0.565, green: 0.795, blue: 0.965) }
}

extension Font {
    /// Small tracked capitals above a headline.
    static var eyebrow: Font { .system(.caption2, design: .rounded, weight: .heavy) }
    /// Lesson names.
    static func lessonTitle(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .rounded, weight: .bold)
    }
}
