# RTL_433 v4 add-on

A clean rebuild of the rtl_433 Home Assistant add-on that uses **current `rtlsdrblog/rtl-sdr-blog` master** for librtlsdr — the same upstream that SDR++ uses internally and that properly handles the RTL-SDR Blog v4's R828D tuner.

Built after extensive testing showed that the two commonly-available HAOS rtl_433 addons (`stuartparmenter/rtl433-addon` and `catduckgnaf/rtl_433_haos_addon`) ship with stale librtlsdr builds that misidentify the v4 tuner as R820T or R820T/2 and produce effectively zero decode sensitivity.

## What's different here

- librtlsdr is built fresh from `rtlsdrblog/rtl-sdr-blog` master (not osmocom, not Hayati Ayguen's fork) — the canonical v4 fork.
- `-DDETACH_KERNEL_DRIVER=ON` so libusb auto-detaches `dvb_usb_rtl28xxu` on device claim (belt-and-braces — also requires `module_blacklist=dvb_usb_rtl28xxu,rtl2832,rtl2832_sdr,dvb_usb_v2` on the host kernel cmdline for reliable operation; see `/boot/cmdline.txt` on HAOS).
- rtl_433 built from `merbanan/rtl_433` master with MQTT support enabled.
- Topics follow pbkhrv autodiscovery convention: `rtl_433/9b13b3f4-rtl433/{devices,events,states}` — so the existing `9b13b3f4_rtl433mqttautodiscovery` add-on will pick up decoded events without further configuration.

## Options

- `frequency` (string) — default `433.92M`. The primary frequency the radio tunes to. Set to `868.3M` for EU sub-GHz sensors. If you want to listen on more than one frequency, use the `frequencies` list below instead of changing this; rtl_433 will hop between the primary and the additional frequencies.
- `frequencies` (list of strings) — default empty. Additional frequencies to hop between (in addition to `frequency`). Example: `["868.3M", "868.95M"]` gives a 3-frequency hop list of `[frequency, 868.3M, 868.95M]`. Leave empty for single-frequency operation.
- `hop_interval` (int, 1–3600) — default `60` seconds. How long to dwell on each frequency before hopping. Only takes effect when more than one frequency is in play. Shorter = better coverage of chatty sensors, longer = better odds of catching sensors that transmit rarely.
- `gain` (int, 0–49) — RTL-SDR tuner gain in **whole dB**. `0` = auto (AGC). The R820T family supports values from 0.0 to 49.6; the value you set here is the closest matching step. Recommended default is `0` (auto) for most setups; if you see no decodes, try `40`.
- `mqtt_host` / `mqtt_port` / `mqtt_user` / `mqtt_pass` — your Mosquitto credentials.
- `pulse_detect` — `autolevel` (default), `minmax` (more sensitive), or `magest`.
- `extra_args` — anything else to append to the rtl_433 command line (e.g. `-T 600` for short runs, `-X '...'` for a custom flex decoder).

> **Note:** unlike v2.0.x, `gain` is now in **whole dB**, not tenths of a dB. If you're upgrading from v2.0.x with a previously-set numeric gain, divide it by 10. (`gain 0` = auto in both versions.)

## Local install (no GitHub round-trip)

1. Copy this whole `rtl_433_v4/` directory to `/addons/rtl_433_v4/` on your HAOS host (use `scp` via port 22222 host SSH).
2. In HA: Settings → Apps → menu → Check for updates (or trigger supervisor store reload via API).
3. The "Local add-ons" section should now show "RTL_433 v4". Install, configure, start.

## Frequency hopping notes

rtl_433 tunes to one frequency at a time and dwells for `hop_interval` seconds before moving to the next. With three frequencies and the default 60-second interval, the radio is on any given band for ~33% of the time — sensors that transmit every few seconds will usually get picked up; sensors that transmit once an hour can easily be missed. Tune `hop_interval` to match your sensor population:

- Chatty 433 (TPMS, weather stations broadcasting every 30–60s): 60s dwell is fine.
- Mixed 433 / 868 sensors: 60–120s dwell.
- Smart meters or other rare transmitters: 300s+ dwell, accept missing 433 stuff while you're on 868.

## Verify it's working

After start, addon log should show:

```
Frequencies:   -f 433.92M -f 868.3M -f 868.95M
Hop:           -H 60
Gain:          -g 40  (or "(auto)" if you left it at 0)
...
Starting rtl_433 ...
Reading samples in async mode...
Auto Level: ...
```

The "Auto Level" lines mean rtl_433 is actively sampling. To see decoded events flow, subscribe to MQTT:

```
mosquitto_sub -h <broker> -u mqtt -P '<password>' -t 'rtl_433/9b13b3f4-rtl433/events' -v
```

If you see only "Starting rtl_433 …" and no "Auto Level" lines, the dongle isn't actually receiving — check that you have a valid gain (try `40` if auto isn't working) and that the dongle is getting warm to the touch.

## Companion: MQTT auto-discovery

This add-on publishes raw decoded events to MQTT. To turn those into Home Assistant entities automatically, pair it with `pbkhrv/rtl_433-hass-addons`'s `rtl_433 MQTT Auto Discovery` add-on (same MQTT topic format — drop-in compatible).

## Changelog

- **2.1.0** — Native `frequencies` (list) and `hop_interval` (int) options instead of requiring `extra_args` for hopping. Fixed gain unit: now in whole dB (schema `int(0,49)`) instead of the v2.0.x bug where the schema implied tenths of dB but `run.sh` passed the value as whole dB anyway. Frequency, gain, and hop interval moved to the command line in `run.sh` to avoid conf-file override surprises.
- **2.0.0** — Initial clean rebuild on `rtl-sdr-blog` master for proper RTL-SDR Blog v4 support.
