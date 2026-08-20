import Foundation
import Testing
@testable import CoreUnits

@Suite("Portionsskalierung")
struct PortionScalerTests {

    let scaler = PortionScaler()
    let de = Locale(identifier: "de_DE")

    @Test("Hochrechnen auf Gaestezahl")
    func scaleUp() {
        let scaled = scaler.scale(.exact(250, .gram), from: 4, to: 27)
        #expect(scaled.min == 1687.5)
        #expect(scaled.unit == .gram)
    }

    @Test("Herunterrechnen")
    func scaleDown() {
        let scaled = scaler.scale(.exact(1000, .gram), from: 8, to: 2)
        #expect(scaled.min == 250)
    }

    @Test("Gleiche Portionszahl laesst die Menge unberuehrt")
    func noChange() {
        let original = Quantity.exact(333, .gram)
        #expect(scaler.scale(original, from: 4, to: 4) == original)
    }

    @Test("Ungueltige Portionszahlen aendern nichts")
    func invalidServings() {
        let original = Quantity.exact(100, .gram)
        #expect(scaler.scale(original, from: 0, to: 4) == original)
        #expect(scaler.scale(original, from: 4, to: 0) == original)
    }

    @Test("Spannen werden an beiden Enden skaliert")
    func rangeScaling() {
        let scaled = scaler.scale(.range(2, 3, .tablespoon), from: 4, to: 8)
        #expect(scaled.min == 4)
        #expect(scaled.max == 6)
    }

    @Test("Zutaten ohne Menge bleiben ohne Menge")
    func emptyStaysEmpty() {
        #expect(scaler.scale(.none, from: 4, to: 20).isEmpty)
    }

    // MARK: - Einheitenaufstieg

    @Test("Gramm steigen ab 1000 auf Kilogramm")
    func gramToKilogram() {
        let result = scaler.scaleAndNormalize(.exact(250, .gram), from: 4, to: 27)
        #expect(result.unit == .kilogram)
        let value = try! #require(result.representative)
        #expect(abs(value - 1.6875) < 0.0001)
    }

    @Test("Milliliter steigen ab 1000 auf Liter")
    func milliliterToLiter() {
        let result = scaler.scaleAndNormalize(.exact(500, .milliliter), from: 2, to: 6)
        #expect(result.unit == .liter)
        #expect(result.representative == 1.5)
    }

    @Test("Kilogramm unter eins fallen auf Gramm zurueck")
    func kilogramToGram() {
        let result = scaler.scaleAndNormalize(.exact(1, .kilogram), from: 8, to: 2)
        #expect(result.unit == .gram)
        #expect(result.representative == 250)
    }

    @Test("Loeffelmasse steigen nicht auf")
    func spoonsStay() {
        let result = scaler.scaleAndNormalize(.exact(2, .tablespoon), from: 1, to: 600)
        #expect(result.unit == .tablespoon)
    }

    // MARK: - Darstellung

    @Test("Grosse Massen werden auf 5 gerundet")
    func bulkRounding() {
        // 1687,5 / 5 = 337,5 -> 338 -> 1690. In der Kueche wiegt niemand 1687,5 g ab.
        #expect(scaler.formatNumber(1687.5, unit: .gram, locale: de) == "1690")
        #expect(scaler.formatNumber(247.3, unit: .gram, locale: de) == "245")
    }

    @Test("Mittlere Werte werden ganzzahlig")
    func mediumRounding() {
        #expect(scaler.formatNumber(13.4, unit: .piece, locale: de) == "13")
        #expect(scaler.formatNumber(13.6, unit: .piece, locale: de) == "14")
    }

    @Test("Kleine Werte bekommen eine Nachkommastelle mit deutschem Komma")
    func smallDecimals() {
        #expect(scaler.formatNumber(1.5, unit: .liter, locale: de) == "1,5")
        #expect(scaler.formatNumber(2.0, unit: .liter, locale: de) == "2")
    }

    @Test("Bruchteile werden als Bruch gezeigt")
    func fractions() {
        #expect(scaler.nearestFraction(0.5) == "½")
        #expect(scaler.nearestFraction(0.25) == "¼")
        #expect(scaler.nearestFraction(0.3333) == "⅓")
        #expect(scaler.nearestFraction(0.42) == nil)
    }

    @Test("Vollstaendige Formatierung mit Einheit")
    func fullFormat() {
        #expect(scaler.format(.exact(500, .gram), locale: de) == "500 g")
        #expect(scaler.format(.exact(1, .clove), locale: de) == "1 Zehe")
        #expect(scaler.format(.exact(3, .clove), locale: de) == "3 Zehen")
        #expect(scaler.format(.range(2, 3, .tablespoon), locale: de) == "2–3 EL")
    }

    @Test("Leere Menge formatiert zu leerem String")
    func emptyFormat() {
        #expect(scaler.format(.none, locale: de).isEmpty)
    }

    @Test("Der Praxisfall: 4 Portionen auf 27 Gaeste")
    func realWorldCase() {
        let scaled = scaler.scaleAndNormalize(.exact(250, .gram), from: 4, to: 27)
        #expect(scaler.format(scaled, locale: de) == "1,7 kg")
    }
}
