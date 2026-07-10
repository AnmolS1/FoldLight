#!/bin/bash
# Capture the four App Store listing screenshots on an iPhone simulator.
#
# Drives the app's `--uitest-screenshots --screen <name>` launch argument (see
# ios/App/ScreenshotSupport.swift): forces mock mode, seeds presets + fake launcher
# tiles, blanks any host/token, then relaunches once per screen and grabs a native
# resolution PNG. Runs entirely on the simulator's isolated container — it never
# touches your real Home Assistant install or the macOS app's data.
#
# Output: fastlane/screenshots/0{1..4}*.png (6.9" Pro Max, portrait, opaque).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
APP="$REPO/ios/build/dd-ios/Build/Products/Debug-iphonesimulator/FoldLight.app"
BUNDLE="dev.ponderance.foldlight"
OUT="$REPO/fastlane/screenshots"
DEVICE="${DEVICE:-iPhone 17 Pro Max}"   # override with DEVICE=... ; newest Pro Max auto-satisfies 6.9"

mkdir -p "$OUT"

# Build (and regenerate the project) if the app product is missing.
if [ ! -d "$APP" ]; then
  echo "Building $DEVICE app…"
  ( cd "$REPO/ios" && xcodegen generate >/dev/null && \
    xcodebuild -project FoldLight.xcodeproj -scheme FoldLight -sdk iphonesimulator \
      -configuration Debug -destination "platform=iOS Simulator,name=$DEVICE" \
      -derivedDataPath build/dd-ios build >/dev/null )
fi

UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F-]+' | head -1)
[ -n "$UDID" ] || { echo "No available simulator named '$DEVICE'"; exit 1; }
echo "Device: $DEVICE  udid=$UDID"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
# Clean, store-style status bar.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryLevel 100 --batteryState charged \
  --wifiBars 3 --cellularBars 4 --dataNetwork wifi
xcrun simctl install "$UDID" "$APP"

# Warm-up: let the one-time "Ready for Apple Intelligence" system banner appear and
# drop into Notification Center before we start capturing.
xcrun simctl launch "$UDID" "$BUNDLE" --uitest-screenshots --screen editor >/dev/null
sleep 12
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

capture () {
  local screen="$1" file="$2"
  echo "→ $screen -> $file"
  # --terminate-running-process so the new --screen arg actually takes effect.
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" \
    --uitest-screenshots --screen "$screen" >/dev/null
  sleep 3.5
  xcrun simctl io "$UDID" screenshot "$OUT/$file" >/dev/null
  swift "$HERE/flatten.swift" "$OUT/$file"   # simctl PNGs carry an alpha channel; ASC rejects it
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
