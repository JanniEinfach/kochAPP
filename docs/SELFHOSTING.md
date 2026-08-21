# Umzug auf eigene Hardware

Der Wunsch ist von Anfang an eingeplant, nicht nachtraeglich angeflanscht.
Was diesen Umzug billig macht, steht in DECISIONS.md unter ADR-3.

## Warum nicht sofort

| Grund | Detail |
|---|---|
| Windows traegt keine Linux-Container | Supabase besteht aus Linux-Containern. Auf Windows Server braucht das WSL2 oder eine Hyper-V-Linux-VM, beides setzt verschachtelte Virtualisierung voraus. Ob der VPS-Anbieter die freischaltet, ist vorab zu klaeren. |
| Backups sind der eigentliche Aufwand | Abfotografierte Familienrezepte sind nicht wiederherstellbar. Selbst gehostet: taeglicher Dump, verschluesselt, ausser Haus, und mindestens einmal testweise zurueckgespielt. |
| Wartung kostet laufend | TLS-Erneuerung, Updates, Ueberwachung, Plattenplatz. |
| Ohne Nutzer kein Gewinn | Bis TestFlight traegt der Free Tier alles. |

## Was den Umzug billig haelt

Diese Regeln gelten ab sofort und werden bei jedem Commit eingehalten:

1. Supabase-Spezifisches liegt ausschliesslich in `Packages/RemoteKit`.
   Kein Feature-Paket importiert es.
2. Fremdschluessel zeigen auf `public.profiles`, nie auf `auth.users`.
   `profiles` ist unsere Tabelle und wandert unveraendert mit.
3. Storage-Pfade werden relativ gespeichert (`<user_id>/<datei>`), nie als
   vollstaendige URL. Ein Hostwechsel beruehrt keine einzige Datenzeile.
4. Rechtevergabe steht explizit in Migration 007, statt sich auf
   Supabase-Voreinstellungen zu verlassen.
5. Edge Functions sind schlanke HTTP-Handler ohne Plattformmagie und laufen
   auch hinter einem beliebigen Reverse Proxy.

Was beim Umzug unveraendert bleibt: das gesamte Schema, alle RLS-Policies,
alle Tests in `supabase/tests/`, alle Swift-Pakete ausser RemoteKit.

Was ersetzt werden muss: Hosting von Postgres, Auth, Storage und den
Edge Functions. Realistisch zwei bis drei Wochen inklusive Backupkonzept.

## Voraussetzungen, die vorab am VPS zu pruefen sind

- [ ] Laeuft auf dem Windows-VPS noch etwas Produktives?
      **Eine Neuinstallation loescht alles.** Vor jeder Aenderung sichern.
- [ ] Betriebssystemwechsel auf Ubuntu LTS im Anbieter-Panel moeglich?
- [ ] Mindestens 4 GB RAM, besser 8. Supabase self-hosted startet rund
      ein Dutzend Container.
- [ ] Feste IPv4 vorhanden (bestaetigt) und Ports 80/443 erreichbar.
- [ ] Eine Domain, auf die ein A-Record zeigt. Ohne Domain kein gueltiges
      HTTPS-Zertifikat, und ohne gueltiges Zertifikat verweigert iOS die
      Verbindung. Selbstsignierte Zertifikate sind keine Option.
- [ ] Wohin gehen die Backups? Nicht auf denselben Server.

## Ablauf, wenn es soweit ist

1. Ubuntu LTS aufsetzen, SSH auf Schluessel umstellen, Passwortlogin aus,
   Firewall auf 22/80/443.
2. Docker und Compose installieren.
3. Supabase self-hosted aufsetzen, alle Standardpasswoerter und JWT-Secrets
   ersetzen. Die mitgelieferten Werte sind oeffentlich bekannt.
4. Reverse Proxy mit automatischem Zertifikat davor.
5. Migrationen einspielen: dieselben Dateien aus `supabase/migrations/`,
   danach `scripts/test-migrations.sh` gegen die neue Instanz.
6. Daten uebernehmen: `pg_dump` aus der Cloud, einspielen, Storage-Objekte
   kopieren. Pfade bleiben gleich, weil sie relativ gespeichert sind.
7. Backups einrichten **und einmal zurueckspielen.**
8. In der App nur `SUPABASE_URL` und `SUPABASE_ANON_KEY` tauschen.
   Ein App-Update ist noetig, alte Installationen zeigen sonst weiter auf
   die alte Instanz. Deshalb: Umzug vor breiter Verteilung, nicht danach.

## Warum nicht MariaDB

Zur Vollstaendigkeit, weil die Frage aufkam:

- **Kein Row Level Security.** Jede Zugriffspruefung muesste in
  Anwendungscode. Das Sicherheitsnetz, das in `supabase/tests/20_rls.sql`
  bereits drei Fehler gefunden hat, gaebe es dort nicht.
- **Keine deutsche Volltextsuche mit Stammformreduktion.** MariaDBs FULLTEXT
  kennt kein Stemming, "gebraten" und "braten" waeren verschiedene Woerter.
- **Kein Auth, kein Storage, keine Funktionsebene.** Das waere ein selbst
  gebautes Backend von sechs bis zehn Wochen, und selbst gebaute
  Authentifizierung ist die haeufigste Quelle von Sicherheitsluecken.

MariaDB hat seit 11.7 einen Vektortyp, semantische Suche waere also moeglich.
Die drei Punkte oben bleiben davon unberuehrt.
