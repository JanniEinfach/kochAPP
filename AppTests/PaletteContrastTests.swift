import Testing
import SwiftUI
import DesignSystem

/// Haelt die Kontrastzusage aus `Palette` fest.
///
/// Ohne diesen Test rutscht eine Farbe irgendwann um ein paar Prozent, sieht
/// huebscher aus und ist in einer sonnigen Kueche nicht mehr lesbar. Der Test
/// ist die einzige Stelle, an der das auffaellt, bevor es jemand benutzt.
@Suite("Farbkontraste nach WCAG")
@MainActor
struct PaletteContrastTests {

    /// WCAG-Anforderung fuer Fliesstext unter 18 pt.
    static let minimumBodyText = 4.5
    /// WCAG-Anforderung fuer grafische Elemente und grossen Text.
    static let minimumGraphic = 3.0

    @Test("Textfarben gegen die Grundflaeche, beide Erscheinungsbilder")
    func textContrast() {
        let cases: [(String, Color)] = [
            ("textPrimary", Palette.textPrimary),
            ("textSecondary", Palette.textSecondary),
            ("textTertiary", Palette.textTertiary),
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            for (name, color) in cases {
                let value = contrast(color, Palette.surface, style: style)
                #expect(
                    value >= Self.minimumBodyText,
                    "\(name) erreicht in \(style == .light ? "hell" : "dunkel") nur \(String(format: "%.2f", value))"
                )
            }
        }
    }

    @Test("Handlungsfarben sind auch als Beschriftung lesbar")
    func accentContrast() {
        let cases: [(String, Color)] = [
            ("accent", Palette.accent),
            ("learning", Palette.learning),
            ("danger", Palette.danger),
            ("success", Palette.success),
            ("warning", Palette.warning),
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            for (name, color) in cases {
                let value = contrast(color, Palette.surface, style: style)
                #expect(
                    value >= Self.minimumBodyText,
                    "\(name) erreicht in \(style == .light ? "hell" : "dunkel") nur \(String(format: "%.2f", value))"
                )
            }
        }
    }

    @Test("Weicher Hintergrund traegt die zugehoerige Handlungsfarbe")
    func softBackgrounds() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(contrast(Palette.accent, Palette.accentSoft, style: style) >= Self.minimumGraphic)
            #expect(contrast(Palette.learning, Palette.learningSoft, style: style) >= Self.minimumGraphic)
        }
    }

    // MARK: - Rechnung nach WCAG 2.1

    private func contrast(_ a: Color, _ b: Color, style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let first = relativeLuminance(UIColor(a).resolvedColor(with: traits))
        let second = relativeLuminance(UIColor(b).resolvedColor(with: traits))
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
