import SwiftUI
import DesignSystem

/// Die fünf Bereiche der App.
///
/// Reihenfolge und Zuschnitt folgen dem Gestaltungs-Handoff in
/// `docs/design-handoff/`. "Finden" trägt die Rolle `.search` und wird von
/// iOS dadurch eigenständig platziert und behandelt -- das ist die native
/// Konvention und sieht auf jedem Systemstand richtig aus, statt eine
/// Suchlupe an eine feste Position zu zwingen.
struct RootView: View {
    @State private var selection: Tabs = Tabs.initialFromEnvironment

    enum Tabs: String, Hashable {
        case cookbook, scan, learning, team, search

        static var initialFromEnvironment: Tabs {
            guard let raw = ProcessInfo.processInfo.environment["LK_INITIAL_TAB"],
                  let tab = Tabs(rawValue: raw) else { return .cookbook }
            return tab
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Kochbuch", systemImage: "book", value: Tabs.cookbook) {
                CookbookPlaceholder()
            }

            Tab("Scannen", systemImage: "doc.text.viewfinder", value: Tabs.scan) {
                ScanPlaceholder()
            }

            Tab("Lernen", systemImage: "graduationcap", value: Tabs.learning) {
                LearningPlaceholder()
            }

            Tab("Team", systemImage: "person.2", value: Tabs.team) {
                TeamPlaceholder()
            }

            Tab(value: Tabs.search, role: .search) {
                SearchPlaceholder()
            }
        }
        // Die Leiste behält ihre Farbe über alle Bereiche hinweg.
        //
        // Vorher wechselte sie beim Sprung in den Lernbereich auf Petrol.
        // Das sah in der Vorschau richtig aus und war in der Hand falsch:
        // ein Wechsel der Tönung baut die Leiste neu auf, und unter Liquid
        // Glass wird daraus ein sichtbarer Sprung bei jedem Reiterwechsel.
        //
        // Die Leiste gehört ohnehin der App und nicht dem Bereich. Die
        // Zweifarbigkeit lebt weiter, aber dort wo sie hingehört: in den
        // Inhalten. Der Lernbereich färbt seine eigenen Elemente petrol.
        .tint(Palette.accent)
        .minimizingTabBarOnScroll()
    }
}

private extension View {
    /// Lässt die Leiste beim Scrollen schrumpfen und Inhalt freigeben.
    ///
    /// Systemverhalten ab iOS 26, wir schalten es nur scharf. Auf iOS 18 bis 25
    /// gibt es weder das Verhalten noch die zugehörige Leiste, dort passiert
    /// nichts -- die App bleibt lauffähig, statt das Mindestsystem anzuheben.
    @ViewBuilder
    func minimizingTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

// MARK: - Vorläufige Bereichsinhalte

private struct CookbookPlaceholder: View {
    var body: some View {
        PlaceholderScreen(
            title: "Kochbuch",
            message: "Hier stehen deine Rezepte.",
            systemImage: "book",
            accent: Palette.accent
        )
    }
}

private struct SearchPlaceholder: View {
    var body: some View {
        PlaceholderScreen(
            title: "Finden",
            message: "Suche nach Zutaten, Gerichten oder Techniken.",
            systemImage: "magnifyingglass",
            accent: Palette.accent
        )
    }
}

private struct ScanPlaceholder: View {
    var body: some View {
        PlaceholderScreen(
            title: "Scannen",
            message: "Fotografiere ein Papierrezept ab.",
            systemImage: "doc.text.viewfinder",
            accent: Palette.accent
        )
    }
}

private struct LearningPlaceholder: View {
    var body: some View {
        PlaceholderScreen(
            title: "Lernküche",
            message: "Fachbegriffe, Karteikarten und Fachrechnen.",
            systemImage: "graduationcap",
            // Der Lernbereich färbt seinen Inhalt, nicht die Leiste.
            accent: Palette.learning
        )
    }
}

private struct TeamPlaceholder: View {
    var body: some View {
        PlaceholderScreen(
            title: "Team",
            message: "Aufgaben, Berichtsheft und Rückmeldungen.",
            systemImage: "person.2",
            accent: Palette.learning
        )
    }
}

/// Gerüst-Ansicht, bis der jeweilige Bereich gebaut ist.
/// Sagt, was hier entstehen wird, statt eine leere Fläche zu zeigen.
private struct PlaceholderScreen: View {
    let title: String
    let message: String
    let systemImage: String
    let accent: Color

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.surface.ignoresSafeArea()

                VStack(spacing: Spacing.inner) {
                    Image(systemName: systemImage)
                        // Die Größe kommt aus einer Textstufe statt aus einer
                        // festen Punktzahl. Dadurch wächst das Zeichen mit der
                        // Systemschrift mit und behält sein optisches Gewicht.
                        .font(.system(.largeTitle, weight: .light))
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.hierarchical)

                    Text(message)
                        .font(Typography.callout())
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.section)
                }
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    RootView()
}
