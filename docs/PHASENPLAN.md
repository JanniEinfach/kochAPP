# Phasenplan

Reihenfolge geaendert gegenueber dem ersten Entwurf. Begruendung: die erste
echte Nutzerin ist eine Auszubildende. Gebaut wird, was sie im Betrieb und in
der Berufsschule benutzt, nicht was ein spaeterer Discovery-Feed braeuchte.

| Phase | Inhalt | Fertig, wenn |
|---|---|---|
| 1 | Datenbank, RLS, Tests, Kernlogik | erledigt, siehe unten |
| 2 | Xcode-Projekt, Auth, Kontoloeschung, Design-Tokens, Tab-Geruest | Login auf dem Geraet, Konto in der App loeschbar |
| 3 | Vertikalschnitt Rezept: anlegen, Liste, Detail, Kochmodus, offline | ein Rezept ohne Netz nachkochbar |
| 4 | Sync-Engine: Outbox, Pull, Tombstones, Konflikte | zwei Geraete, Flugmodus, keine Datenverluste |
| 5 | Scanpipeline: Kamera, OCR, Edge Function, Pruefansicht | Papierrezept in unter 60 Sekunden sauber erfasst |
| 6 | Suche und Auto-Kategorisierung | Zutatensuche liefert brauchbare Treffer |
| 7 | Lernkueche: Fachbegriffe, FSRS, Fachrechnen, Berichtsheft | eine Woche sinnvoll damit lernbar |
| 8 | Barrierefreiheit, Dynamic Type, VoiceOver, Performance, TestFlight | Build in TestFlight |

## Phase 1, erledigt

- Sieben Migrationen, gegen Postgres 17 eingespielt und geprueft
- RLS auf allen Tabellen, 16 Pruefungen gruen, vier Identitaeten getestet
- Seeds: 14 LMIV-Allergene, 7 Taxonomie-Achsen, Quellenregister
- `IngredientLineParser`, `NumberTokenizer`, `PortionScaler`, `TextNormalizer`
  mit 58 Unit-Tests
- Testlaeufe: `scripts/test-migrations.sh` und `swift test`

### Drei Fehler, die erst der Test gefunden hat

1. `unaccent()` ist nicht immutable und taugt nicht fuer eine generated column.
   Ersetzt durch `public.normalize_text`, gespiegelt in Swift.
2. Kontoloeschung scheiterte, sobald der Nutzer ein Team besass, in dem noch
   andere Admins waren. `delete_account` uebertraegt jetzt das Eigentum.
3. Teamaufloesung zog Team-Rezepte in einen vom Check-Constraint verbotenen
   Zustand. Ein Trigger stellt sie stattdessen auf privat zurueck.

## Was noch von aussen kommen muss

- Supabase-Projekt in der EU-Region, Zugangsdaten in `.env`
- Bundle Identifier, sobald der Produktname steht
- Command Line Tools aktualisieren, sonst faellt die Supabase CLI aus
- pgvector fehlt lokal: `vector`-Spalte und HNSW-Index sind bisher nur beim
  ersten Deploy gegen Supabase pruefbar
