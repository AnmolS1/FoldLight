# Foldlight — Home Assistant light control (own app, widget-first) — for Claude Code

> A standalone app + widgets to control your Home Assistant light(s) — **on/off, brightness, and
> color** — from the Home Screen, Lock Screen, and Control Center **without opening anything**.
> Ponderance blueprint style. **Its own repo** (working name `foldlight` — rename freely). You'll
> have ~1–2 HA lights for the foreseeable future, so the widget is dedicated and generous, not a
> generic device list.

## Why its own app (reversing the earlier "fold into Homelab Glance" idea)
Native interactive widgets + iOS 18 Control Center controls already actuate **without opening an
app**, so co-locating with Homelab Glance saves nothing — and lighting is a distinct domain (a
Home Assistant integration plus a whole color UI) with its own potential audience. Separate repo =
cleaner code + cleaner task graph. If convenient, share a tiny Swift package for the blueprint
theme + secure-access helper; otherwise just duplicate (it's small).

## Control path — Home Assistant REST
- Auth: HA **long-lived access token**, `Authorization: Bearer <token>`.
- Read: `GET {HA}/api/states/{entity_id}` → state + attributes (`brightness`, `rgb_color`,
  `color_temp_kelvin`, supported color modes).
- Act: `POST {HA}/api/services/light/turn_on` with `{entity_id, brightness_pct}` and/or
  `{rgb_color:[r,g,b]}` / `{color_temp_kelvin:K}` / `{hs_color:[h,s]}`; plus `light/turn_off`,
  `light/toggle`. (MQTT to `zigbee2mqtt/{device}/set` is a fallback; HA is cleaner and models color.)
- Reach HA over **Tailscale** or **Cloudflare Tunnel + Access**. Base URL + token in **Keychain** +
  an **App Group** so widgets read them.

## Color — how it works on each surface (this drives the whole design)
WidgetKit interactive widgets only allow `Button(intent:)` / `Toggle(intent:)` — **no color wheel
or drag-slider inside a widget**. So color reaches the widgets as **presets you define in the app**:
- **In-app (full control):** a real **color wheel** (SwiftUI `Canvas` + drag, or a hue/sat field),
  a **white-temperature slider (~2000–6500 K)**, a **brightness slider**, a live preview, and a
  **saved-preset library** (name + color/temp/brightness). This is where you dial colors in.
- **Every widget, incl. `systemSmall`:** an on/off toggle + a **row of preset swatches** (tap →
  `ApplyPresetIntent` → HA, instant, budget-exempt) + **brightness steps** (−/+ or 25/50/75/100).
  Since there's one main light, dedicate the small widget to it — ~5 swatches + brightness fit.
  Medium/large add more swatches, a temperature row, and per-light rows if a 2nd light appears.
- **iOS 18 Control Center / Lock Screen / Action button:** a brightness **value control**
  (slider-style), an on/off **toggle control**, and one **control per favorite preset**
  ("Warm", "Focus", "Movie red"). Fastest path — no Home Screen needed.
- **Optimistic UI** everywhere: reflect the change instantly, reconcile on the next read.

## App Intents
`ToggleLightIntent(light)`, `SetBrightnessIntent(light, pct)`, `SetColorIntent(light, rgb|kelvin)`,
`ApplyPresetIntent(light, preset)` — `light` and `preset` are `AppEntity`s, so they're pickable in
widget configuration, Shortcuts, and controls. Persist presets in the App Group so app + widgets
share them.

## Build / surfaces / theme
- **XcodeGen** app + widget extension + `Shared`; iOS 17 (interactive widgets) / iOS 18 (controls);
  a Watch complication is a later option.
- **Blueprint style:** graph-paper ground; a **lit bulb renders in the actual chosen color** with a
  soft halo; off = outline on graph paper; crease-blue chrome; rosette mark; light/dark via tokens.
- **Widgets:** small (the one light — toggle + swatches + brightness), medium/large (more presets +
  temperature + brightness), Lock Screen accessories, iOS 18 controls.
- **In-app:** the wheel / temperature / brightness / preset editor, a device list (for a future 2nd
  light), and a Settings screen (HA URL/token + "Test connection").

## Test / manual / acceptance
- **Local, free:** Simulator hitting HA over Tailscale, or a mock HA responder; free personal team
  on-device to feel a Control Center toggle and a swatch changing the real bulb.
- **Manual (Anmol):** create the HA long-lived token; confirm the light `entity_id`(s) and their
  supported color modes (rgb vs color_temp); Tailscale/Tunnel reachability; Xcode signing + App
  Group.
- **Acceptance:** from the **small** widget you can turn the light on/off, pick a **color** (preset
  swatch), and step **brightness** — changing the real bulb **without opening the app**; same from a
  Control Center control; the in-app **color wheel + temperature** set any color and save presets
  that then appear as widget swatches; offline fails safe; blueprint legible in both themes;
  compiles iOS 17 (+ iOS 18 controls where available).

Reference:
- discofin-server `/Volumes/expansion/docker/docker-compose.yml` (`homeassistant`, `zigbee2mqtt`, `mosquitto`).
- homelab-glace `~/GitHub/homelab-glance` (`ios/`, `README.md`)