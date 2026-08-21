#!/bin/sh
# Baut die App, installiert sie im Simulator und startet sie.
# Optionales Argument: Startreiter (cookbook | search | learning | profile).
#
# Legt bei Bedarf ein Simulator-Geraet an. Notwendig, weil Geraete verschwinden
# koennen, wenn CoreSimulator-Daten aufgeraeumt werden -- simctl meldet dann
# "cannot be located on disk" und das Geraet ist eine Karteileiche.

set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

BUNDLE_ID="de.lernkueche.app"
DEVICE_NAME="Lernkueche iPhone"
TAB="${1:-cookbook}"

if [ ! -d "Lernkueche.xcodeproj" ]; then
  echo "==> Xcode-Projekt erzeugen"
  xcodegen generate
fi

RUNTIME=$(xcrun simctl list runtimes | grep "^iOS" | tail -1 | sed -E 's/.*(com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+).*/\1/')
if [ -z "$RUNTIME" ]; then
  echo "Keine iOS-Simulator-Laufzeit gefunden. In Xcode unter Settings > Components nachinstallieren."
  exit 1
fi

DEVICE=$(xcrun simctl list devices | grep "$DEVICE_NAME" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')

# Geraet existiert, aber Daten fehlen: wegwerfen und neu anlegen.
if [ -n "$DEVICE" ] && [ ! -d "$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE/data" ]; then
  echo "==> Geraet $DEVICE hat keine Daten mehr, wird ersetzt"
  xcrun simctl delete "$DEVICE" >/dev/null 2>&1 || true
  DEVICE=""
fi

if [ -z "$DEVICE" ]; then
  echo "==> Simulator anlegen"
  DEVICE=$(xcrun simctl create "$DEVICE_NAME" "iPhone 17 Pro" "$RUNTIME")
fi

echo "==> Geraet $DEVICE"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
open -a Simulator

echo "==> Bauen"
xcodebuild -project Lernkueche.xcodeproj -scheme Lernkueche \
  -destination "id=$DEVICE" -configuration Debug \
  -derivedDataPath .build/dd build CODE_SIGNING_ALLOWED=NO \
  | grep -E "error:|BUILD" || true

APP=".build/dd/Build/Products/Debug-iphonesimulator/Lernkueche.app"
if [ ! -d "$APP" ]; then
  echo "Build hat kein App-Bundle erzeugt."
  exit 1
fi

echo "==> Installieren und starten (Reiter: $TAB)"
xcrun simctl install "$DEVICE" "$APP"
# simctl reicht nur Variablen mit dem Praefix SIMCTL_CHILD_ an die App weiter.
SIMCTL_CHILD_LK_INITIAL_TAB="$TAB" \
  xcrun simctl launch --terminate-running-process "$DEVICE" "$BUNDLE_ID"
