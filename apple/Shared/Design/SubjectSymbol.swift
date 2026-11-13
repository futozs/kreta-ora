import Foundation

/// An SF Symbol per subject, for the places with room for a sign but not a
/// word: the Dynamic Island, the lock screen, the watch. Matched by keyword
/// like the subject colours, so "Matematika" and "matek" share one.
enum SubjectSymbol {
    /// Checked in order, so the specific keywords come before the general ones.
    private static let known: [(keywords: [String], symbol: String)] = [
        (["gyogytestneveles"], "figure.flexibility"),
        (["testneveles", "tesi", "sport"], "figure.run"),
        (["matematika", "matek"], "function"),
        (["fizika"], "atom"),
        (["kemia"], "flask"),
        (["biologia", "termeszettudomany"], "leaf"),
        (["foldrajz"], "globe.europe.africa"),
        (["tortenelem", "allampolgar"], "building.columns"),
        (["magyar", "irodalom", "nyelvtan"], "book"),
        (["angol", "nemet", "francia", "spanyol", "olasz", "latin", "idegen nyelv"], "character.bubble"),
        (["adatbazis"], "cylinder.split.1x2"),
        (["web", "programozas", "szoftver", "alkalmazas"], "chevron.left.forwardslash.chevron.right"),
        (["informatika", "digitalis", "ikt", "projekt", "halozat"], "laptopcomputer"),
        (["osztalyfonoki", "kozossegi"], "person.3"),
        (["enek", "zene"], "music.note"),
        (["rajz", "vizualis", "muveszet"], "paintpalette"),
        (["etika", "hittan", "filozofia"], "heart.text.square"),
        (["fejleszto", "korrepetalas", "felzarkoztat"], "lightbulb"),
    ]

    private static let fallback = "book.closed"

    static func name(for subject: String) -> String {
        let key = subject.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "hu_HU"))
            .lowercased()
        return known.first { entry in entry.keywords.contains { key.contains($0) } }?.symbol ?? fallback
    }
}
