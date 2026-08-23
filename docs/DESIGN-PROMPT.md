# Design-Direktive

Zum Kopieren in ein anderes Werkzeug, wenn dort ein Entwurf auf diese
Gestaltung umgestellt werden soll. Die Werte sind die tatsaechlich in
`Packages/DesignSystem/Sources/DesignSystem/Tokens/` verwendeten und durch
`AppTests/PaletteContrastTests.swift` gegen WCAG AA abgesichert.

Überarbeite das bestehende Design nach der folgenden Direktive. Ändere die
Gestaltung, nicht den Funktionsumfang: gleiche Screens, gleiche Inhalte,
gleiche Navigation.

## Haltung

Zurückhaltung mit einer klaren Meinung. Das Vorbild ist ein gut gesetztes
Fachbuch, nicht ein Dashboard. Wenige Farben, viel Weißraum, Hierarchie
über Schriftgröße und Abstand statt über Rahmen, Schatten und Boxen.

Vermeide konsequent: Farbverläufe als Dekoration, bunte Icon-Kacheln,
Glassmorphismus, Schlagschatten zur Betonung, überall gleiche Kartenraster,
Emoji als Bedienelemente, mehr als eine Akzentfarbe pro Bereich.

Eine Fläche ist erst dann eine Karte, wenn sie sich vom Hintergrund abheben
muss. Im Zweifel: kein Rahmen, nur Abstand.

## Farbe

Der Grundton ist warmes Off-White, nie reines Weiß. Reines Weiß wirkt klinisch
und lässt jede Fläche gleich wichtig aussehen.

Hell:
  Grundfläche          #FAF8F4
  erhöhte Fläche       #FFFEFC   (Karten, Blätter, Bottom Sheets)
  vertiefte Fläche     #F2EFE9   (Eingabefelder, Listenblöcke)
  Text primär          #1D1914
  Text sekundär        #60584D
  Text tertiär         #736B61
  Trennlinie           #E0DBD3

Dunkel:
  Grundfläche          #161514
  erhöhte Fläche       #211F1D
  vertiefte Fläche     #0E0D0C
  Text primär          #F4F2EE
  Text sekundär        #ADA8A0
  Text tertiär         #8B8780
  Trennlinie           #35322F

Genau eine Akzentfarbe pro Bereich, nicht pro Bildschirm:

  Bereich A (warm, inhaltsnah)   hell #BD4D29   dunkel #E0734D
  weicher Hintergrund dazu       hell #F8E8E0   dunkel #3D251C

  Bereich B (kühl, sachlich)     hell #1B656F   dunkel #5DAFB8
  weicher Hintergrund dazu       hell #E2EFF0   dunkel #142E32

Zustände, sparsam eingesetzt:
  Erfolg   hell #387942   dunkel #6FB47A
  Warnung  hell #966913   dunkel #E5B142
  Fehler   hell #AA2E28   dunkel #E1665D

Bindende Regel: Jede Textfarbe muss gegen ihre Fläche mindestens 4,5:1
erreichen, in beiden Erscheinungsbildern. Rechne das nach, statt es zu
schätzen. Farben, die diese Schwelle nur knapp reißen, werden abgedunkelt,
nicht durchgewinkt.

Wenn die Anwendung zwei inhaltlich verschiedene Hälften hat, bekommt jede
ihre eigene Akzentfarbe, und die Navigationsleiste färbt sich beim Wechsel um.
Zwei Räume in einem Haus, nicht zwei Häuser.

Kein automatischer Dunkelmodus als Standardlook. Beide Erscheinungsbilder
werden gepflegt, aber das helle ist die Absicht.

## Typografie

Zwei Familien mit klarer Aufgabenteilung. Was gelesen wird, läuft in einer
Serifenschrift: Überschriften von Inhalten, längere Fließtexte. Was bedient
wird, läuft serifenlos: Schaltflächen, Beschriftungen, Navigation, Formulare.

Zahlen in Listen und Tabellen bekommen Tabellenziffern, damit sie
untereinander stehen und beim Aktualisieren nicht springen.

Der Größensprung zwischen den Stufen muss deutlich sein. Wenn Überschrift und
Fließtext ähnlich groß sind, entsteht keine Hierarchie, sondern Grauwert.

Alle Größen binden an die Systemschriftgröße. Wer sie größer stellt, hat einen
Grund. Feste Punktgrößen nur dort, wo die Situation es erzwingt.

## Rhythmus

Abstände sind bewusst ungleichmäßig. Gleiche Polsterung überall lässt jede
Oberfläche wie eine Vorlage aussehen.

   4  zwischen unmittelbar Zusammengehörigem, etwa Beschriftung und Wert
   8  eng
  12  innerhalb einer Gruppe
  16  Innenabstand von Karten
  20  Seitenrand
  32  zwischen zwei Gruppen
  48  zwischen zwei Abschnitten

Ecken: 6 für Kleinteile, 14 für Karten, 24 für Blätter, voll rund für Chips.

Trefferflächen mindestens 44 Punkt. Dort, wo unter erschwerten Bedingungen
bedient wird, 64.

## Bewegung

  120 ms  Rückmeldung auf eine Berührung
  240 ms  Standardübergang
  Feder mit Antwortzeit 0,38 und Dämpfung 0,86 für Blätter

Bewegung erklärt, woher etwas kommt und wohin es geht. Sie ist nie Dekoration.
Ist im System reduzierte Bewegung aktiviert, entfällt die Animation ganz statt
abgeschwächt zu werden.

## Leere Zustände

Ein leerer Bereich sagt, was hier entstehen wird. Ein einzelnes Symbol in der
Akzentfarbe, darunter ein Satz in der sekundären Textfarbe, zentriert, viel
Luft. Keine Illustration, kein aufgedrängter Aufruf zum Handeln.

## Automatisch Erzeugtes kennzeichnen

Werte, die eine Maschine erkannt oder geschätzt hat, tragen eine dezente
Kennzeichnung in der Warnfarbe, nicht in der Fehlerfarbe, und ohne Warnsymbol.
Es ist kein Fehler, sondern die Bitte um einen zweiten Blick. Wer hier Alarm
signalisiert, erzieht Nutzer dazu, die Prüfung wegzuklicken.

Stehen Werte aus mehreren Quellen nebeneinander, wird die Quelle benannt und
nie zu einem gemeinsamen Durchschnitt verrechnet.

## Zum Schluss

Prüfe deinen Entwurf gegen diese drei Fragen. Fällt eine Antwort negativ aus,
überarbeite ihn, statt ihn zu erklären.

1. Sähe das in einer echten Produktaufnahme glaubwürdig aus, oder wie eine
   Vorlage mit ausgetauschten Texten?
2. Erkennt man die Hierarchie beim Zusammenkneifen der Augen, wenn nur noch
   Grauwerte und Flächen übrig bleiben?
3. Erreicht jede Textfarbe nachgerechnet 4,5:1 gegen ihre Fläche, in hell
   und in dunkel?
