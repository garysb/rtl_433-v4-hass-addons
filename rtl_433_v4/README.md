# RTL_433 v4 add-on

A clean rebuild of the rtl_433 Home Assistant add-on that uses **current `rtlsdrblog/rtl-sdr-blog` master** for librtlsdr — the same upstream that SDR++ uses internally and that properly handles the RTL-SDR Blog v4's R828D tuner.

Built after extensive testing showed that the two commonly-available HAOS rtl_433 addons (`stuartparmenter/rtl433-addon` and `catduckgnaf/rtl_433_haos_addon`) ship with stale librtlsdr builds that misidentify the v4 tuner as R820T or R820T/2 and produce effectively zero decode sensitivity.

## What's different here

- librtlsdr is built fresh from `rtlsdrblog/rtl-sdr-blog` master (not osmocom, not Hayati Ayguen's fork) — the canonical v4 fork.
- `-DDETACH_KERNEL_DRIVER=ON` so libusb auto-detaches `dvb_usb_rtl28xxu` on device claim (belt-and-braces — also requires `module_blacklist=dvb_usb_rtl28xxu,rtl2832,rtl2832_sdr,dvb_usb_v2` on the host kernel cmdline for reliable operation; see `/boot/cmdline.txt` on HAOS).
- rtl_433 built from `merbanan/rtl_433` master with MQTT support enabled.
- Topics follow pbkhrv autodiscovery convention: `rtl_433/9b13b3f4-rtl433/{devices,events,states}` — so the existing `9b13b3f4_rtl433mqttautodiscovery` add-on will pick up decoded events without further configuration.

## Options

- `frequency` (string) — default `433.92M`. Set to `868.3M` for EU sub-GHz sensors, or list multiple for hopping (one per line if you customize via extra_args).
- `gain` (int 0–496) — RTL-SDR gain in tenths of dB. `0` = auto. Max effective is `496` (49.6 dB).
- `mqtt_host` / `mqtt_port` / `mqtt_user` / `mqtt_pass` — your Mosquitto credentials.
- `pulse_detect` — `autolevel` (default), `minmax` (more sensitive), or `magest`.
- `extra_args` — anything else to append to the rtl_433 command line (e.g. `-T 600` for short runs).

## Local install (no GitHub round-trip)

1. Copy this whole `rtl_433_v4/` directory to `/addons/rtl_433_v4/` on your HAOS host (use `scp` via port 22222 host SSH).
2. In HA: Settings → Apps → menu → Check for updates (or trigger supervisor store reload via API).
3. The "Local add-ons" section should now show "RTL_433 v4". Install, configure, start.

## Verify it's working

After start, addon log should show:
```
Found Rafael Micro R828D tuner          # <-- the win, was R820T before
Reading samples in async mode...
```

And MQTT subscription to `rtl_433/9b13b3f4-rtl433/events` should show decoded events when sensors transmit nearby.
