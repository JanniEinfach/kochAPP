import SwiftUI
import CoreGraphics

/// Schriftstufen.
///
/// Zwei Familien mit klarer Aufgabenteilung: Rezepttitel und Schrittfliesstext
/// laufen in einer Serifenschrift, weil sie gelesen und nicht bedient werden.
/// Alles Bedienbare laeuft serifenlos.
///
/// Alle Stufen sind an Dynamic Type gebunden. Wer die Systemschrift groesser
/// stellt, hat einen Grund dafuer, und in einer Kueche gilt das doppelt.
public enum Typography {

    // MARK: - Rezeptwelt, Serife

    public static func recipeTitle() -> Font {
        .system(.largeTitle, design: .serif, weight: .semibold)
    }

    public static func recipeSubtitle() -> Font {
        .system(.title3, design: .serif, weight: .regular)
    }

    /// Schritttext in der normalen Detailansicht.
    public static func stepBody() -> Font {
        .system(.body, design: .serif)
    }

    // MARK: - Bedienelemente, serifenlos

    public static func sectionHeader() -> Font {
        .system(.headline, design: .default, weight: .semibold)
    }

    public static func body() -> Font {
        .system(.body)
    }

    public static func callout() -> Font {
        .system(.callout)
    }

    public static func caption() -> Font {
        .system(.caption)
    }

    /// Mengenangaben. Tabellenziffern, damit Zahlen in einer Liste
    /// untereinander stehen und nicht tanzen.
    public static func quantity() -> Font {
        .system(.body, design: .default, weight: .medium)
            .monospacedDigit()
    }

    // MARK: - Stufen aus dem Gestaltungs-Handoff

    /// Titel einer Listenzeile. Im Handoff 17/21 in Halbfett.
    /// Gebunden an `.body`, damit die Zeile mit der Systemschrift mitwächst.
    public static func listTitle() -> Font {
        .system(.body, design: .default, weight: .medium)
    }

    /// Zweite Zeile einer Listenzeile: Herkunft, Datum, Zusatz.
    public static func listSubtitle() -> Font {
        .system(.caption, design: .default, weight: .medium)
    }

    /// Titel innerhalb einer Karte. Serife, weil er gelesen wird.
    ///
    /// Die negative Laufweite kommt aus dem Handoff und ist bei Serifen in
    /// dieser Größe nötig: New York setzt von Haus aus etwas weit, und ohne
    /// die Korrektur zerfällt eine zweizeilige Überschrift optisch.
    public static func cardTitle() -> Font {
        .system(.title3, design: .serif, weight: .semibold)
    }

    public static let cardTitleTracking: CGFloat = -0.2

    /// Kleine Versalzeile über einer Gruppe, etwa "FACHBEGRIFF DES TAGES".
    /// Wird immer zusammen mit `overlineTracking` und Großbuchstaben gesetzt --
    /// gesperrte Versalien ohne Laufweite kleben zusammen.
    public static func overline() -> Font {
        .system(.caption2, design: .default, weight: .semibold)
    }

    public static let overlineTracking: CGFloat = 0.9

    /// Beschriftung einer Handlung innerhalb einer Zeile, etwa "Karte öffnen".
    public static func actionLabel() -> Font {
        .system(.subheadline, design: .default, weight: .semibold)
    }

    /// Kennzahl in einer Zeile: Portionen, Dauer, Menge.
    /// Serife mit Tabellenziffern, damit Zahlen untereinander stehen.
    public static func metric() -> Font {
        .system(.subheadline, design: .serif, weight: .semibold)
            .monospacedDigit()
    }

    // MARK: - Kochmodus

    /// Der Kochmodus wird aus zwei Metern Abstand gelesen, mit fettigen
    /// Fingern und schlechtem Licht. Deshalb eine eigene, deutlich groessere
    /// Skala statt einer hochskalierten Detailansicht.
    public enum Kitchen {
        public static func stepNumber() -> Font {
            .system(size: 22, weight: .semibold, design: .default)
        }

        public static func stepBody() -> Font {
            .system(size: 34, weight: .regular, design: .serif)
        }

        public static func ingredient() -> Font {
            .system(size: 24, weight: .regular)
                .monospacedDigit()
        }

        public static func timer() -> Font {
            .system(size: 48, weight: .medium, design: .rounded)
                .monospacedDigit()
        }
    }
}
