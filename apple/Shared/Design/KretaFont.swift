import CoreText
import SwiftUI
import Synchronization

// Bricolage Grotesque speaks: day names, lesson names, lesson numbers. Its
// ink traps and uneven widths read as drawn rather than generated. Hanken
// Grotesk does the reading work underneath and sets every clock, because its
// figures can be made the same width. Both are variable fonts registered
// through UIAppFonts; their axes are set the way the Android app sets them.

enum KretaFontFamily: Hashable, Sendable {
    /// Bricolage at optical size 72: the large cut, tighter and sharper.
    case bricolageDisplay
    /// Bricolage at optical size 22, for text sizes.
    case bricolageText
    case hanken

    fileprivate var postScriptName: String {
        switch self {
        case .bricolageDisplay, .bricolageText: "BricolageGrotesque-96ptExtraBold"
        case .hanken: "HankenGrotesk-Regular"
        }
    }

    fileprivate var opticalSize: CGFloat? {
        switch self {
        case .bricolageDisplay: 72
        case .bricolageText: 22
        case .hanken: nil
        }
    }
}

/// Builds CoreText fonts with explicit variation axes and caches them.
enum KretaFonts {
    private struct Key: Hashable {
        let family: KretaFontFamily
        let weight: CGFloat
        let size: CGFloat
        let isTabular: Bool
    }

    // Four-character axis tags as CoreText expects them.
    private static let weightAxis = 0x7767_6874 as NSNumber // 'wght'
    private static let opticalSizeAxis = 0x6F70_737A as NSNumber // 'opsz'

    private static let cache = Mutex<[Key: Font]>([:])

    static func font(_ family: KretaFontFamily, weight: CGFloat, size: CGFloat, isTabular: Bool = false) -> Font {
        let key = Key(family: family, weight: weight, size: (size * 2).rounded() / 2, isTabular: isTabular)
        if let cached = cache.withLock({ $0[key] }) { return cached }
        let font = Font(makeCTFont(key))
        cache.withLock { $0[key] = font }
        return font
    }

    private static func makeCTFont(_ key: Key) -> CTFont {
        var variations: [NSNumber: NSNumber] = [weightAxis: key.weight as NSNumber]
        if let opticalSize = key.family.opticalSize {
            variations[opticalSizeAxis] = opticalSize as NSNumber
        }
        var attributes: [CFString: Any] = [
            kCTFontNameAttribute: key.family.postScriptName,
            kCTFontVariationAttribute: variations,
        ]
        if key.isTabular {
            // Every digit the same width, so a ticking clock does not jitter.
            attributes[kCTFontFeatureSettingsAttribute] = [
                [kCTFontOpenTypeFeatureTag: "tnum", kCTFontOpenTypeFeatureValue: 1],
            ]
        }
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, key.size, nil)
    }
}

/// One step of the type scale. Sizes are points at the default text size and
/// grow with Dynamic Type, like Android's sp.
struct KretaTextStyle: Hashable, Sendable {
    let family: KretaFontFamily
    let weight: CGFloat
    let size: CGFloat
    let lineHeight: CGFloat
    var tracking: CGFloat = 0
    var isTabular = false

    func font(scale: CGFloat = 1) -> Font {
        KretaFonts.font(family, weight: weight, size: size * scale, isTabular: isTabular)
    }

    func weight(_ weight: CGFloat) -> KretaTextStyle {
        KretaTextStyle(
            family: family, weight: weight, size: size, lineHeight: lineHeight,
            tracking: tracking, isTabular: isTabular
        )
    }

    func size(_ size: CGFloat) -> KretaTextStyle {
        let ratio = size / self.size
        return KretaTextStyle(
            family: family, weight: weight, size: size, lineHeight: lineHeight * ratio,
            tracking: tracking * ratio, isTabular: isTabular
        )
    }
}

private struct KretaFontModifier: ViewModifier {
    let style: KretaTextStyle
    let scalesWithDynamicType: Bool
    /// 100 at the default text size; the ratio scales every style evenly.
    @ScaledMetric(relativeTo: .body) private var scaled: CGFloat = 100

    func body(content: Content) -> some View {
        let scale = scalesWithDynamicType ? scaled / 100 : 1
        content
            .font(style.font(scale: scale))
            .tracking(style.tracking * scale)
            .lineHeight(.exact(points: style.lineHeight * scale))
    }
}

extension View {
    /// Sets text in one of the app's styles: family, weight, size, tracking and line height.
    func kretaFont(_ style: KretaTextStyle, scalesWithDynamicType: Bool = true) -> some View {
        modifier(KretaFontModifier(style: style, scalesWithDynamicType: scalesWithDynamicType))
    }
}
