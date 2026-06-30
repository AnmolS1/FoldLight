# FoldLight — Pass 1 handoff

Widget-first Home Assistant **light** controller for iOS + macOS, blueprint style.
This is the MVP spine. Read this top-to-bottom to resume in a fresh context.

## What's built (Pass 1) — compiles + 19 unit tests green

**Project** (`ios/`, XcodeGen → `xcodegen generate`): four targets —
`FoldKit` (framework), `FoldLight` (minimal app), `FoldLightWidgets` (extension),
`FoldKitTests`. iOS 17 / macOS 14. Team `G2KBQH7KWT`. App Group
`group.dev.ponderance.foldlight`. **No** macOS menu-bar/dashboard — widget-first by design.

**FoldKit (shared):**
- Secure-access (duplicated from homelab-glance): `KeychainStore`, `AppSettings`
  (single HA token, App-Group `UserDefaults` + Keychain split, mock-default),
  `StoredConnection` (nonisolated snapshot for widgets/intents).
- Theme (duplicated): `BlueprintColors` + `Color(hex:)` + `\.blueprint` env,
  `BlueprintFonts`/`Typography` + OFL fonts, `GraphPaperBackground`/`FoldedCorner`,
  new `BulbMark` (lit bulb renders in the live color w/ halo; outline when off).
- HA REST client (new): `LightProviding` protocol + `LiveLightClient`
  (`/api/states`, `/api/services/light/turn_on|turn_off|toggle`, `GET /api/` test) +
  `MockLightClient` (stateful) + `LightError`. `Brightness` util converts HA's
  0–255 ↔ `brightness_pct` 0–100. `normalizedBase` URL cleanup.
- Models: `LightState` (+ capability flags `supportsBrightness/Color/ColorTemp`,
  `isOnOffOnly`, `displayColor`), `LightRGB` (renamed from `RGBColor` — that name is
  ambiguous on macOS), `LightPreset` (+ `seedDefaults`), `LauncherTarget`.
- App-Group stores: `LightCache` (widgets render instantly), `PresetStore`
  (seeds Warm/Focus/Movie red on first run).
- App Intents + AppEntities (the spine the template lacked): `LightAppEntity` +
  `LightEntityQuery`, `PresetAppEntity` + `PresetEntityQuery`; `ToggleLightIntent`,
  `SetBrightnessIntent`, `ApplyPresetIntent` (optimistic cache + `WidgetReload`).

**Widgets (`FoldLightWidgets`):**
- `LightWidget` (small + medium, interactive): power toggle + brightness steps
  (25/50/75/100) + preset swatch row — each a `Button(intent:)` → HA, gated on the
  light's capabilities.
- `LauncherWidget`: blueprint tiles opening HA / Bambuddy via `Link`.
- iOS-18 controls (`#if os(iOS)`, ≥18): `MainLightToggleControl` (stateful
  `ControlWidgetToggle` + `SetMainLightOnIntent`), `ApplyPresetControl`,
  `OpenHomeAssistantControl`, `OpenPrinterControl` (via `OpenURLIntent`).

**App (`FoldLight`, minimal):** `RootView` (3 tabs) → `EditorView` (pick light;
brightness/temp/`ColorPicker` gated on `supported_color_modes`; live preview;
Apply to HA; save/delete presets), `PanelView` (launcher tiles), `SettingsView`
(URL + token + Test connection; mock toggle).

## Live HA facts (verified this session)
- App base URL (ships as default): `http://100.65.218.62:8123` (Tailscale — proven
  reachable). Alt: Caddy HTTPS `https://homeassistant.internal.ponderance.dev` (its
  internal cert isn't always trusted on-device). ATS allows the cleartext Tailscale path.
- Token: `/Volumes/docker/.env` → `HA_TOKEN` (valid). **Not** baked into source —
  paste it into Settings on device.
- Entities (real `/api/states` captured as test fixtures in `FoldKitTests/Fixtures/`):
  - `light.yetstrhom` ("Yetstrhöm") — `[color_temp, xy]`, 2202–4000 K → full color/temp/brightness. Main light.
  - `light.x1c_chamber_light` ("X1C Chamber Light") — `[onoff]` → toggle only.

## Verify
```bash
cd ios
xcodegen generate
xcodebuild test  -scheme FoldLight -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'   # 19 tests, all pass
xcodebuild build -scheme FoldLight -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'   # ✅
xcodebuild build -scheme FoldLight -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO            # ✅ (code; real signing needs a profile)
```
**Verified here:** all of the above + the live **read** path (fixtures came from the real
bulb) + the live **write/actuation** path — every body shape `LiveLightClient` sends was
curled against `light.yetstrhom` and returned 200 + physically changed the bulb, then
restored: `{"brightness_pct":60}` (→ HA brightness 153 ≈ 60%), `{"rgb_color":[255,30,20]}`
(HA maps rgb→xy on this `[color_temp,xy]` bulb), `{"color_temp_kelvin":4000}`, `turn_off`.
**NOT verifiable here (needs Anmol's device + signing):** real bulb changing from the
small widget / Control Center; App-Group + Keychain sharing under signing; Tailscale
reachability on-device; offline fail-safe; blueprint legibility in light/dark.

## Anmol manual checklist (on-device)
1. Open in Xcode (`open ios/FoldLight.xcodeproj`), select team `G2KBQH7KWT`; confirm the
   **App Group** `group.dev.ponderance.foldlight` capability is enabled on **both** the app
   and widget targets (Automatic signing should add it).
2. Run on device → Settings → turn **off** "Use mock data" → paste `HA_TOKEN` → Test connection (expect "Reachable ✓").
3. Add the **Light** widget + **Panel** widget to the Home Screen; add the Control Center controls.
4. Confirm a swatch / brightness step / toggle changes the real bulb without opening the app.

**If Test Connection fails on device** (the HTTPS exception was removed assuming the `.dev`
host is publicly trusted): the symptom shows as "Not reachable" because `testConnection()`
swallows TLS/DNS errors into `false`. Likely causes + fixes — (a) `homeassistant.internal.
ponderance.dev` doesn't resolve off-LAN → use the Tailscale URL `http://100.65.218.62:8123`;
(b) Caddy serves an *internal* CA cert iOS doesn't trust → install the Caddy root CA on the
device, **or** switch to the raw-IP `http://` URL and re-add an `NSAppTransportSecurity` →
`NSExceptionDomains` entry in `App/Info.plist` (it was removed since HTTPS needs none).

## Pass 2 backlog
- Full **Canvas color wheel** (replacing `ColorPicker`) + hue/sat field.
- **Generic multi-device control panel**: switches/scenes/scripts/climate as actuating
  widgets + an in-app entity list (HA already reachable; extend `LightProviding`-style clients).
- **medium/large** widget layouts + **Lock Screen** accessory families + per-preset iOS-18 controls
  (currently one "favorite" control; make it configurable via `AppIntentControlConfiguration`).
- `SetColorIntent`; 2nd-light/device list UI; brightness as a real value control; Watch complication.
- Real app icon + a FoldLight brand mark (currently a placeholder AppIcon slot + SF-Symbol bulb).
- Deep-link the printer tile to Bambuddy's upload route (currently its home page).

## Reuse provenance
Template: `~/GitHub/homelab-glance/ios` (XcodeGen four-target skeleton, KeychainStore,
AppSettings split-storage, blueprint theme/fonts, App-Group cache, timeline `SendableBox`,
`AppIntent → ControlWidget` plumbing). Plan: `~/.claude/plans/please-read-and-execute-composed-piglet.md`.
