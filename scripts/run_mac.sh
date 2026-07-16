#!/bin/bash
# Build the macOS app and INSTALL it to /Applications, then launch it.
#
# Why this exists (and why it differs from scripts/screenshots/capture_mac.sh):
# the macOS widget gallery (Notification Center → Edit Widgets) only surfaces a
# widget whose containing app is registered from a single, stable location. When
# the app is only ever run straight out of scattered `-derivedDataPath` build
# dirs (as the capture scripts do), Launch Services accumulates many competing
# registrations for bundle id `dev.ponderance.foldlight` and `chronod` can't pick
# a canonical host — so the FoldLight widget never shows up in the gallery.
#
# This script builds to ONE fixed derived-data path, replaces any prior copy in
# /Applications, bounces the widget daemon, and launches — giving chronod a single
# blessed host. Use THIS when you want to test the widget; use the capture scripts
# only for screenshots.
#
# One-time cleanup: if the gallery is already polluted with stale registrations,
# reset the Launch Services database first (safe; it rebuilds itself):
#   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
#     -kill -r -domain local -domain system -domain user
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
DD="$REPO/ios/build/dd-mac"
APP="$DD/Build/Products/Debug/FoldLight.app"

echo "→ Regenerating project + building macOS…"
( cd "$REPO/ios" && xcodegen generate >/dev/null && \
  xcodebuild -project FoldLight.xcodeproj -scheme FoldLight -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath build/dd-mac build >/dev/null )

[ -d "$APP" ] || { echo "!! build produced no app at $APP"; exit 1; }

echo "→ Installing to /Applications…"
# Quit any running copy so the replace/registration is clean.
pkill -f "$APP/Contents/MacOS/FoldLight" 2>/dev/null || true
osascript -e 'quit app "FoldLight"' 2>/dev/null || true
sleep 1
rm -rf /Applications/FoldLight.app
cp -R "$APP" /Applications/

# xcodebuild's RegisterWithLaunchServices step registers the build-dir copy too;
# unregister it so /Applications is the SOLE host chronod can pick for the widget.
LSR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSR" -u "$APP" 2>/dev/null || true
"$LSR" -f /Applications/FoldLight.app 2>/dev/null || true

echo "→ Refreshing the widget daemon…"
# Mark the extension used so it lands as '+' (active) rather than '!' in pluginkit,
# so it reliably shows in the gallery on a fresh install.
pluginkit -e use -i dev.ponderance.foldlight.widgets 2>/dev/null || true
killall chronod NotificationCenter 2>/dev/null || true

echo "→ Launching /Applications/FoldLight.app…"
open /Applications/FoldLight.app

echo
echo "Done. First launch registers the host + widget with chronod."
echo "Add it via: Notification Center → Edit Widgets → FoldLight → 'Light'."
echo "Verify:  pluginkit -m -p com.apple.widgetkit-extension | grep -i foldlight"
echo "         (expect a '+' status and a Path under /Applications/FoldLight.app)"
