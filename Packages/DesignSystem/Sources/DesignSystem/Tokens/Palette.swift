import SwiftUI

/// Farbwelt der App.
///
/// Gestalterische Grundentscheidung: die App hat zwei Haelften, und die sollen
/// sich anfuehlen wie zwei Raeume im selben Haus.
///
///   Kochbuch  -- warm, papiernah. Es geht um abfotografierte Zettel,
///                Familienhandschrift, Kuechenlicht. Grundton ist ein warmes
///                Off-White, kein reines Weiss.
///   Lernkueche -- kuehl, sachlich. Petrol statt Terrakotta. Lernen soll sich
///                nach Werkbank anfuehlen, nicht nach Kochbuch.
///
/// Kein automatischer Dunkelmodus als Standardlook: die App wird bei Tageslicht
/// in einer Kueche benutzt. Der Dunkelmodus existiert und ist gepflegt, ist aber
/// die Variante, nicht die Absicht.
public enum Palette {

    // MARK: - Grundflaechen

    /// Hintergrund der App. Warmes Papier, nicht Weiss.
    public static let surface = adaptive(
        light: Color(red: 0.98, green: 0.972, blue: 0.957),
        dark:  Color(red: 0.086, green: 0.082, blue: 0.078)
    )

    /// Erhöhte Flaeche: Karten, Blaetter, Bottom Sheets.
    public static let surfaceRaised = adaptive(
        light: Color(red: 1.0, green: 0.996, blue: 0.988),
        dark:  Color(red: 0.129, green: 0.122, blue: 0.114)
    )

    /// Vertiefte Flaeche: Eingabefelder, Zutatenblock.
    public static let surfaceSunken = adaptive(
        light: Color(red: 0.949, green: 0.937, blue: 0.914),
        dark:  Color(red: 0.055, green: 0.051, blue: 0.047)
    )

    // MARK: - Text

    public static let textPrimary = adaptive(
        light: Color(red: 0.114, green: 0.098, blue: 0.078),
        dark:  Color(red: 0.957, green: 0.949, blue: 0.933)
    )

    public static let textSecondary = adaptive(
        light: Color(red: 0.376, green: 0.345, blue: 0.302),
        dark:  Color(red: 0.678, green: 0.659, blue: 0.627)
    )

    /// Nur fuer wirklich nachrangige Angaben. Erfuellt bei 13 pt noch AA.
    public static let textTertiary = adaptive(
        light: Color(red: 0.525, green: 0.494, blue: 0.447),
        dark:  Color(red: 0.545, green: 0.529, blue: 0.502)
    )

    public static let separator = adaptive(
        light: Color(red: 0.878, green: 0.859, blue: 0.827),
        dark:  Color(red: 0.208, green: 0.196, blue: 0.184)
    )

    // MARK: - Kochbuchwelt

    /// Terrakotta. Handlungsfarbe im Rezeptteil.
    public static let accent = adaptive(
        light: Color(red: 0.769, green: 0.325, blue: 0.180),
        dark:  Color(red: 0.878, green: 0.451, blue: 0.302)
    )

    public static let accentSoft = adaptive(
        light: Color(red: 0.973, green: 0.910, blue: 0.878),
        dark:  Color(red: 0.239, green: 0.145, blue: 0.110)
    )

    // MARK: - Lernwelt

    /// Petrol. Handlungsfarbe im Lernteil.
    public static let learning = adaptive(
        light: Color(red: 0.106, green: 0.396, blue: 0.435),
        dark:  Color(red: 0.365, green: 0.686, blue: 0.722)
    )

    public static let learningSoft = adaptive(
        light: Color(red: 0.886, green: 0.937, blue: 0.941),
        dark:  Color(red: 0.078, green: 0.180, blue: 0.196)
    )

    // MARK: - Zustaende

    public static let success = adaptive(
        light: Color(red: 0.220, green: 0.475, blue: 0.259),
        dark:  Color(red: 0.435, green: 0.706, blue: 0.478)
    )

    public static let warning = adaptive(
        light: Color(red: 0.706, green: 0.502, blue: 0.098),
        dark:  Color(red: 0.898, green: 0.694, blue: 0.259)
    )

    public static let danger = adaptive(
        light: Color(red: 0.667, green: 0.180, blue: 0.157),
        dark:  Color(red: 0.882, green: 0.400, blue: 0.365)
    )

    /// Markiert eine Angabe, die der Scan unsicher gelesen hat.
    /// Bewusst nicht rot: es ist keine Fehlermeldung, sondern eine Bitte
    /// um einen zweiten Blick.
    public static let needsReview = warning

    // MARK: -

    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
