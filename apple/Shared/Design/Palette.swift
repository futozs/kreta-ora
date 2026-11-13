import KretaKit
import SwiftUI

// Direction: a hand-coloured timetable. The day is a stack of flat blocks,
// one solid colour per subject, on a warm near-black or a paper ground.
// Colour belongs to the lessons; the interface around them stays neutral and
// uses a single chalk yellow for "selected" and "now". No gradients, no
// glows, no blur: shape and fill carry the meaning. Liquid Glass is only the
// floating control layer above the content, never the content itself.

/// The app's own colours. They follow the system appearance on iPhone; the
/// watch is always dark.
enum Palette {
    static let background = Color.adaptive(dark: 0x111110, light: 0xF3F0E8)
    static let surface = Color.adaptive(dark: 0x1C1C1A, light: 0xFBF9F4)
    static let surfaceHigh = Color.adaptive(dark: 0x292926, light: 0xE6E2D7)
    static let outline = Color.adaptive(dark: 0x3B3A36, light: 0xCDC8BA)
    static let text = Color.adaptive(dark: 0xF3F0E7, light: 0x141413)
    static let textDim = Color.adaptive(dark: 0xABA79C, light: 0x5F5C54)
    static let textFaint = Color.adaptive(dark: 0x77746B, light: 0x8F8C83)
    /// Chalk yellow: the selected day, the primary button. Always a fill under `ink`, never text.
    static let accent = Color(rgb: 0xFFD60A)
    /// Cancelled.
    static let danger = Color.adaptive(dark: 0xFF6A55, light: 0xD63A27)
    /// Text on a subject colour and on the accent.
    static let ink = Color(rgb: 0x141413)
    /// Secondary text on a subject colour.
    static let inkMuted = Color(rgb: 0x141413).opacity(0.68)

    /// The outline of a cancelled segment in a widget's day bar.
    static let widgetOutline = Color.adaptive(dark: 0x5C5A53, light: 0xB9B4A6)
}

enum Subjects {
    /// The subject's colour, identical to the Android app for the same name.
    static func color(_ name: String) -> Color {
        color(SubjectPalette.swatch(for: name))
    }

    static func color(_ swatch: SubjectSwatch) -> Color {
        Color(rgb: swatch.rgb)
    }
}

extension Color {
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour that switches with the system appearance.
    static func adaptive(dark: UInt32, light: UInt32) -> Color {
        #if os(iOS)
        Color(UIColor { traits in
            UIColor(Color(rgb: traits.userInterfaceStyle == .light ? light : dark))
        })
        #else
        Color(rgb: dark)
        #endif
    }
}
