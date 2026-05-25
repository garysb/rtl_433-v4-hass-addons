# rtl_433 v4 Home Assistant Add-on

A Home Assistant add-on repository providing **rtl_433 built against the rtl-sdr-blog librtlsdr fork**, which adds proper driver support for the **RTL-SDR Blog v4** dongle (USB PID `0x2838`).

## Why this exists

The popular [pbkhrv/rtl_433-hass-addons](https://github.com/pbkhrv/rtl_433-hass-addons) add-on ships with the upstream Osmocom `librtlsdr`. That library does not include the v4-specific tuner code from the rtl-sdr-blog fork. With a v4 dongle, the upstream library detects the device, fails to lock the R820T tuner's PLL (`[R82XX] PLL not locked!`), and either wedges the USB device or produces zero decoded events.

This add-on builds both `librtlsdr` (from the rtl-sdr-blog fork) and `rtl_433` from source, so the resulting binary tunes the v4 hardware correctly.

If you have a **v3 dongle** (USB PID `0x2832`), you should use the upstream pbkhrv add-on instead — it works perfectly with v3 and avoids a custom build.

## Installation

In Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**, then add this repository's URL.

After it loads, install **rtl_433 v4** from the store, configure with your MQTT broker credentials, and start it.

## What's inside

- `rtl_433_v4/` — the add-on itself (Dockerfile + config + run script)
- `repository.yaml` — supervisor repo metadata

## Companion: MQTT auto-discovery

This add-on publishes raw decoded events to MQTT. To turn those into Home Assistant entities automatically, pair it with `pbkhrv/rtl_433-hass-addons`'s `rtl_433 MQTT Auto Discovery` add-on (same MQTT topic format — drop-in compatible).
