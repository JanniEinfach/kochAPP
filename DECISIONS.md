# Architekturentscheidungen

Format: Kontext, Entscheidung, Konsequenz. Neue Entscheidungen werden angehaengt,
alte nicht geloescht, sondern als abgeloest markiert.

## ADR-1 Native SwiftUI statt Cross-Platform

**Kontext.** Die Kernfeatures sind Dokumentenscanner, On-Device-OCR, ein
Vollbild-Kochmodus mit Hintergrundtimern und Live Activities. Alles davon liegt
auf iOS-Systemebene.

**Entscheidung.** SwiftUI nativ. Deployment Target iOS 18, nicht iOS 17.
Swift 6 Language Mode paketweise, nicht global auf einen Schlag.

**Konsequenz.** Keine Android-Version ohne Zweitentwicklung. Dafuer volle
Systemintegration ohne Bridge-Wartung. iOS 18 statt 17 spart die SwiftData-Bugs
der ersten Generation und macht die Concurrency-Migration beherrschbar.
Offen: Geraeteabdeckung der Zielgruppe pruefen, Azubis haben oft aeltere iPhones.

## ADR-2 GRDB als lokale Wahrheit, nicht SwiftData

**Kontext.** Offline-first mit rund zwanzig synchronisierten Tabellen, lokaler
Volltextsuche, Sync-Outbox, Konfliktaufloesung und deterministischen Migrationen
ueber App-Versionen hinweg.

**Entscheidung.** GRDB.swift auf SQLite.

**Begruendung.** SwiftData verbirgt das SQL-Schema, was Migrationen bei einem
Modell dieser Groesse zum Gluecksspiel macht. Es gibt keinen Zugriff auf FTS5,
den die Offline-Suche braucht. Es kennt kein "lokal geaendert, noch nicht
gepusht" ausser ueber kuenstliche Flags. Und Sync-Fehler sind praktisch nicht
diagnostizierbar, weil man nicht in den Store sehen kann. GRDB liefert SQL,
Migrationen als Code, FTS5, ValueObservation fuer SwiftUI und eine Datei, die
sich mit jedem SQLite-Browser oeffnen laesst.

**Konsequenz.** Mehr Mapping-Boilerplate zwischen Record und Model. Dafuer ist
die Sync-Engine ueberhaupt baubar und debuggbar. Ein spaeterer Wechsel bleibt
auf PersistenceKit beschraenkt, weil Features nur Repository-Protokolle sehen.

## ADR-3 Supabase nutzen, aber nicht daran festwachsen

**Kontext.** Free Tier startklar, aber Skalierungskosten und ein moeglicher
Umzug auf eigene Hardware stehen im Raum.

**Entscheidung.** Supabase-Spezifisches ausschliesslich in RemoteKit.
Fremdschluessel zeigen auf `profiles`, nie auf `auth.users`. Storage-Pfade
werden relativ gespeichert, nie als vollstaendige URL. Rechtevergabe steht
explizit in Migration 007 statt sich auf Supabase-Defaults zu verlassen.
Edge Functions bleiben schlanke HTTP-Handler.

**Konsequenz.** Ein Umzug auf eigenes Postgres bedeutet: Schema bleibt,
RLS-Policies bleiben, RemoteKit und Auth werden ersetzt. Realistisch zwei bis
drei Wochen statt Rewrite. Preis: einige Bequemlichkeiten entfallen.

## ADR-4 Kanonische Zutaten als eigene Entitaet

**Kontext.** Zutatensuche, Allergenableitung, Ruestverluste und Kalkulation
brauchen dieselbe normalisierte Zutat. Deutscher Volltext zerlegt keine
Komposita: "Hackfleisch" findet "Fleisch" nicht.

**Entscheidung.** `ingredients` mit kuratiertem Grundstock, dazu
`ingredient_aliases`, `ingredient_yields`, `ingredient_prices` und
`ingredient_allergens`. `recipe_ingredients.raw_text` bleibt immer erhalten und
wird angezeigt. `ingredient_id` ist nullable.

**Konsequenz.** Kurations- und Aufloesungsaufwand. Dafuer funktionieren
Zutatensuche, Allergene und der gesamte Fachrechnen-Generator ueberhaupt erst.
Nicht aufgeloeste Zutaten degradieren sauber statt zu blockieren.

## ADR-5 Scan: Vision-LLM serverseitig, On-Device-OCR daneben, Review immer

**Kontext.** Papierrezepte sind haeufig handschriftlich, mehrspaltig, mit
Randnotizen. Reines OCR liefert dabei Zeichensalat, und ein Sprachmodell, das
nur diesen Salat sieht, halluziniert Struktur hinein.

