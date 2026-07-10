#!/bin/bash
# Capture the App Store listing screenshots on an iPhone simulator.
#
# Drives the app's `--uitest-screenshots --screen <name>` launch argument (see
# ios/App/ScreenshotSupport.swift): forces mock mode, seeds presets + fake launcher
# tiles, blanks any host/token, then relaunches once per screen and grabs a native
# resolution PNG. Runs entirely on the simulator's isolated container — it never
# touches your real Home Assistant install or the macOS app's data.
#
# The Pro Max captures natively at 1320x2868 (6.9"); each shot is then cover-scaled
# and center-cropped to TARGET_W x TARGET_H — 1284x2778 by default, which is the
# size App Store Connect's 6.5"/6.7" iPhone slot accepts. Override the target env
# vars to keep the native 6.9" size (TARGET_W=1320 TARGET_H=2868).
#
# Output: fastlane/screenshots/0{1..3}*.png (portrait, opaque).
set -euo pipefail

TARGET_W="${TARGET_W:-1284}"
TARGET_H="${TARGET_H:-2778}"

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
  # Cover-scale to target width, center-crop to target height (uniform scale, no
  # distortion), then flatten — simctl PNGs carry an alpha channel and ASC rejects it.
  sips --resampleWidth "$TARGET_W" "$OUT/$file" >/dev/null
  sips -c "$TARGET_H" "$TARGET_W" "$OUT/$file" >/dev/null
  swift "$HERE/flatten.swift" "$OUT/$file"
}

capture editor   "01LightEditor.png"
capture panel    "02Panel.png"
capture settings "03Settings.png"

echo "=== dimensions ==="
for f in "$OUT"/0*.png; do
  printf "%s  " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2} END{print ""}'
done
