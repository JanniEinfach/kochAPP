import Testing
import CoreUtilities

@Suite("Textnormalisierung, Spiegel von public.normalize_text")
struct TextNormalizerTests {

    @Test("Umlaute werden auf Basisbuchstaben abgebildet")
    func umlauts() {
        #expect(TextNormalizer.normalize("Püree") == "puree")
        #expect(TextNormalizer.normalize("Möhren") == "mohren")
        #expect(TextNormalizer.normalize("Käse") == "kase")
    }

    @Test("Scharfes S wird zu Doppel-S, nicht zu einem S")
    func sharpS() {
        #expect(TextNormalizer.normalize("Weißwein") == "weisswein")
        #expect(TextNormalizer.normalize("Fleißig") == "fleissig")
    }

    @Test("Mehrfache Leerzeichen werden zusammengezogen und getrimmt")
    func whitespace() {
        #expect(TextNormalizer.normalize("  zwei   Blatt  Gelatine ") == "zwei blatt gelatine")
        #expect(TextNormalizer.normalize("\tKalbs\nfond") == "kalbs fond")
    }

    @Test("Franzoesische Akzente aus Kuechenbegriffen")
    func frenchAccents() {
        #expect(TextNormalizer.normalize("Sauté") == "saute")
        #expect(TextNormalizer.normalize("Crème fraîche") == "creme fraiche")
        #expect(TextNormalizer.normalize("Pürée") == "puree")
    }

    @Test("Satzzeichen fallen nur beim Matching weg")
    func matchingVariant() {
        #expect(TextNormalizer.normalize("n. B.") == "n. b.")
        #expect(TextNormalizer.normalizeForMatching("n. B.") == "n b")
    }

    @Test("Leerer Text bleibt leer")
    func empty() {
        #expect(TextNormalizer.normalize("") == "")
        #expect(TextNormalizer.normalize("   ") == "")
    }
}
