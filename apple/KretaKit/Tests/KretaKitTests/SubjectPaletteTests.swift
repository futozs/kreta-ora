import Testing
@testable import KretaKit

@Suite("Subject colours")
struct SubjectPaletteTests {
    @Test("known subjects get their fixed colour, accents and case ignored")
    func knownSubjects() {
        #expect(SubjectPalette.swatch(for: "Matematika") == .cobalt)
        #expect(SubjectPalette.swatch(for: "TÖRTÉNELEM") == .sand)
        #expect(SubjectPalette.swatch(for: "Kémia") == .olive)
        #expect(SubjectPalette.swatch(for: "ének-zene") == .rose)
    }

    @Test("specific keywords win over general ones")
    func order() {
        #expect(SubjectPalette.swatch(for: "Gyógytestnevelés") == .mint)
        #expect(SubjectPalette.swatch(for: "Testnevelés") == .grass)
        #expect(SubjectPalette.swatch(for: "Szakmai angol") == .teal)
        #expect(SubjectPalette.swatch(for: "Angol nyelv") == .plum)
    }

    // Expected indices computed with the Kotlin rule:
    // fold(0) { sum, c -> (sum * 31 + c.code) and 0x7FFFFFFF } % 10
    // over the accent-stripped lower-case name.
    @Test("unknown subjects get the same colour as on Android", arguments: [
        ("Ügyvitel", SubjectSwatch.plum),
        ("Szakmai gyakorlat", .sand),
        ("Pénzügyi ismeretek", .tangerine),
        ("Gépírás", .sky),
        ("Dráma", .olive),
        ("Mozgóképkultúra", .cobalt),
        ("Őrség", .cobalt),
    ])
    func fallbackMatchesAndroid(name: String, expected: SubjectSwatch) {
        #expect(SubjectPalette.swatch(for: name) == expected)
    }

    @Test("names are lower-cased and stripped of accents")
    func normalize() {
        #expect(SubjectPalette.normalize("Hon- és Népismeret") == "hon- es nepismeret")
        #expect(SubjectPalette.normalize("Őrség") == "orseg")
    }
}
