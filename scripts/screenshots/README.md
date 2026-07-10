# App Store screenshot capture

Regenerates the App Store Connect listing screenshots for FoldLight on iPhone, iPad,
and Mac, using deterministic mock data (never your real Home Assistant install).

## How it works

The app has a `--uitest-screenshots` launch argument (see
`ios/App/ScreenshotSupport.swift`), gated so production builds are unaffected. When
present it forces mock mode, blanks any host/token, dismisses onboarding, and seeds
the preset library + fake `.local` launcher tiles. `--screen editor|presets|panel|
settings` selects which screen to show. The capture scripts relaunch the app once
per screen and grab a native-resolution frame.

Each script captures three screens — **editor** (colored bulb + color controls),
**panel** (launcher tiles), and **settings** (mock connection state). The app also
supports `--screen presets` (the editor in White mode) if you want a fourth.

On iPad the app applies a layout pass (`RootView`'s `iPadColumn`) that caps the
content width and centers it, so the phone-style UI reads as intentional.

No fastlane, no UI-test target — just `simctl` (iPhone/iPad) and `screencapture` + a
small Swift compositor (Mac).

## Run

```bash
scripts/screenshots/capture_iphone.sh   # → fastlane/screenshots/       (1284×2778, opaque)
scripts/screenshots/capture_ipad.sh     # → fastlane/screenshots/ipad/  (2064×2752, opaque)
scripts/screenshots/capture_mac.sh      # → fastlane/screenshots/mac/   (2880×1800, opaque)
```

All build the app first if needed. Overrides: `DEVICE=...` for the iPhone/iPad
device; `TARGET_W`/`TARGET_H` for the iPhone output size (default 1284×2778, the
6.5"/6.7" slot size — set `TARGET_W=1320 TARGET_H=2868` to keep the native 6.9"
size); `BG=EEF0EC` for the Mac script if your Mac is in light appearance.

The Mac script needs **Screen Recording** permission for your terminal
(System Settings → Privacy & Security → Screen Recording).

## ⚠️ macOS side effect

The iPhone run is fully isolated (simulator container). The **Mac** run writes to the
real App Group container. The script backs up and restores presets/launchers/
light-prefs/URL automatically, but the Home Assistant **long-lived token** lives in
the data-protection Keychain and cannot be backed up — it is cleared, so
**re-enter it in the app's Settings after running the Mac capture.**

## Helpers

- `windowid.swift` — prints the CGWindowID of the app's main window (for `screencapture -l`)
- `normalize.swift` — composites a capture onto an opaque `W×H` canvas (scales, centers, flattens)
- `flatten.swift` — strips the alpha channel from a PNG (App Store Connect rejects alpha)
