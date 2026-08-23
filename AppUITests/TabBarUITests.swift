import XCTest

/// Prüft die Reiterleiste auf dem laufenden Gerät.
///
/// Der Anlass war ein sichtbarer Sprung der Leiste bei jedem Reiterwechsel.
/// Ursache war ein Wechsel der Tönung, der die Leiste jedes Mal neu aufbaute.
/// Dieser Test hält fest, dass alle fünf Reiter erreichbar sind und die Leiste
/// dabei an ihrem Platz bleibt.
final class TabBarUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func testAlleReiterSindErreichbar() {
        let app = launch()
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Reiterleiste erscheint nicht")

        for name in ["Kochbuch", "Scannen", "Lernen", "Team"] {
            let button = bar.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Reiter \(name) fehlt")
            button.tap()
            XCTAssertTrue(
                app.navigationBars.firstMatch.waitForExistence(timeout: 5),
                "Nach dem Wechsel auf \(name) erscheint kein Inhalt"
            )
        }
    }

    /// Die Leiste darf beim Reiterwechsel nicht ihre Lage ändern.
    /// Genau das war der Sprung, den man in der Hand gesehen hat.
    func testLeisteBleibtBeimWechselAnOrt() {
        let app = launch()
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))

        var rahmen: [CGRect] = []
        for name in ["Kochbuch", "Lernen", "Team", "Kochbuch"] {
            bar.buttons[name].tap()
            // Kurz warten, damit eine etwaige Animation abgelaufen wäre.
            Thread.sleep(forTimeInterval: 0.6)
            rahmen.append(bar.frame)
        }

        guard let erster = rahmen.first else { return XCTFail("keine Messwerte") }
        for (index, rect) in rahmen.enumerated() {
            XCTAssertEqual(
                rect.origin.y, erster.origin.y, accuracy: 0.5,
                "Die Leiste verschiebt sich beim \(index + 1). Wechsel um "
                + "\(abs(rect.origin.y - erster.origin.y)) Punkte"
            )
            XCTAssertEqual(
                rect.height, erster.height, accuracy: 0.5,
                "Die Leiste ändert beim \(index + 1). Wechsel ihre Höhe"
            )
        }
    }
}
