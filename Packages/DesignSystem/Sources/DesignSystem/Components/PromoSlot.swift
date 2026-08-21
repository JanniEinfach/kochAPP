import SwiftUI

/// Platzhalter fuer eine spaetere Einblendung in Listen.
///
/// Rendert heute nichts. Er existiert trotzdem, weil das Layout sich spaeter
/// nicht verschieben soll und weil der Feed die Einfuegelogik schon kennen
/// muss -- eine Komponente, die man spaeter dazwischenschiebt, verschiebt
/// jedes Scrollverhalten und jeden Screenshot.
///
/// Version 1 ist werbefrei. Das bleibt so, bis es bewusst geaendert wird.
public struct PromoSlot: View {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public var body: some View {
        EmptyView()
    }
}

/// Ein Eintrag im Rezeptfeed.
///
/// Als Aufzaehlung modelliert, damit spaetere Einblendungen kein Umbau sind.
/// Ohne das haette der Feed nur ein Array von Rezepten und muesste beim
/// Einfuegen komplett umgeschrieben werden.
public enum FeedItem<Content: Identifiable>: Identifiable {
    case content(Content)
    case promo(index: Int)

    public var id: String {
        switch self {
        case let .content(item): "content-\(item.id)"
        case let .promo(index): "promo-\(index)"
        }
    }
}