**Entscheidung.** On-Device-OCR laeuft immer und sofort und traegt den
Offline-Fall. Fuer die Strukturierung gehen Bild und OCR-Text gemeinsam an eine
Edge Function. Das Ergebnis geht nie ohne Review-Screen in die Datenbank.
Mengen laufen nach dem LLM-Schritt zusaetzlich durch `IngredientLineParser`,
dessen Ergebnis bei Konflikt gewinnt und die Konfidenz setzt.

**Konsequenz.** Hoehere Kosten pro Scan. Gegenmassnahmen: Downscaling, harte
Quota in `usage_quota`, Ergebnis-Caching ueber `scan_jobs.content_hash`.
Der Scan verlaesst das Geraet, das gehoert ins Onboarding, nicht ins
Kleingedruckte.

## ADR-6 Externe Rezepte: nur lizenzierte APIs plus nutzerinitiierter Import

**Kontext.** Rezepte aus dem Netz in die Suche zu mischen kollidiert mit
Nutzungsbedingungen, robots.txt und dem Urheberrecht am Zubereitungstext.

**Entscheidung.** Kein serverseitiges Crawlen. Nur zwei Pfade: Quellen mit
ausdruecklicher API-Lizenz, und nutzerinitiierter JSON-LD-Import, der per
Check-Constraint zwingend `visibility = 'private'` traegt.

**Konsequenz.** Der Discovery-Feed ist duenn und faellt in v1 ganz weg.
Die inhaltliche Tiefe kommt aus dem eigenen Kochbuch. Das passt zur Kernthese:
der Wert liegt im eigenen Bestand und im Lernen.

## ADR-7 Keine oeffentlichen Inhalte in v1

**Kontext.** Ein erheblicher Teil der Zielgruppe ist minderjaehrig. Oeffentliche
nutzergenerierte Inhalte ziehen Moderationspflicht, Meldefunktion, Blockieren,
Jugendschutz und Haftung fuer fremde Inhalte nach sich. Zusammen mit DSGVO
Art. 8 waere das ein eigenes Teilprojekt.

**Entscheidung.** `visibility` kennt den Wert `public` im Enum, ein
Check-Constraint verbietet ihn. Kein Geburtsdatum, keine Altersabfrage, keine
Fremdkontakte. Was nicht erhoben wird, muss nicht geschuetzt werden.

**Konsequenz.** Kein Community-Effekt in v1. Dafuer entfaellt der komplette
Moderations- und Jugendschutzaufwand, und die Datenschutzerklaerung bleibt kurz.
Der Constraint faellt, wenn `public` bewusst eingefuehrt wird.

## ADR-8 Teams im Schema ab Tag eins, in der Oberflaeche spaeter

**Kontext.** Der zahlende Kunde ist spaeter der Ausbildungsbetrieb, nicht der
Azubi. Wird das Rollenmodell nachgeruestet, muessen RLS und Sync neu geschrieben
werden. Gleichzeitig ist die erste echte Nutzerin eine einzelne Auszubildende,
fuer die Team-UI wertlos waere.

**Entscheidung.** Jeder Datensatz traegt `owner_id` und optional `team_id`, die
RLS-Policies sind vollstaendig fuer Teams ausgelegt und getestet. Die
Team-Oberflaeche kommt erst, wenn ein realer Betrieb testet.

**Konsequenz.** Etwas mehr Aufwand in den Policies, dafuer kein Rewrite.
Der Test `20_rls.sql` deckt Teamfaelle bereits ab, obwohl noch keine UI existiert.

## ADR-9 Betriebsmodell: Cloud bis TestFlight, danach eigene Hardware

**Kontext.** Vorhanden ist ein Windows-VPS in Deutschland mit fester IP.
Der Wunsch nach Unabhaengigkeit von einem Cloud-Anbieter ist berechtigt.
Gleichzeitig sind bereits zwei fruehere Server dieses Projektumfelds
ausgefallen, und abfotografierte Familienrezepte sind nicht wiederherstellbar.

**Entscheidung.** Supabase Cloud in der EU-Region bis einschliesslich
TestFlight. Danach Umzug auf eigene Hardware, dann aber auf Linux, nicht
Windows: die Supabase-Bausteine sind Linux-Container und brauchen auf Windows
Server verschachtelte Virtualisierung, die auf VPS haeufig fehlt.

MariaDB wird nicht verwendet. Begruendung in `docs/SELFHOSTING.md`.

**Konsequenz.** Abhaengigkeit von einem Anbieter bis zum Umzug, dafuer kein
Betriebsaufwand in der Bauphase. Der Umzug bleibt durch ADR-3 auf RemoteKit
und Hosting beschraenkt. Bedingung: Der Umzug findet vor breiter Verteilung
statt, weil ausgelieferte Installationen sonst auf die alte Instanz zeigen.
