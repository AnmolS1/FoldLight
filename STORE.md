# FoldLight — App Store readiness checklist

What's needed to ship the iOS/macOS app. FoldLight is a client for the user's
own Home Assistant server.

## Metadata (fill in on App Store Connect)

| Field | Value / TODO |
|---|---|
| App name | FoldLight *(confirm availability on ASC)* |
| Subtitle (30 chars) | e.g. "Widget-first HA light control" |
| Category | Utilities |
| Description | TODO — cover: widget-first control of Home Assistant lights; auto-detects every light and its capabilities (on/off, dimming, temperature, color); per-widget light + preset-swatch configuration; Control Center controls; presets; user-defined launcher tiles; demo mode needs no server. |
| Keywords (100 chars) | home assistant,lights,smart home,widget,dimmer,color,presets,control center |
| Support URL | TODO (e.g. the GitHub repo) |
| Marketing URL | optional |
| Privacy-policy URL | **TODO — required.** Must state: no data collected; the app talks only to the user's own Home Assistant; the access token stays in the device Keychain. |

## Privacy (App Privacy section on ASC)

- Data collection: **None**. (Matches `PrivacyInfo.xcprivacy`: no tracking, no
  collected data types, UserDefaults accessed with reason CA92.1.)
- `ITSAppUsesNonExemptEncryption = false` is already set — no export docs needed.

## App Review notes (paste into the Review Notes field)

> FoldLight is a client for the user's self-hosted Home Assistant server. No
> account or server is needed to review: **Mock Data is ON by default** — every
> screen and widget is fully explorable with bundled sample lights (a color
> light, a temperature-only lamp, and an on/off light, so all capability
> layouts are visible), presets, the lights/launchers managers, the
> configurable widget, and Control Center controls.
>
> Network use: the app connects only to the Home Assistant URL the user
> enters. ATS is restrictive (HTTPS by default) with NSAllowsLocalNetworking
> for LAN servers and a scoped exception for Tailscale MagicDNS (*.ts.net)
> hosts, whose traffic is end-to-end encrypted by WireGuard.
> NSLocalNetworkUsageDescription is set; the local-network prompt appears on
> first connect, not at launch.

## Screenshots (generate from mock mode — no server needed)

Matrix: light + dark per device class.

- iPhone 6.9" (iPhone 17 Pro Max sim): Light editor (color light + temp-only lamp for capability gating), widget gallery/Edit Widget (light + preset selection), Control Center controls, Settings + Lights manager.
- iPad 13": editor + widgets.
- Mac: main window, narrow-window Settings.

Suggested flow per screenshot run: fresh install → onboarding → "Explore with
sample data" → screenshots.

## Human-only steps (cannot be automated from this repo)

1. Create the App Store Connect app record (bundle id `dev.ponderance.foldlight`, team `G2KBQH7KWT`).
2. Host the privacy policy and set its URL.
3. Archive + upload from Xcode 26 (Product → Archive → Distribute), both iOS and macOS.
4. Verify the App Group / Keychain entitlements are on the distribution provisioning profiles.
5. Complete the App Privacy questionnaire ("Data Not Collected").
