import Foundation
import CoreUtilities

/// Einheiten, wie sie in deutschen Rezepten tatsaechlich vorkommen.
///
/// Bewusst kein `Foundation.UnitMass`: Rezepte kennen `Prise`, `Bund` und
/// `Pck.`, und die Umrechnung EL -> g haengt an der Zutat, nicht an der Einheit.
public enum MeasurementUnit: String, Sendable, Hashable, CaseIterable, Codable {

    // Masse
    case gram, kilogram, milligram
    // Volumen
    case milliliter, liter, centiliter, deciliter
    // Kuechenmasse (volumenbasiert, Umrechnung braucht die Dichte der Zutat)
    case tablespoon      // EL
    case teaspoon        // TL
    case knifeTip        // Msp.
    case pinch           // Prise
    case cup             // Tasse
    case mug             // Becher
    case shot            // Schuss
    case dash            // Spritzer
    case handful         // Handvoll
    // Stueckmasse
    case piece           // Stueck
    case bunch           // Bund
    case clove           // Zehe
    case stalk           // Stange
    case head            // Kopf
    case slice           // Scheibe
    case leaf            // Blatt
    case can             // Dose
    case jar             // Glas
    case package         // Pck.
    case bag             // Beutel
    case bottle          // Flasche
    case drop            // Tropfen
    case sheet           // Blatt Gelatine

    /// Ob die Einheit ohne Kenntnis der Zutat in Gramm umgerechnet werden kann.
    public var isAbsoluteMass: Bool {
        switch self {
        case .gram, .kilogram, .milligram: true
        default: false
        }
    }

    /// Ob die Einheit ein reines Volumen ist.
    public var isAbsoluteVolume: Bool {
        switch self {
        case .milliliter, .liter, .centiliter, .deciliter: true
        default: false
        }
    }

    /// Volumen in Millilitern, sofern die Einheit ein definiertes Volumen hat.
    /// EL und TL sind in DACH auf 15 bzw. 5 ml normiert.
    public var milliliters: Double? {
        switch self {
        case .milliliter: 1
        case .centiliter: 10
        case .deciliter: 100
        case .liter: 1000
        case .tablespoon: 15
        case .teaspoon: 5
        case .knifeTip: 0.5
        case .pinch: 0.35
        case .cup: 150
        case .mug: 250
        case .shot: 20
        case .dash: 2
        case .drop: 0.05
        default: nil
        }
    }

    /// Masse in Gramm, sofern die Einheit eine reine Masseeinheit ist.
    public var grams: Double? {
        switch self {
        case .gram: 1
        case .kilogram: 1000
        case .milligram: 0.001
        default: nil
        }
    }

    /// Anzeigeform, wie sie in einem deutschen Rezept steht.
    public var symbol: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .milligram: "mg"
        case .milliliter: "ml"
        case .centiliter: "cl"
        case .deciliter: "dl"
        case .liter: "l"
        case .tablespoon: "EL"
        case .teaspoon: "TL"
        case .knifeTip: "Msp."
        case .pinch: "Prise"
        case .cup: "Tasse"
        case .mug: "Becher"
        case .shot: "Schuss"
        case .dash: "Spritzer"
        case .handful: "Handvoll"
        case .piece: "Stück"
        case .bunch: "Bund"
        case .clove: "Zehe"
        case .stalk: "Stange"
        case .head: "Kopf"
        case .slice: "Scheibe"
        case .leaf: "Blatt"
        case .can: "Dose"
        case .jar: "Glas"
        case .package: "Pck."
        case .bag: "Beutel"
        case .bottle: "Flasche"
        case .drop: "Tropfen"
        case .sheet: "Blatt"
        }
    }

    /// Plural, wo er im Deutschen abweicht. Wird bei Menge != 1 verwendet.
    public var pluralSymbol: String {
        switch self {
        case .pinch: "Prisen"
        case .cup: "Tassen"
        case .mug: "Becher"
        case .piece: "Stück"
        case .bunch: "Bund"
        case .clove: "Zehen"
        case .stalk: "Stangen"
        case .head: "Köpfe"
        case .slice: "Scheiben"
        case .leaf: "Blätter"
        case .can: "Dosen"
        case .jar: "Gläser"
        case .bag: "Beutel"
        case .bottle: "Flaschen"
        case .drop: "Tropfen"
        case .sheet: "Blatt"
        case .handful: "Handvoll"
        case .dash: "Spritzer"
        case .shot: "Schuss"
        default: symbol
        }
    }

    /// Alle Schreibweisen, die im Fliesstext oder aus OCR auftauchen.
    /// Normalisiert (klein, ohne Umlaute, ohne Punkt) verglichen.
    static let synonyms: [String: MeasurementUnit] = {
        var map: [String: MeasurementUnit] = [:]
        func add(_ unit: MeasurementUnit, _ keys: [String]) {
            for key in keys { map[key] = unit }
        }
        add(.gram,       ["g", "gr", "gramm", "grammm"])
        add(.kilogram,   ["kg", "kilo", "kilogramm"])
        add(.milligram,  ["mg", "milligramm"])
        add(.milliliter, ["ml", "milliliter"])
        add(.centiliter, ["cl", "centiliter", "zentiliter"])
        add(.deciliter,  ["dl", "deziliter"])
        add(.liter,      ["l", "ltr", "liter"])
        add(.tablespoon, ["el", "essloffel", "esslofel", "essl", "tbsp", "eloffel"])
        add(.teaspoon,   ["tl", "teeloffel", "teel", "tsp"])
        add(.knifeTip,   ["msp", "messerspitze", "messerspitzen"])
        add(.pinch,      ["prise", "prisen"])
        add(.cup,        ["tasse", "tassen"])
        add(.mug,        ["becher"])
        add(.shot,       ["schuss"])
        add(.dash,       ["spritzer"])
        add(.handful,    ["handvoll", "hand voll"])
        add(.piece,      ["stuck", "stk", "st", "stueck"])
        add(.bunch,      ["bund", "bunde", "bd"])
        add(.clove,      ["zehe", "zehen"])
        add(.stalk,      ["stange", "stangen", "stangel"])
        add(.head,       ["kopf", "kopfe"])
        add(.slice,      ["scheibe", "scheiben"])
        add(.leaf,       ["blatt", "blatter"])
        add(.can,        ["dose", "dosen", "ds"])
        add(.jar,        ["glas", "glaser"])
        add(.package,    ["pck", "pkg", "packung", "packungen", "paket", "pack"])
        add(.bag,        ["beutel", "btl", "tute", "tuten"])
        add(.bottle,     ["flasche", "flaschen", "fl"])
        add(.drop,       ["tropfen"])
        return map
    }()

    /// Erkennt eine Einheit aus einem Rohtoken. Gibt `nil` zurueck, wenn das
    /// Token keine bekannte Einheit ist -- dann gehoert es zum Zutatennamen.
    public static func parse(_ token: String) -> MeasurementUnit? {
        let key = TextNormalizer.normalizeForMatching(token)
            .replacingOccurrences(of: " ", with: "")
        guard !key.isEmpty else { return nil }
        return synonyms[key]
    }
}