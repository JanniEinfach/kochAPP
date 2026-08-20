import Testing
@testable import CoreUnits

@Suite("Zutatenzeilen aus echten Rezepten")
struct IngredientLineParserTests {

    let parser = IngredientLineParser()

    // MARK: - Standardfaelle

    @Test("Menge, Einheit, Name")
    func plain() {
        let line = parser.parse("750 g Mehl")
        #expect(line.quantity.min == 750)
        #expect(line.quantity.unit == .gram)
        #expect(line.name == "Mehl")
        #expect(line.confidence >= 0.9)
    }

    @Test("Einheit klebt an der Zahl")
    func noSpaceBeforeUnit() {
        let line = parser.parse("500g Kartoffeln")
        #expect(line.quantity.min == 500)
        #expect(line.quantity.unit == .gram)
        #expect(line.name == "Kartoffeln")
    }

    @Test("Deutsches Dezimalkomma")
    func decimalComma() {
        let line = parser.parse("1,5 l Gemüsebrühe")
        #expect(line.quantity.min == 1.5)
        #expect(line.quantity.unit == .liter)
        #expect(line.name == "Gemüsebrühe")
    }

    // MARK: - Brueche

    @Test("Schraegstrich-Bruch")
    func slashFraction() {
        let line = parser.parse("1/2 TL Salz")
        #expect(line.quantity.min == 0.5)
        #expect(line.quantity.unit == .teaspoon)
        #expect(line.name == "Salz")
    }

    @Test("Unicode-Bruchzeichen")
    func vulgarFraction() {
        let line = parser.parse("½ Bund Petersilie")
        #expect(line.quantity.min == 0.5)
        #expect(line.quantity.unit == .bunch)
        #expect(line.name == "Petersilie")
    }

    @Test("Gemischter Bruch mit Leerzeichen")
    func mixedFraction() {
        let line = parser.parse("1 1/2 EL Zucker")
        #expect(line.quantity.min == 1.5)
        #expect(line.quantity.unit == .tablespoon)
        #expect(line.name == "Zucker")
    }

    // MARK: - Spannen

    @Test("Spanne mit Bindestrich")
    func hyphenRange() {
        let line = parser.parse("2-3 EL Olivenöl")
        #expect(line.quantity.min == 2)
        #expect(line.quantity.max == 3)
        #expect(line.quantity.isRange)
        #expect(line.quantity.representative == 2.5)
        #expect(line.name == "Olivenöl")
    }

    @Test("Spanne mit Halbgeviertstrich aus dem Buchsatz")
    func enDashRange() {
        let line = parser.parse("4–5 Kartoffeln")
        #expect(line.quantity.min == 4)
        #expect(line.quantity.max == 5)
        #expect(line.name == "Kartoffeln")
    }

    @Test("Spanne ausgeschrieben")
    func bisRange() {
        let line = parser.parse("2 bis 3 Zehen Knoblauch")
        #expect(line.quantity.min == 2)
        #expect(line.quantity.max == 3)
        #expect(line.quantity.unit == .clove)
        #expect(line.name == "Knoblauch")
    }

    // MARK: - Qualifier

    @Test("Gehaeufter Loeffel")
    func heaped() {
        let line = parser.parse("1 EL geh. Speisestärke")
        #expect(line.quantity.min == 1)
        #expect(line.quantity.unit == .tablespoon)
        #expect(line.qualifier == .heaped)
        #expect(line.name == "Speisestärke")
    }

    @Test("Gestrichener Loeffel")
    func level() {
        let line = parser.parse("1 TL gestr. Backpulver")
        #expect(line.qualifier == .level)
        #expect(line.name == "Backpulver")
    }

    @Test("Circa-Angabe vor der Zahl")
    func approximately() {
        let line = parser.parse("ca. 200 ml Sahne")
        #expect(line.qualifier == .approximately)
        #expect(line.quantity.min == 200)
        #expect(line.quantity.unit == .milliliter)
        #expect(line.name == "Sahne")
    }

