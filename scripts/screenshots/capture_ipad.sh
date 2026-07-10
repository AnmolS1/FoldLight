#!/bin/bash
# Capture the App Store listing screenshots on a 13" iPad simulator.
#
# Same launch-arg mechanism as capture_iphone.sh (see ios/App/ScreenshotSupport.swift),
# on an iPad Pro 13" whose native 2064x2752 is an accepted 13" iPad size — no resize
# needed. The app has an iPad-only layout pass (RootView's `iPadColumn`) that caps
# the content width and centers it. Simulator-only: never touches real data.
#
# Output: fastlane/screenshots/ipad/0{1..3}*.png (2064x2752, portrait, opaque).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
APP="$REPO/ios/build/dd-ios/Build/Products/Debug-iphonesimulator/FoldLight.app"
BUNDLE="dev.ponderance.foldlight"
OUT="$REPO/fastlane/screenshots/ipad"
DEVICE="${DEVICE:-iPad Pro 13-inch (M4)}"   # native 2064x2752

mkdir -p "$OUT"

# Build (and regenerate the project) if the simulator app product is missing.
if [ ! -d "$APP" ]; then
  echo "Building simulator app…"
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
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryLevel 100 --batteryState charged \
  --wifiBars 3 --cellularBars 4 --dataNetwork wifi 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

# Warm-up so the one-time Apple Intelligence banner clears.
xcrun simctl launch "$UDID" "$BUNDLE" --uitest-screenshots --screen editor >/dev/null
sleep 12
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

capture () {
  local screen="$1" file="$2"
  echo "→ $screen -> $file"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" \
    --uitest-screenshots --screen "$screen" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$file" >/dev/null
  swift "$HERE/flatten.swift" "$OUT/$file"   # strip the alpha channel ASC rejects
}

capture editor   "01LightEditor.png"
capture panel    "02Panel.png"
capture settings "03Settings.png"

echo "=== dimensions ==="
for f in "$OUT"/0*.png; do
  printf "%s  " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2} END{print ""}'
done
