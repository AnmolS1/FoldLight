#!/bin/bash
# Capture the four App Store listing screenshots for the macOS app.
#
# Launches the built .app with `--uitest-screenshots --screen <name>` once per
# screen, grabs the window (frameless, no shadow) via screencapture, and composites
# it centered onto an opaque 2880x1800 canvas.
#
# IMPORTANT: unlike the iPhone script, the Mac app writes to your REAL App Group
# container (group.dev.ponderance.foldlight). Mock-mode seeding overwrites presets,
# launchers, light-prefs and the connection URL. This script backs those up and
# restores them afterward — BUT the Home Assistant long-lived token lives in the
# data-protection Keychain, which cannot be backed up; it is cleared and you must
# re-enter it in the app's Settings after running this.
#
# Requires: Screen Recording permission for your terminal (System Settings →
# Privacy & Security → Screen Recording). Output: fastlane/screenshots/mac/.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
APP="$REPO/ios/build/dd-mac/Build/Products/Debug/FoldLight.app"
EXEC="$APP/Contents/MacOS/FoldLight"
OUT="$REPO/fastlane/screenshots/mac"
BG="${BG:-13202A}"   # dark blueprint ground; use EEF0EC if your Mac is in light appearance
TMP="$(mktemp -d)"
GC="$HOME/Library/Group Containers/group.dev.ponderance.foldlight"
DOMAIN="$GC/Library/Preferences/group.dev.ponderance.foldlight"

mkdir -p "$OUT"

if [ ! -d "$APP" ]; then
  echo "Building macOS app…"
  ( cd "$REPO/ios" && xcodegen generate >/dev/null && \
    xcodebuild -project FoldLight.xcodeproj -scheme FoldLight -configuration Debug \
      -destination 'platform=macOS' -derivedDataPath build/dd-mac build >/dev/null )
fi

quit_dev () { pkill -f "$EXEC" 2>/dev/null || true; sleep 1; }

# --- Back up the real App Group data before seeding overwrites it. ---
quit_dev
BK="$TMP/gc-backup"; mkdir -p "$BK"
cp "$GC"/*.json "$BK/" 2>/dev/null || true
defaults export "$DOMAIN" "$BK/prefs.plist" 2>/dev/null || true
restore () {
  quit_dev
  cp "$BK"/*.json "$GC/" 2>/dev/null || true
  [ -f "$BK/prefs.plist" ] && defaults import "$DOMAIN" "$BK/prefs.plist" 2>/dev/null || true
  echo "Restored App Group data. NOTE: re-enter your Home Assistant token in Settings"
  echo "      (the Keychain token was cleared by mock mode and can't be auto-restored)."
}
trap restore EXIT

capture () {
  local screen="$1" file="$2"
  echo "→ $screen -> $file"
  quit_dev
  open -n "$APP" --args --uitest-screenshots --screen "$screen"
  sleep 5
  local wid; wid=$(swift "$HERE/windowid.swift" FoldLight 2>/dev/null)
  [ -n "$wid" ] || { echo "  !! no window id — is Screen Recording granted to your terminal?"; return 1; }
  screencapture -o -x -l "$wid" "$TMP/$file"
  swift "$HERE/normalize.swift" "$TMP/$file" "$OUT/$file" 2880 1800 "$BG"
}

capture editor   "01LightEditor.png"
capture presets  "02PresetLibrary.png"
capture panel    "03Panel.png"
capture settings "04Settings.png"

echo "=== dimensions ==="
for f in "$OUT"/0*.png; do
  printf "%s  " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2} END{print ""}'
done
