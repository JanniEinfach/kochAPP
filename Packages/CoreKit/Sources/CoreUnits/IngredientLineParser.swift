import Foundation
import CoreUtilities

/// Ergebnis des Parsens einer einzelnen Zutatenzeile.
public struct ParsedIngredientLine: Sendable, Hashable, Codable {
    /// Der unveraenderte Eingabetext. Wird immer mitgefuehrt und im UI gezeigt.
    public var rawText: String
    public var quantity: Quantity
    public var qualifier: QuantityQualifier?
    /// Der Zutatenname nach Abzug von Menge, Einheit und Zusaetzen.
    public var name: String
    /// Zusatz in Klammern oder nach Komma: "gehackt", "zimmerwarm".
    public var note: String?
    public var isOptional: Bool
    /// 0...1. Unter 0,7 markiert der Review-Screen die Zeile zur Pruefung.
    public var confidence: Double

    public init(
        rawText: String,
        quantity: Quantity = .none,
        qualifier: QuantityQualifier? = nil,
        name: String = "",
        note: String? = nil,
        isOptional: Bool = false,
        confidence: Double = 0
    ) {
        self.rawText = rawText
        self.quantity = quantity
        self.qualifier = qualifier
        self.name = name
        self.note = note
        self.isOptional = isOptional
        self.confidence = confidence
    }
}

/// Deterministischer Parser fuer deutsche Zutatenzeilen.
///
/// Er laeuft nach dem LLM-Schritt der Scan-Pipeline und hat bei der Menge das
/// letzte Wort: ein Sprachmodell, das "1/2" als 1 liest, ist ein stiller Fehler
/// im Kochbuch: der Parser ist reproduzierbar und testbar.
public struct IngredientLineParser: Sendable {

    public init() {}

    private static let optionalMarkers: Set<String> = [
        "optional", "nach belieben", "wer mag", "falls gewunscht", "wahlweise",
    ]

    private static let qualifierMarkers: [(tokens: [String], qualifier: QuantityQualifier)] = [
        (["geh", "gehauft", "gehaufter", "gehaufte", "gehauftem"], .heaped),
        (["gestr", "gestrichen", "gestrichener", "gestrichene"], .level),
        (["ca", "circa", "etwa", "ungefahr", "rund"], .approximately),
        // "n b" mit Leerzeichen, weil normalizeForMatching aus "n. B." genau das macht.
        (["nb", "n b", "nach bedarf", "nach geschmack", "nach belieben"], .toTaste),
        (["etwas", "ein wenig", "ein bisschen", "eine kleinigkeit"], .some),
        (["reichlich", "grosszugig"], .generous),
    ]

    public func parse(_ line: String) -> ParsedIngredientLine {
        let raw = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return ParsedIngredientLine(rawText: line, confidence: 0)
        }

        var result = ParsedIngredientLine(rawText: line)
        var working = raw

        // 1. Klammerzusatz abtrennen: "200 g Mehl (Type 405)"
        if let note = extractParenthetical(&working) {
            result.note = note
        }

        // 2. Optional-Markierung
        let normalizedFull = TextNormalizer.normalizeForMatching(working)
        for marker in Self.optionalMarkers where normalizedFull.contains(marker) {
            result.isOptional = true
            working = removeCaseInsensitive(marker, from: working)
            break
        }

        // 3. Fuehrende Qualifier: "ca. 200 g", "etwas Öl"
        var tokens = tokenize(working)
        if let (qualifier, consumed) = leadingQualifier(in: tokens) {
            result.qualifier = qualifier
            tokens.removeFirst(consumed)
        }

        // 4. Zahl oder Zahlenspanne. Kann die Tokenliste umschreiben,
        //    weil "500g" in "500" und "g" zerfaellt.
        let quantity = leadingQuantity(in: &tokens)

        // 5. Einheit direkt hinter der Zahl
        var unit: MeasurementUnit?
        if !quantity.isEmpty, let first = tokens.first, let parsed = MeasurementUnit.parse(first) {
            unit = parsed
            tokens.removeFirst()
        }

        // 6. Qualifier auch hinter der Einheit: "1 EL geh."
        if result.qualifier == nil, let (qualifier, consumed) = leadingQualifier(in: tokens) {
            result.qualifier = qualifier
            tokens.removeFirst(consumed)
        }

        // 7. Nachgestellter Qualifier: "Salz n. B.", "Öl nach Bedarf"
        if result.qualifier == nil, let (qualifier, consumed) = trailingQualifier(in: tokens) {
            result.qualifier = qualifier
            tokens.removeLast(consumed)
        }

        result.quantity = Quantity(min: quantity.min, max: quantity.max, unit: unit)

