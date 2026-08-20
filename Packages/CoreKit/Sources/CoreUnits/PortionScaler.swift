import Foundation

/// Rechnet Mengen auf eine andere Portionszahl um und formatiert sie so,
/// wie es in einer Kueche lesbar ist.
///
/// Der schwierige Teil ist nicht die Multiplikation, sondern die Darstellung.
/// "1687,5 g Mehl" ist rechnerisch richtig und praktisch unbrauchbar.
public struct PortionScaler: Sendable {

    public init() {}

    /// Skaliert linear. Bewusst ohne Sonderbehandlung fuer Gewuerze oder
    /// Backtriebmittel: die haengt an der Zutat und gehoert damit in die
    /// Zutatendomaene, nicht in die Mengenarithmetik.
    public func scale(_ quantity: Quantity, from base: Int, to target: Int) -> Quantity {
        guard base > 0, target > 0, base != target else { return quantity }
        let factor = Double(target) / Double(base)
        return Quantity(
            min: quantity.min.map { $0 * factor },
            max: quantity.max.map { $0 * factor },
            unit: quantity.unit
        )
    }

    /// Skaliert und steigt dabei bei Bedarf in die groessere Einheit auf:
    /// 1687,5 g werden zu 1,69 kg, 1500 ml zu 1,5 l.
    public func scaleAndNormalize(_ quantity: Quantity, from base: Int, to target: Int) -> Quantity {
        normalizeUnit(scale(quantity, from: base, to: target))
    }

    /// Wechselt in die naechstgroessere oder -kleinere Einheit, wenn der Wert
    /// dadurch besser lesbar wird.
    public func normalizeUnit(_ quantity: Quantity) -> Quantity {
        guard let unit = quantity.unit, let value = quantity.representative else { return quantity }

        switch unit {
        case .gram where value >= 1000:
            return convert(quantity, to: .kilogram, factor: 0.001)
        case .kilogram where value < 1:
            return convert(quantity, to: .gram, factor: 1000)
        case .milliliter where value >= 1000:
            return convert(quantity, to: .liter, factor: 0.001)
        case .liter where value < 1:
            return convert(quantity, to: .milliliter, factor: 1000)
        default:
            return quantity
        }
    }

    private func convert(_ quantity: Quantity, to unit: MeasurementUnit, factor: Double) -> Quantity {
        Quantity(
            min: quantity.min.map { $0 * factor },
            max: quantity.max.map { $0 * factor },
            unit: unit
        )
    }

    // MARK: - Darstellung

    /// Formatiert eine Menge fuer die Anzeige. Deutsche Schreibweise,
    /// Rundung nach Groessenordnung, Brueche bei kleinen Loeffelmengen.
    public func format(_ quantity: Quantity, locale: Locale = Locale(identifier: "de_DE")) -> String {
        guard !quantity.isEmpty else { return "" }

        let unitLabel: String? = quantity.unit.map { unit in
            let value = quantity.representative ?? 0
            return (value == 1) ? unit.symbol : unit.pluralSymbol
        }

        let numberPart: String
        if quantity.isRange, let lower = quantity.min, let upper = quantity.max {
            numberPart = "\(formatNumber(lower, unit: quantity.unit, locale: locale))"
                + "–\(formatNumber(upper, unit: quantity.unit, locale: locale))"
        } else if let value = quantity.representative {
            numberPart = formatNumber(value, unit: quantity.unit, locale: locale)
        } else {
            numberPart = ""
        }

        return [numberPart, unitLabel].compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Rundungsstrategie:
    ///   ab 100    -> ganze Zahlen, auf 5 gerundet bei Masse und Volumen
    ///   ab 10     -> ganze Zahlen
    ///   ab 1      -> eine Nachkommastelle
    ///   darunter  -> Bruch, wenn er nahe genug liegt, sonst zwei Stellen
    func formatNumber(_ value: Double, unit: MeasurementUnit?, locale: Locale) -> String {
        let isBulk = unit?.isAbsoluteMass == true || unit?.isAbsoluteVolume == true

        if value >= 100, isBulk {
            let rounded = (value / 5).rounded() * 5
            return decimalString(rounded, fractionDigits: 0, locale: locale)
        }
        if value >= 10 {
            return decimalString(value.rounded(), fractionDigits: 0, locale: locale)
        }
        if value >= 1 {
            let rounded = (value * 10).rounded() / 10
            return decimalString(rounded, fractionDigits: rounded == rounded.rounded() ? 0 : 1, locale: locale)
        }
        if let fraction = nearestFraction(value) {
            return fraction
        }
        return decimalString((value * 100).rounded() / 100, fractionDigits: 2, locale: locale)
    }

    /// Kleine Mengen liest man in der Kueche als Bruch, nicht als 0,33.
    private static let fractionTable: [(value: Double, label: String)] = [
        (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"), (0.375, "⅜"),
        (0.5, "½"), (0.625, "⅝"), (2.0 / 3, "⅔"), (0.75, "¾"), (0.875, "⅞"),
    ]

    func nearestFraction(_ value: Double, tolerance: Double = 0.02) -> String? {
        for entry in Self.fractionTable where abs(entry.value - value) <= tolerance {
            return entry.label
        }
        return nil
    }

    private func decimalString(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        formatter.usesGroupingSeparator = value >= 10_000
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
