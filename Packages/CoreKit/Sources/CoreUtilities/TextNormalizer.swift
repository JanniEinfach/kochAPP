import Foundation

/// Deutschsprachige Textnormalisierung fuer Suche und Begriffserkennung.
///
/// Diese Regeln sind zeichengleich mit der SQL-Funktion `public.normalize_text`
/// (siehe `supabase/migrations/00000000000001_foundation.sql`). Weichen die
/// beiden voneinander ab, liefert die lokale Offline-Suche andere Treffer als
/// die Serversuche und niemand versteht warum. Aenderungen deshalb immer an
/// beiden Stellen, und der Test `TextNormalizerTests` haelt die Faelle fest.
public enum TextNormalizer {

    /// Reihenfolge ist bedeutsam: `ß` wird zu `ss` expandiert, bevor die
    /// Einzelzeichen-Ersetzung laeuft.
    private static let characterMap: [Character: Character] = [
        "ä": "a", "ö": "o", "ü": "u",
        "à": "a", "á": "a", "â": "a", "ã": "a", "å": "a",
        "é": "e", "è": "e", "ê": "e", "ë": "e",
        "í": "i", "ì": "i", "î": "i", "ï": "i",
        "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ø": "o",
        "ú": "u", "ù": "u", "û": "u",
        "ý": "y", "ñ": "n", "ç": "c",
    ]

    public static func normalize(_ input: String) -> String {
        let lowered = input.lowercased().replacingOccurrences(of: "ß", with: "ss")

        var result = String()
        result.reserveCapacity(lowered.count)
        var lastWasSpace = false

        for character in lowered {
            if character.isWhitespace {
                if !lastWasSpace && !result.isEmpty {
                    result.append(" ")
                }
                lastWasSpace = true
                continue
            }
            lastWasSpace = false
            result.append(characterMap[character] ?? character)
        }

        if result.hasSuffix(" ") {
            result.removeLast()
        }
        return result
    }

    /// Normalisiert und entfernt zusaetzlich Satzzeichen. Fuer den Abgleich
    /// einzelner Woerter gegen Synonymtabellen.
    public static func normalizeForMatching(_ input: String) -> String {
        let normalized = normalize(input)
        return String(normalized.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " "
        })
    }
}
