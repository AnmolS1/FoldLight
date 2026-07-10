# FoldLight

A widget-first **Home Assistant light controller** for iOS + macOS — on/off,
brightness, and color from the Home Screen, Lock Screen, and Control Center
**without opening the app**. Ponderance blueprint style. Sibling to
[homelab-glance](../homelab-glance).

## How it works

Widgets can't contain a color wheel, so **color reaches widgets as presets**: you
dial a color / temperature / brightness in the app, save it, and it appears as a
tappable swatch in the widget and as a Control Center control. Each tap fires an
App Intent straight to Home Assistant's REST API — no round-trip through the app.

- **App** (`ios/App`): a minimal editor (brightness / white-temperature / color,
  gated on each bulb's `supported_color_modes`), a preset library, a Panel of
  web-UI launchers, and Settings (HA URL + long-lived token + Test connection).
- **Widgets** (`ios/Widgets`): a small/medium interactive light widget (toggle +
  brightness steps + preset swatches), a launcher panel, and iOS-18 Control
  Center controls.
- **FoldKit** (`ios/FoldKit`): the shared framework — HA REST client (`Net`),
  models (`Model`), App-Group stores (presets + light cache), theme (`Theme`),
  settings/keychain (`Settings`), and the App Intents / AppEntities (`Intents`).
- **Tests** (`ios/FoldKitTests`): unit coverage for the client, models, and
  brightness conversion.

## Build

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `ios/project.yml` — edit that, not the `.xcodeproj`, and regenerate:

```bash
cd ios
xcodegen generate
open FoldLight.xcodeproj
# or run the tests headlessly:
xcodebuild test -scheme FoldLight \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Requires XcodeGen (`brew install xcodegen`) and Xcode 17+. Targets iOS 17 /
macOS 14. Signing team and the App Group (`group.dev.ponderance.foldlight`) are
configured in `project.yml`; automatic signing adds the App Group capability to
both the app and widget targets.

## Connect to Home Assistant

Create a long-lived access token in HA (profile → Security → Long-Lived Access
Tokens), then in the app: Settings → turn off **Use mock data** → set the base
URL → paste the token → **Test connection**. The base URL accepts either an HTTPS
hostname or a raw `http://host:8123` (e.g. over Tailscale). Reach HA over
Tailscale or a Cloudflare Tunnel — cleartext HTTP is only permitted to
local-network and `*.ts.net` hosts, which ride the encrypted WireGuard tunnel.

## Roadmap

- Full in-app color wheel (hue/sat field) replacing the system `ColorPicker`.
- A generic multi-device panel: switches, scenes, scripts, and climate as
  actuating widgets, plus an in-app entity list.
- More widget families — medium/large layouts, Lock Screen accessories, and
  per-preset, configurable iOS-18 controls.
- `SetColorIntent`, brightness as a continuous value control, and a Watch
  complication.
- A real app icon and brand mark (currently a placeholder).

## License

MIT — see [LICENSE](LICENSE).
