# Moved — lighting is now its own app

Zigbee/Home-Assistant **light control is a standalone app** now (working name **Foldlight**), not a
module of Homelab Glance. The build spec lives in the portable prompt **`foldlight-lights-app-prompt.md`**
(in Anmol's outputs) — create it as its own repo and build from there.

Why: native interactive widgets + iOS 18 Control Center controls actuate without opening an app, so
co-locating with Homelab Glance bought nothing, and lighting (HA integration + a full color UI) is
its own domain. Homelab Glance and Foldlight are siblings; they may share a small theme/secure-access
Swift package.
