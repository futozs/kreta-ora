import Foundation

/// The ten subject colours, as 0xRRGGBB. Every one is light enough to carry
/// near-black text.
public enum SubjectSwatch: Int, CaseIterable, Codable, Hashable, Sendable {
    case tangerine, grass, teal, sky, cobalt, plum, rose, olive, sand, mint

    public var rgb: UInt32 {
        switch self {
        case .tangerine: 0xF59A3A
        case .grass: 0x6CC474
        case .teal: 0x3DBFAE
        case .sky: 0x62B4EE
        case .cobalt: 0x7B95F2
        case .plum: 0xC08BE0
        case .rose: 0xF088B2
        case .olive: 0xB7C55C
        case .sand: 0xD6B381
        case .mint: 0x8BDABD
        }
    }
}

/// Gives every subject its colour, the way a student colours a paper
/// timetable. Known subjects get a fixed colour so maths is always the same
/// blue; anything else gets a stable one from its name. The rules match the
/// Android app exactly, so a subject has the same colour on every device.
public enum SubjectPalette {
    /// The order of the hash fallback. Must stay in step with Android.
    static let fallback: [SubjectSwatch] = [
        .tangerine, .grass, .teal, .sky, .cobalt, .plum, .rose, .olive, .sand, .mint,
    ]

    /// Checked in order, so the specific keywords come before the general ones.
    static let known: [(keywords: [String], swatch: SubjectSwatch)] = [
        (["gyogytestneveles"], .mint),
        (["testneveles", "tesi", "sport"], .grass),
        (["matematika", "matek"], .cobalt),
        (["magyar", "irodalom", "nyelvtan"], .rose),
        (["szakmai angol"], .teal),
        (["angol", "nemet", "francia", "spanyol", "olasz", "latin", "idegen nyelv"], .plum),
        (["tortenelem", "allampolgar"], .sand),
        (["fizika"], .sky),
        (["kemia"], .olive),
        (["biologia", "termeszettudomany"], .grass),
        (["foldrajz"], .teal),
        (["informatika", "digitalis", "ikt", "programozas", "projekt", "halozat", "szoftver", "web"], .tangerine),
        (["osztalyfonoki", "kozossegi"], .olive),
        (["enek", "zene"], .rose),
        (["rajz", "vizualis", "muveszet"], .tangerine),
        (["etika", "hittan", "filozofia"], .sand),
    ]

    public static func swatch(for name: String) -> SubjectSwatch {
        let key = normalize(name)
        if let match = known.first(where: { entry in entry.keywords.contains { key.contains($0) } }) {
            return match.swatch
        }
        return fallback[fallbackIndex(for: key)]
    }

    /// Kotlin's `fold(0) { sum, c -> (sum * 31 + c.code) and 0x7FFFFFFF }`
    /// over UTF-16 units. Only the low 31 bits survive each step, so 64-bit
    /// arithmetic gives the same result as Kotlin's wrapping 32-bit one.
    static func fallbackIndex(for key: String) -> Int {
        let hash = key.utf16.reduce(0) { sum, unit in (sum * 31 + Int(unit)) & 0x7FFF_FFFF }
        return hash % fallback.count
    }

    /// Lower case without accents, so "Történelem" matches "tortenelem".
    static func normalize(_ text: String) -> String {
        let decomposed = text.lowercased().decomposedStringWithCanonicalMapping
        let kept = decomposed.unicodeScalars.filter { !(0x300...0x36F).contains($0.value) }
        return String(String.UnicodeScalarView(kept))
    }
}