        // 8. Rest ist der Name, ein nachgestellter Kommazusatz wird zur Notiz.
        var name = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if let commaIndex = name.firstIndex(of: ",") {
            let tail = String(name[name.index(after: commaIndex)...])
                .trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty {
                result.note = [result.note, tail].compactMap { $0 }.joined(separator: "; ")
            }
            name = String(name[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        }
        result.name = name.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:"))

        result.confidence = confidence(for: result)
        return result
    }

    // MARK: - Bausteine

    private func tokenize(_ input: String) -> [String] {
        input
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func extractParenthetical(_ text: inout String) -> String? {
        guard let open = text.firstIndex(of: "("),
              let close = text[open...].firstIndex(of: ")") else { return nil }
        let inner = String(text[text.index(after: open)..<close])
            .trimmingCharacters(in: .whitespaces)
        text.removeSubrange(open...close)
        text = text.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        return inner.isEmpty ? nil : inner
    }

    private func removeCaseInsensitive(_ needle: String, from text: String) -> String {
        guard let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return text
        }
        var copy = text
        copy.removeSubrange(range)
        return copy
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;"))
    }

    /// Erkennt einen Qualifier am Anfang der Tokenliste.
    /// Gibt die Anzahl der verbrauchten Tokens zurueck, weil "nach Bedarf"
    /// zwei Tokens lang ist.
    private func leadingQualifier(in tokens: [String]) -> (QuantityQualifier, Int)? {
        guard !tokens.isEmpty else { return nil }

        for count in stride(from: min(3, tokens.count), through: 1, by: -1) {
            let phrase = TextNormalizer.normalizeForMatching(
                tokens.prefix(count).joined(separator: " ")
            ).replacingOccurrences(of: ".", with: "")

            for entry in Self.qualifierMarkers where entry.tokens.contains(phrase) {
                return (entry.qualifier, count)
            }
        }
        return nil
    }

    /// Liest eine Zahl oder Spanne am Anfang. Formen:
    ///   "500"        -> exakt
    ///   "2-3"        -> Spanne, auch mit Halbgeviertstrich
    ///   "2 bis 3"    -> Spanne
    ///   "1 1/2"      -> gemischter Bruch
    ///   "500g"       -> Zahl und Einheit ohne Leerzeichen
    private func leadingQuantity(in tokens: inout [String]) -> Quantity {
        guard let first = tokens.first else { return .none }

        // "500g" -> Token wird durch die reine Einheit ersetzt, damit der
        // naechste Schritt sie regulaer erkennt.
        if let split = splitNumberAndUnit(first) {
            tokens[0] = split.unit
            return Quantity(min: split.value, max: split.value)
        }

        // Spanne mit Trennstrich im selben Token: "2-3"
        if let range = parseRangeToken(first) {
            tokens.removeFirst()
            return Quantity(min: range.lower, max: range.upper)
        }

        guard let value = NumberTokenizer.parse(first) else { return .none }

        // "2 bis 3"
        if tokens.count >= 3,
           ["bis", "-", "\u{2013}", "\u{2014}"].contains(TextNormalizer.normalize(tokens[1])),
           let upper = NumberTokenizer.parse(tokens[2]) {
            tokens.removeFirst(3)
            return Quantity(min: value, max: upper)
        }

        // Gemischter Bruch: "1 1/2"
        if tokens.count >= 2,
           value == value.rounded(),
           tokens[1].contains("/"),
           let fraction = NumberTokenizer.parse(tokens[1]),
           fraction < 1 {
            tokens.removeFirst(2)
            let total = value + fraction
            return Quantity(min: total, max: total)
        }

        tokens.removeFirst()
        return Quantity(min: value, max: value)
    }

    /// Erkennt einen Qualifier am ENDE der Tokenliste. "Salz n. B." ist im
    /// deutschen Rezeptsatz genauso ueblich wie "n. B. Salz".
    private func trailingQualifier(in tokens: [String]) -> (QuantityQualifier, Int)? {
        guard !tokens.isEmpty else { return nil }

        for count in stride(from: min(3, tokens.count), through: 1, by: -1) {
            // Ein Qualifier darf nicht die ganze Zeile auffressen.
            guard count < tokens.count else { continue }

            let phrase = TextNormalizer.normalizeForMatching(
                tokens.suffix(count).joined(separator: " ")
            ).replacingOccurrences(of: ".", with: "")

            for entry in Self.qualifierMarkers where entry.tokens.contains(phrase) {
                return (entry.qualifier, count)
            }
        }
        return nil
    }

    /// "500g" -> (500, "g"). Nur wenn der Zahlteil eindeutig ist.
    private func splitNumberAndUnit(_ token: String) -> (value: Double, unit: String)? {
        var digits = ""
        var rest = ""
        var inNumber = true

        for character in token {
            if inNumber, character.isNumber || character == "," || character == "." || character == "/" {
                digits.append(character)
            } else {
                inNumber = false
                rest.append(character)
            }
        }

        guard !digits.isEmpty, !rest.isEmpty,
              MeasurementUnit.parse(rest) != nil,
              let value = NumberTokenizer.parse(digits) else { return nil }
        return (value, rest)
    }

    private func parseRangeToken(_ token: String) -> (lower: Double, upper: Double)? {
        for separator in ["-", "–", "—"] where token.contains(separator) {
            let parts = token.components(separatedBy: separator)
            guard parts.count == 2,
                  let lower = NumberTokenizer.parse(parts[0]),
                  let upper = NumberTokenizer.parse(parts[1]) else { continue }
            return (lower, upper)
        }
        return nil
    }

    /// Konfidenz aus dem, was tatsaechlich erkannt wurde.
    /// Der Wert steuert nur die Markierung im Review-Screen, er entscheidet nie
    /// allein ueber Speichern -- gespeichert wird erst nach menschlicher Sicht.
    private func confidence(for line: ParsedIngredientLine) -> Double {
        var score = 0.0

        if !line.name.isEmpty { score += 0.4 }
        if line.name.count >= 3 { score += 0.1 }

        if line.quantity.min != nil {
            score += 0.25
            if line.quantity.unit != nil {
                score += 0.25
            } else {
                // Zahl ohne Einheit ist bei Stueckware normal ("3 Eier"),
                // aber unsicherer als eine Angabe mit Einheit.
                score += 0.1
            }
        } else if line.qualifier?.impliesNoNumber == true {
            // "etwas Öl" ist vollstaendig, nicht unvollstaendig.
            score += 0.4
        }

        if line.name.count > 60 { score -= 0.2 }
        if line.name.contains(where: \.isNumber) { score -= 0.15 }

        return Swift.min(1.0, Swift.max(0.0, score))
    }
}
