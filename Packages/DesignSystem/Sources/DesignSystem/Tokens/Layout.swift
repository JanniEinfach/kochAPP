import SwiftUI

/// Abstaende, Radien, Bewegung.
///
/// Der Rhythmus ist bewusst nicht gleichfoermig: Abstaende innerhalb einer
/// Gruppe sind eng, zwischen Gruppen deutlich weiter. Gleiche Polsterung
/// ueberall laesst jede Oberflaeche wie eine Vorlage aussehen.
public enum Spacing {
    /// Zwischen eng zusammengehoerenden Elementen, etwa Label und Wert.
    public static let hair: CGFloat = 4
    public static let tight: CGFloat = 8
    /// Standardabstand innerhalb einer Gruppe.
    public static let inner: CGFloat = 12
    /// Innenabstand von Karten und Blaettern.
    public static let card: CGFloat = 16
    /// Seitenrand.
    public static let margin: CGFloat = 20
    /// Zwischen zwei Gruppen.
    public static let group: CGFloat = 32
    /// Zwischen zwei Abschnitten.
    public static let section: CGFloat = 48
}

public enum Radius {
    public static let small: CGFloat = 6
    public static let card: CGFloat = 14
    public static let sheet: CGFloat = 24
    public static let pill: CGFloat = 999
}

public enum Motion {
    /// Rueckmeldung auf eine Beruehrung. Muss unter der Wahrnehmungsschwelle
    /// fuer Verzoegerung bleiben.
    public static let tap = Animation.easeOut(duration: 0.12)
    /// Standarduebergang.
    public static let standard = Animation.easeInOut(duration: 0.24)
    /// Blatt oeffnet sich.
    public static let sheet = Animation.spring(response: 0.38, dampingFraction: 0.86)

    /// Respektiert die Systemeinstellung fuer reduzierte Bewegung.
    /// Wer sie aktiviert hat, bekommt keine Animation, kein abgeschwaechtes.
    public static func respectingReduceMotion(
        _ animation: Animation,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// Mindestgroesse einer Trefferflaeche. Apple nennt 44 pt; im Kochmodus
/// gilt mehr, weil dort mit dem Handruecken oder feuchten Fingern getippt wird.
public enum HitTarget {
    public static let minimum: CGFloat = 44
    public static let kitchen: CGFloat = 64
}
