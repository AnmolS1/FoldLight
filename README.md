# FoldLight

A widget-first **Home Assistant light controller** for iOS + macOS — on/off,
brightness, and color from the Home Screen, Lock Screen, and Control Center
**without opening the app**. Ponderance blueprint style. Sibling to
[homelab-glance](../homelab-glance).

> Status: **Pass 1 (MVP spine)** — compiles for iOS + macOS, 19 unit tests pass.
> See [HANDOFF.md](HANDOFF.md) for what's built, how to verify, and the Pass-2 backlog.

## How it works
Widgets can't contain a color wheel, so **color reaches widgets as presets**: you
dial a color/temperature/brightness in the app, save it, and it appears as a
tappable swatch in the widget and as a Control Center control. Each tap fires an
App Intent straight to Home Assistant's REST API.

- **In-app** (`ios/App`): a minimal editor (brightness / white-temperature /
  color, gated on each bulb's `supported_color_modes`), a preset library, a Panel
  of web-UI launchers, and Settings (HA URL + long-lived token + Test connection).
- **Widgets** (`ios/Widgets`): a small/medium interactive light widget (toggle +
  brightness steps + preset swatches), a launcher panel, and iOS-18 controls.
- **FoldKit** (`ios/FoldKit`): the HA REST client, models, App-Group stores
  (presets + light cache), theme, and the App Intents / AppEntities.

## Build
```bash
cd ios
xcodegen generate
open FoldLight.xcodeproj        # or: xcodebuild test -scheme FoldLight -destination 'platform=iOS Simulator,name=iPhone 16'
```
Requires [XcodeGen](https://github.com/yonsky/XcodeGen) (`brew install xcodegen`) and Xcode 17+.

## Connect to Home Assistant
Create a long-lived access token in HA (profile → Security → Long-Lived Access
Tokens), then in the app: Settings → turn off "Use mock data" → set the base URL
→ paste the token → Test connection. The base URL accepts either an HTTPS hostname
or a raw `http://host:8123` (e.g. over Tailscale). Reach HA over Tailscale or a
Cloudflare Tunnel.