    @Test("Nach Bedarf ohne Zahl gilt als vollstaendig")
    func toTaste() {
        let line = parser.parse("Salz n. B.")
        #expect(line.quantity.isEmpty)
        #expect(line.name == "Salz")
        // Keine Zahl ist hier korrekt, nicht unsicher.
        #expect(line.confidence >= 0.5)
    }

    @Test("Etwas Oel")
    func someOil() {
        let line = parser.parse("etwas Öl zum Braten")
        #expect(line.qualifier == .some)
        #expect(line.quantity.isEmpty)
        #expect(line.name == "Öl zum Braten")
    }

    // MARK: - Stueck- und Packungsmasse

    @Test("Packung")
    func package() {
        let line = parser.parse("1 Pck. Vanillezucker")
        #expect(line.quantity.min == 1)
        #expect(line.quantity.unit == .package)
        #expect(line.name == "Vanillezucker")
    }

    @Test("Prise")
    func pinch() {
        let line = parser.parse("1 Prise Muskatnuss")
        #expect(line.quantity.unit == .pinch)
        #expect(line.name == "Muskatnuss")
    }

    @Test("Zahl ohne Einheit ist Stueckware")
    func pieces() {
        let line = parser.parse("3 Eier")
        #expect(line.quantity.min == 3)
        #expect(line.quantity.unit == nil)
        #expect(line.name == "Eier")
    }

    @Test("Blatt Gelatine")
    func gelatine() {
        let line = parser.parse("6 Blatt Gelatine")
        #expect(line.quantity.min == 6)
        #expect(line.quantity.unit == .leaf)
        #expect(line.name == "Gelatine")
    }

    // MARK: - Zusaetze und Notizen

    @Test("Klammerzusatz wird zur Notiz")
    func parenthetical() {
        let line = parser.parse("200 g Mehl (Type 405)")
        #expect(line.quantity.min == 200)
        #expect(line.name == "Mehl")
        #expect(line.note == "Type 405")
    }

    @Test("Kommazusatz wird zur Notiz")
    func commaNote() {
        let line = parser.parse("2 Zwiebeln, fein gewürfelt")
        #expect(line.quantity.min == 2)
        #expect(line.name == "Zwiebeln")
        #expect(line.note == "fein gewürfelt")
    }

    @Test("Optional wird erkannt und aus dem Namen entfernt")
    func optionalMarker() {
        let line = parser.parse("50 g Walnüsse, optional")
        #expect(line.isOptional)
        #expect(line.name == "Walnüsse")
    }

    // MARK: - Zeilen ohne Menge

    @Test("Nur ein Name")
    func nameOnly() {
        let line = parser.parse("Salz und Pfeffer")
        #expect(line.quantity.isEmpty)
        #expect(line.name == "Salz und Pfeffer")
    }

    @Test("Leere Zeile hat Konfidenz null")
    func emptyLine() {
        let line = parser.parse("   ")
        #expect(line.name.isEmpty)
        #expect(line.confidence == 0)
    }

    // MARK: - Der Rohtext bleibt unangetastet

    @Test("rawText wird nie veraendert")
    func rawTextPreserved() {
        let input = "  1 1/2 EL geh. Zucker (fein)  "
        let line = parser.parse(input)
        #expect(line.rawText == input)
    }

    // MARK: - Typische OCR-Verstuemmelungen

    @Test("Geschuetztes Leerzeichen aus dem Scan")
    func nonBreakingSpace() {
        let line = parser.parse("250\u{00A0}g Butter")
        #expect(line.quantity.min == 250)
        #expect(line.quantity.unit == .gram)
        #expect(line.name == "Butter")
    }

    @Test("Grossschreibung der Einheit stoert nicht")
    func uppercaseUnit() {
        let line = parser.parse("100 ML Milch")
        #expect(line.quantity.unit == .milliliter)
        #expect(line.name == "Milch")
    }
}
