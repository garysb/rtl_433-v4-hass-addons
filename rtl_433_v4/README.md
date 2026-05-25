# rtl_433 v4

rtl_433 built against the rtl-sdr-blog fork of librtlsdr, with proper RTL-SDR Blog v4 dongle support.

## Configuration

| Option | Default | Description |
|---|---|---|
| `rtl_433_conf_file` | `""` (empty) | Path to a `rtl_433.conf` file. Leave empty for defaults (433.92 MHz, all decoders). Use `/share/rtl_433.conf` for a custom file (write via File Editor add-on). |
| `retain` | `true` | Whether MQTT messages should have the retain flag set. |

## MQTT topics

Publishes decoded events to `rtl_433/<addon-hostname>/events` — matches the wildcard topic that the standard MQTT auto-discovery add-on subscribes to (`rtl_433/+/events`), so they're drop-in compatible.

## Frequency hopping for EU (868 MHz)

Create a file at `/share/rtl_433.conf` (use the File Editor add-on):

```
frequency 433.92M
frequency 868.3M
hop_interval 60
```

Then set `rtl_433_conf_file: /share/rtl_433.conf` in this add-on's configuration and restart.

## First-build warning

The first time you install this add-on, the supervisor compiles librtlsdr and rtl_433 from source inside the container. On a Raspberry Pi 5 this takes about **5–8 minutes**. Subsequent restarts are instant — only the initial install is slow.
