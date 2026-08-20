import Testing
@testable import CoreUnits

@Suite("Zahlschreibweisen deutscher Rezepte")
struct NumberTokenizerTests {

    @Test("Ganze Zahlen", arguments: [
        ("1", 1.0), ("500", 500.0), ("0", 0.0), ("1000", 1000.0),
    ])
    func wholeNumbers(input: String, expected: Double) {
        #expect(NumberTokenizer.parse(input) == expected)
    }

    @Test("Deutsches Komma und englischer Punkt", arguments: [
        ("1,5", 1.5), ("0,25", 0.25), ("1.5", 1.5), ("12,75", 12.75),
    ])
    func decimals(input: String, expected: Double) {
        #expect(NumberTokenizer.parse(input) == expected)
    }

    @Test("Punkt als Tausendertrenner")
    func thousandsSeparator() {
        #expect(NumberTokenizer.parse("1.000") == 1000)
        #expect(NumberTokenizer.parse("1.500") == 1500)
        // Zwei Nachkommastellen sind kein Tausenderblock, also Dezimalpunkt.
        #expect(NumberTokenizer.parse("1.50") == 1.5)
    }

    @Test("Schraegstrich-Brueche", arguments: [
        ("1/2", 0.5), ("3/4", 0.75), ("1/4", 0.25), ("2/3", 2.0 / 3),
    ])
    func slashFractions(input: String, expected: Double) {
        let value = try! #require(NumberTokenizer.parse(input))
        #expect(abs(value - expected) < 0.0001)
    }

    @Test("Unicode-Bruchzeichen", arguments: [
        ("½", 0.5), ("¼", 0.25), ("¾", 0.75), ("⅓", 1.0 / 3),
    ])
    func vulgarFractions(input: String, expected: Double) {
        let value = try! #require(NumberTokenizer.parse(input))
        #expect(abs(value - expected) < 0.0001)
    }

    @Test("Ganzzahl mit angehaengtem Bruchzeichen")
    func mixedVulgar() {
        #expect(NumberTokenizer.parse("1½") == 1.5)
        #expect(NumberTokenizer.parse("2¼") == 2.25)
    }

    @Test("Zahlwoerter, aber nur eindeutige")
    func numberWords() {
        #expect(NumberTokenizer.parse("zwei") == 2)
        #expect(NumberTokenizer.parse("eine") == 1)
        #expect(NumberTokenizer.parse("halbe") == 0.5)
        // "ein" fehlt bewusst: "ein wenig Salz" ist keine Menge von 1.
        #expect(NumberTokenizer.parse("ein") == nil)
    }

    @Test("Keine Zahl bleibt keine Zahl", arguments: [
        "Salz", "Mehl", "", "  ", "n.B.", "Öl",
    ])
    func nonNumbers(input: String) {
        #expect(NumberTokenizer.parse(input) == nil)
    }

    @Test("Division durch Null ergibt kein Ergebnis")
    func divisionByZero() {
        #expect(NumberTokenizer.parse("1/0") == nil)
    }
}
