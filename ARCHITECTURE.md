# Lernkueche

Digitales Kochbuch mit Papierrezept-Scan, das dieselben Rezeptdaten als
Lernmaterial fuer Koch-Auszubildende zweitverwertet.

Arbeitstitel. Der Produktname steht an genau einer Stelle:
`App/Config/Shared.xcconfig`, Schluessel `PRODUCT_DISPLAY_NAME`.

## Stand

| Bereich | Stand |
|---|---|
| Datenbankschema, 7 Migrationen | fertig, gegen Postgres 17 verifiziert |
| RLS-Policies und Tests | fertig, 16 Pruefungen gruen |
| Seeds: Allergene, Taxonomie, Quellen | fertig |
| Mengenparser, Portionsskalierung | fertig, 58 Unit-Tests gruen |
| Xcode-Projekt, App-Target | offen |
| Auth, Sync, Scan, Kochmodus, Lernmodul | offen |

## Was v1 ist und was nicht

Enthalten: eigenes Kochbuch, Papierscan mit Pruefansicht, Kochmodus,
Volltext- und Zutatensuche, Fachbegriff-Layer, Karteikarten mit FSRS,
Fachrechnen-Generator, Berichtsheft-Entwuerfe.

Nicht enthalten, jeweils mit Begruendung in DECISIONS.md: oeffentliche Rezepte
(ADR-7), Fremdrezept-Feed (ADR-6), Team-Oberflaeche (ADR-8), Pruefungssimulator
und Skill-Tree (Contentaufwand ohne Nutzerbasis), Einkaufsliste und Meal-Planner.

## Schichten

```
App                    Composition Root, DI, Ressourcen, Privacy Manifest
  |
Features/*             SwiftUI. Kennt nur Repository-Protokolle.
  |
RepositoryKit          Offline-first-Fassade. Liest lokal, schreibt lokal + Outbox.
  |            \
PersistenceKit         RemoteKit
GRDB, Sync-Engine      Supabase, DTOs, Edge Functions
  |            /
CoreKit                Wertetypen und Logik ohne IO
```

Die Regel, die der Compiler durchsetzt: **kein Feature importiert RemoteKit
oder PersistenceKit.** Wird Supabase spaeter ersetzt (ADR-3), bleibt jede View
unberuehrt.

## Pakete

| Paket | Inhalt | Abhaengigkeiten |
|---|---|---|
| CoreUtilities | TextNormalizer, Logging-Fassade | keine |
| CoreUnits | MeasurementUnit, Quantity, NumberTokenizer, IngredientLineParser, PortionScaler | CoreUtilities |
| PersistenceKit | GRDB-Setup, Records, Sync-Engine | CoreKit |
| RemoteKit | Supabase-Client, DTOs, Endpoints | CoreKit |
| RepositoryKit | Repository-Protokolle und Implementierungen | Persistence, Remote |
| DesignSystem | Tokens, Komponenten, Kochmodus-Typoskala | CoreKit |
| ScanKit | VisionKit, On-Device-OCR, Pruefansicht | Domain, DesignSystem |
| Features/* | je ein Feature | Repository, DesignSystem |

Der Mengenparser liegt in CoreUnits, nicht in einem eigenen DomainKit: er ist
reine Einheitenarithmetik ohne Fremdabhaengigkeit. FSRS, Fachrechnen-Generator
und Begriffserkennung bekommen ein eigenes Paket, sobald sie gebaut werden.

## Datenmodell, tragende Entscheidungen

**Kanonische Zutaten.** `recipe_ingredients` verweist optional auf
`ingredients`. Der Rohtext bleibt immer erhalten und wird angezeigt. Daran
haengen Zutatensuche, Allergene, Ruestverluste und Kalkulation (ADR-4).

**Drei Schwierigkeitsquellen, nie vermischt.** `difficulty_heuristic`,
`difficulty_author`, `difficulty_community`. Angezeigt wird der Community-Wert
ab fuenf Angaben, sonst der Autorenwert, sonst die Heuristik. Die Quelle steht
im UI dabei.

**Bewertungen getrennt.** `recipe_ratings` und `external_ratings` bekommen nie
einen gemeinsamen Durchschnitt. "4,3 aus 2.104 Bewertungen" und "5,0 aus einer"
zu verrechnen waere eine Luege.

**Soft-Delete auf Rezepten.** `deleted_at`. Der App-Pfad loescht nie hart.
Familienrezepte werden aus Versehen geloescht.

**Suche.** `search_text` wird per Trigger aus Titel, Zutaten und Schritten
denormalisiert, `search_vector` ist eine generated column mit deutscher
Konfiguration darauf. Zusaetzlich `embedding` fuer semantische Suche.

**Textnormalisierung doppelt gefuehrt.** `public.normalize_text` in SQL und
`TextNormalizer` in Swift muessen zeichengleich bleiben, sonst liefern lokale
und Serversuche unterschiedliche Treffer. Beide Stellen sind gegenseitig
kommentiert, die Faelle stehen in `TextNormalizerTests`.

## Sicherheit

RLS ist auf jeder Tabelle aktiv, ohne Ausnahme. Der Test `10_schema_checks.sql`
scheitert, sobald eine Tabelle ohne RLS oder ohne Policy hinzukommt, und ebenso,
sobald eine `security definer`-Funktion ohne festen `search_path` existiert.

`20_rls.sql` prueft vier Identitaeten gegeneinander: Eigentuemer, Teamkollege,
Fremder, Anonym. Enthalten sind auch die drei Faelle, die beim Schreiben des
Schemas kaputt waren und erst der Test gefunden hat: Kontoloeschung bei
geteiltem Team, Teamaufloesung mit Team-Rezepten, und der Versuch des Clients,
sein eigenes Scan-Kontingent hochzusetzen.

Kontingente zaehlt ausschliesslich `consume_scan_quota` mit `service_role`.
Der Client hat auf `usage_quota` nur Leserecht.

## Formales, frueh statt spaet

- Kontoloeschung in der App ist Pflicht (Guideline 5.1.1(v)). `delete_account`
  existiert samt Test, inklusive Uebertragung von Team-Eigentum.
- `PrivacyInfo.xcprivacy` gehoert ins App-Target, ebenso muss das
  Supabase-Swift-SDK ein eigenes Privacy Manifest mitbringen.
- Sign in with Apple ist bei uns nicht durch Guideline 4.8 erzwungen, weil kein
  Social-Login angeboten wird. Es kommt trotzdem, weil es der reibungsaermste
  Login auf iOS ist.
- DSGVO: EU-Region bei Supabase, AVV abschliessen, Datenschutzerklaerung und
  Impressum brauchen eine oeffentliche URL.
- Apple Developer Program ist kostenpflichtig, auch fuer kostenlose Apps.

## Entwicklung

```
scripts/test-migrations.sh          Migrationen, Seeds, RLS-Tests gegen Postgres 17
cd Packages/CoreKit && swift test   Einheiten- und Parsertests
```

Beide muessen vor jedem Commit gruen sein.
