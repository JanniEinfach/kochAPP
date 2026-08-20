import Foundation
import CoreUtilities

/// Wandelt die Zahlschreibweisen deutscher Rezepte in `Double` um.
///
/// Abgedeckt, weil alles davon real vorkommt:
///   "1"  "1,5"  "1.5"  "1/2"  "1 1/2"  "½"  "1½"  "0,25"  "1'000"
/// Nicht abgedeckt und bewusst nicht geraten: ausgeschriebene Zahlwoerter
/// ausser den haeufigsten ("ein", "eine", "zwei", "drei"), weil "ein Ei" und
/// "ein wenig Salz" sonst dieselbe Behandlung bekaemen.
public enum NumberTokenizer {

    /// Unicode-Bruchzeichen, die aus Buchsatz und OCR stammen.
    static let vulgarFractions: [Character: Double] = [
        "¼": 0.25, "½": 0.5, "¾": 0.75,
        "⅐": 1.0 / 7, "⅑": 1.0 / 9, "⅒": 0.1,
        "⅓": 1.0 / 3, "⅔": 2.0 / 3,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
        "⅙": 1.0 / 6, "⅚": 5.0 / 6,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
    ]

    /// Zahlwoerter, die eindeutig eine Menge meinen.
    /// "ein" fehlt absichtlich: "ein wenig" ist keine Menge.
    static let numberWords: [String: Double] = [
        "eine": 1, "einen": 1, "einem": 1, "einer": 1,
        "zwei": 2, "drei": 3, "vier": 4, "funf": 5, "sechs": 6,
        "sieben": 7, "acht": 8, "neun": 9, "zehn": 10, "zwolf": 12,
        "halbe": 0.5, "halben": 0.5, "halbes": 0.5, "halber": 0.5,
        "viertel": 0.25, "dreiviertel": 0.75,
    ]

    /// Parst genau ein Zahltoken. Gibt `nil` zurueck, wenn es keine Zahl ist.
    public static func parse(_ token: String) -> Double? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Reines Unicode-Bruchzeichen: "½"
        if trimmed.count == 1, let fraction = vulgarFractions[trimmed.first!] {
            return fraction
        }

        // Ganzzahl mit angehaengtem Bruchzeichen: "1½"
        if let last = trimmed.last, let fraction = vulgarFractions[last] {
            let head = String(trimmed.dropLast())
            if head.isEmpty { return fraction }
            if let whole = parseDecimal(head) { return whole + fraction }
            return nil
        }

        // Schraegstrich-Bruch: "1/2" oder "3/4"
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/", maxSplits: 1)
            if parts.count == 2,
               let numerator = parseDecimal(String(parts[0])),
               let denominator = parseDecimal(String(parts[1])),
               denominator != 0 {
                return numerator / denominator
            }
            return nil
        }

        if let value = parseDecimal(trimmed) { return value }

        let word = TextNormalizer.normalizeForMatching(trimmed)
        return numberWords[word]
    }

    /// Dezimalzahl mit deutschem Komma oder englischem Punkt.
    /// Tausendertrennzeichen werden nur akzeptiert, wenn sie eindeutig sind:
    /// "1.000" ist tausend, "1.5" ist eineinhalb. Unterscheidung ueber die
    /// Stellenzahl nach dem Trenner.
    static func parseDecimal(_ input: String) -> Double? {
        var text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        text = text.replacingOccurrences(of: "'", with: "")
        text = text.replacingOccurrences(of: "\u{00A0}", with: "")

        let hasComma = text.contains(",")
        let hasDot = text.contains(".")

        if hasComma && hasDot {
            // "1.234,56" -- Punkt ist Tausender, Komma ist Dezimaltrenner.
            text = text.replacingOccurrences(of: ".", with: "")
            text = text.replacingOccurrences(of: ",", with: ".")
        } else if hasComma {
            text = text.replacingOccurrences(of: ",", with: ".")
        } else if hasDot {
            // Genau drei Ziffern nach dem letzten Punkt und mindestens eine
            // davor: Tausendertrenner. Sonst Dezimalpunkt.
            let parts = text.split(separator: ".")
            if parts.count >= 2,
               parts.dropFirst().allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isNumber) }),
               parts[0].allSatisfy(\.isNumber), !parts[0].isEmpty {
                text = parts.joined()
            }
        }

        guard text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) else { return nil }
        guard text.contains(where: \.isNumber) else { return nil }
        return Double(text)
    }

    /// Ob das Token ueberhaupt zahlartig beginnt. Fuer den Parser, der
    /// entscheiden muss, wo der Zutatenname anfaengt.
    public static func looksNumeric(_ token: String) -> Bool {
        guard let first = token.first else { return false }
        if first.isNumber { return true }
        if vulgarFractions[first] != nil { return true }
        let word = TextNormalizer.normalizeForMatching(token)
        return numberWords[word] != nil
    }
}
