import SwiftUI

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
