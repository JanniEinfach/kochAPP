import SwiftUI
import DesignSystem

/// Die vier Bereiche der App.
///
/// Bewusst vier und nicht fuenf: die Lernkueche ist ein eigener Reiter und
/// nicht ein Unterpunkt im Profil. Wer sie versteckt, macht aus dem
/// Unterscheidungsmerkmal ein Zusatzfeature.
struct RootView: View {
    @State private var selection: Tab = Tab.initialFromEnvironment

    /// Startreiter ueber eine Umgebungsvariable waehlbar.
    /// Wird fuer automatisierte Screenshots und UI-Tests gebraucht, damit man
    /// nicht jeden Bereich per Hand ansteuern muss. Im normalen Start ohne
    /// gesetzte Variable ist das Kochbuch der Einstieg.

    enum Tab: String, Hashable {
        case cookbook, search, learning, profile

        static var initialFromEnvironment: Tab {
            guard let raw = ProcessInfo.processInfo.environment["LK_INITIAL_TAB"],
                  let tab = Tab(rawValue: raw) else { return .cookbook }
            return tab
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab.cookbook.destination
                .tabItem { Label("Kochbuch", systemImage: "book.closed") }
                .tag(Tab.cookbook)

            Tab.search.destination
                .tabItem { Label("Suchen", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            Tab.learning.destination
                .tabItem { Label("Lernen", systemImage: "graduationcap") }
                .tag(Tab.learning)

            Tab.profile.destination
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        // Der Lernbereich faerbt sich um: warm im Kochbuch, kuehl im Lernen.
        .tint(selection == .learning ? Palette.learning : Palette.accent)
    }
}

private extension RootView.Tab {
    @ViewBuilder
    var destination: some View {
        switch self {
        case .cookbook:
            PlaceholderScreen(
                title: "Kochbuch",
                message: "Hier stehen deine Rezepte.",
                systemImage: "book.closed",
                accent: Palette.accent
            )
        case .search:
            PlaceholderScreen(
                title: "Suchen",
                message: "Suche nach Zutaten, Gerichten oder Techniken.",
                systemImage: "magnifyingglass",
                accent: Palette.accent
            )
        case .learning:
            PlaceholderScreen(
                title: "Lernküche",
                message: "Fachbegriffe, Karteikarten und Fachrechnen.",
                systemImage: "graduationcap",
                accent: Palette.learning
            )
        case .profile:
            PlaceholderScreen(
                title: "Profil",
                message: "Konto, Einstellungen und Berichtsheft.",
                systemImage: "person.crop.circle",
                accent: Palette.accent
            )
        }
    }
}

/// Geruest-Ansicht bis der jeweilige Bereich gebaut ist.
/// Sie sagt, was hier entstehen wird, statt eine leere Flaeche zu zeigen.
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
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(accent)

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
