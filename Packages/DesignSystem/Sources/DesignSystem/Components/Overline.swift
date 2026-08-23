import SwiftUI

/// Kleine Versalzeile über einer Gruppe, etwa "FACHBEGRIFF DES TAGES".
///
/// Bündelt Schriftstufe, Laufweite und Großschreibung an einer Stelle.
/// Gesperrte Versalien ohne Laufweite kleben zusammen, und die Laufweite
/// von Hand an jeder Fundstelle zu setzen geht genau einmal gut.
public struct Overline: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = Palette.textSecondary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text.uppercased())
            .font(Typography.overline())
            .tracking(Typography.overlineTracking)
            .foregroundStyle(color)
            // Der Versalsatz ist eine Gestaltungsentscheidung, keine Aussage
            // über den Inhalt. VoiceOver liest den Originaltext.
            .accessibilityLabel(text)
    }
}
