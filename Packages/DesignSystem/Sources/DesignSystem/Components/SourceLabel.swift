import SwiftUI

/// Benennt, woher ein angezeigter Wert stammt.
///
/// Wird ueberall dort gebraucht, wo mehrere Quellen nebeneinander stehen:
/// bei der Schwierigkeit (Heuristik, Autor, Community) und bei Bewertungen
/// (eigene gegen fremde). Einen gemeinsamen Durchschnitt aus "4,3 bei 2.104
/// Bewertungen" und "5,0 bei einer" zu bilden waere eine Luege, also zeigen
/// wir beides mit Herkunft.
public struct SourceLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(Typography.caption())
            .foregroundStyle(Palette.textTertiary)
    }
}
