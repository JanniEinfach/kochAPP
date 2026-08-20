import Foundation

/// Eine Mengenangabe aus einer Rezeptzeile.
///
/// `min`/`max` bilden Spannen ab ("2-3 EL"). Bei einer exakten Angabe sind
/// beide gleich. `nil` bedeutet: keine Zahl vorhanden ("Salz", "etwas Öl").
///
/// Warum `Double` und nicht `Decimal`: Mengen sind Naeherungen und werden
/// gerundet angezeigt. Geldbetraege dagegen laufen ueberall als Int in Cent,
/// dort waere Double falsch.
public struct Quantity: Sendable, Hashable, Codable {
    public var min: Double?
    public var max: Double?
    public var unit: MeasurementUnit?

    public init(min: Double? = nil, max: Double? = nil, unit: MeasurementUnit? = nil) {
        self.min = min
        self.max = max
        self.unit = unit
    }

    public static func exact(_ value: Double, _ unit: MeasurementUnit? = nil) -> Quantity {
        Quantity(min: value, max: value, unit: unit)
    }

    public static func range(_ lower: Double, _ upper: Double, _ unit: MeasurementUnit? = nil) -> Quantity {
        Quantity(min: lower, max: upper, unit: unit)
    }

    public static let none = Quantity()

    public var isEmpty: Bool { min == nil && max == nil }
    public var isRange: Bool {
        guard let min, let max else { return false }
        return min != max
    }

    /// Repraesentativer Wert fuer Berechnungen. Bei einer Spanne die Mitte --
    /// wer "2-3 EL" schreibt, meint in der Kalkulation ungefaehr 2,5.
    public var representative: Double? {
        switch (min, max) {
        case let (lower?, upper?): (lower + upper) / 2
        case let (lower?, nil): lower
        case let (nil, upper?): upper
        case (nil, nil): nil
        }
    }
}

/// Zusatz, der die Menge praezisiert, ohne sie zu veraendern.
public enum QuantityQualifier: String, Sendable, Hashable, CaseIterable, Codable {
    case heaped        // geh. / gehäuft
    case level         // gestr. / gestrichen
    case approximately // ca. / etwa
    case toTaste       // n. B. / nach Bedarf / nach Geschmack
    case some          // etwas
    case generous      // reichlich

    public var label: String {
        switch self {
        case .heaped: "gehäuft"
        case .level: "gestrichen"
        case .approximately: "ca."
        case .toTaste: "nach Bedarf"
        case .some: "etwas"
        case .generous: "reichlich"
        }
    }

    /// Ob der Zusatz bedeutet, dass gar keine Zahl zu erwarten ist.
    public var impliesNoNumber: Bool {
        switch self {
        case .toTaste, .some, .generous: true
        case .heaped, .level, .approximately: false
        }
    }
}
