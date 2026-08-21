import SwiftUI

/// Markiert eine Angabe, die automatisch erkannt wurde und einen zweiten
/// Blick verdient.
///
/// Bewusst keine Fehlerfarbe und kein Warndreieck: Der Scan hat nichts falsch
/// gemacht, er ist sich nur nicht sicher. Wer hier Alarm signalisiert,
/// erzieht Nutzer dazu, die Pruefansicht wegzuklicken.
public struct ConfidenceBadge: View {
    public enum Level {
        case certain
        case uncertain

        init(confidence: Double) {
            self = confidence >= 0.7 ? .certain : .uncertain
        }
    }

    private let level: Level
    private let label: String

    public init(confidence: Double, label: String = "prüfen") {
        self.level = Level(confidence: confidence)
        self.label = label
    }

    public var body: some View {
        switch level {
        case .certain:
            EmptyView()
        case .uncertain:
            Text(label)
                .font(Typography.caption())
                .padding(.horizontal, Spacing.tight)
                .padding(.vertical, Spacing.hair)
                .background(Palette.warning.opacity(0.16), in: Capsule())
                .foregroundStyle(Palette.warning)
                .accessibilityLabel("Automatisch erkannt, bitte prüfen")
        }
    }
}
