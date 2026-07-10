# App Store screenshot capture

Regenerates the App Store Connect listing screenshots for FoldLight on iPhone and
Mac, using deterministic mock data (never your real Home Assistant install).

## How it works

The app has a `--uitest-screenshots` launch argument (see
`ios/App/ScreenshotSupport.swift`), gated so production builds are unaffected. When
present it forces mock mode, blanks any host/token, dismisses onboarding, and seeds
the preset library + fake `.local` launcher tiles. `--screen editor|presets|panel|
settings` selects which screen to show. The capture scripts relaunch the app once
per screen and grab a native-resolution frame.

No fastlane, no UI-test target — just `simctl` (iPhone) and `screencapture` + a
small Swift compositor (Mac).

## Run

```bash
scripts/screenshots/capture_iphone.sh   # → fastlane/screenshots/       (1320×2868, opaque)
scripts/screenshots/capture_mac.sh      # → fastlane/screenshots/mac/   (2880×1800, opaque)
```

Both build the app first if needed. Overrides: `DEVICE="iPhone 17 Pro Max"` for the
iPhone script; `BG=EEF0EC` for the Mac script if your Mac is in light appearance.

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
