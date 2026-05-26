#!/usr/bin/env bash
set -euo pipefail
OPTS=/data/options.json
CONF=/tmp/rtl_433.conf

# --- read options with sensible fallbacks ----------------------------------
FREQ=$(jq -r '.frequency // "433.92M"' "$OPTS")
FREQS_JSON=$(jq -c '.frequencies // []' "$OPTS")
HOP=$(jq -r '.hop_interval // 60' "$OPTS")
GAIN=$(jq -r '.gain // 0' "$OPTS")
MQTT_HOST=$(jq -r '.mqtt_host // "core-mosquitto"' "$OPTS")
MQTT_PORT=$(jq -r '.mqtt_port // 1883' "$OPTS")
MQTT_USER=$(jq -r '.mqtt_user // ""' "$OPTS")
MQTT_PASS=$(jq -r '.mqtt_pass // ""' "$OPTS")
PULSE_DETECT=$(jq -r '.pulse_detect // "autolevel"' "$OPTS")
EXTRA=$(jq -r '.extra_args // ""' "$OPTS")

# --- build frequency args (primary + any additional) -----------------------
# rtl_433's command-line -f flags do NOT reliably combine with a conf-file
# 'frequency' directive, so we put every frequency on the command line and
# keep the conf file free of frequency directives.
FREQ_ARGS="-f $FREQ"
EXTRA_COUNT=$(echo "$FREQS_JSON" | jq 'length')
if [ "$EXTRA_COUNT" -gt 0 ]; then
    while IFS= read -r f; do
        [ -n "$f" ] && FREQ_ARGS="$FREQ_ARGS -f $f"
    done < <(echo "$FREQS_JSON" | jq -r '.[]')
fi

# --- hop interval, only if multiple frequencies are in play ---------------
HOP_ARGS=""
TOTAL_FREQS=$((EXTRA_COUNT + 1))
if [ "$TOTAL_FREQS" -gt 1 ]; then
    HOP_ARGS="-H $HOP"
fi

# --- gain: 0 = auto (omit -g); otherwise pass whole-dB value --------------
# (rtl_433's -g flag and conf-file 'gain' directive are both in dB,
# NOT tenths of dB. We use the schema range int(0,49) to enforce this.)
GAIN_ARGS=""
if [ "$GAIN" -gt 0 ]; then
    GAIN_ARGS="-g $GAIN"
fi

# --- minimal conf file: only what doesn't need to be on the cmdline -------
cat > "$CONF" <<EOF
# Auto-generated from add-on options on every start.
# Frequency, gain, and hop interval are passed on the command line.
sample_rate 250k
pulse_detect $PULSE_DETECT
convert si
report_meta time:iso:usec:tz
# MQTT output -- topic structure matches pbkhrv autodiscovery expectations
output mqtt://${MQTT_HOST}:${MQTT_PORT},user=${MQTT_USER},pass=${MQTT_PASS},retain=1,devices=rtl_433/9b13b3f4-rtl433/devices[/type][/model][/subtype][/channel][/id],events=rtl_433/9b13b3f4-rtl433/events,states=rtl_433/9b13b3f4-rtl433/states
EOF

echo "============================================================"
echo "RTL_433 v4 add-on -- effective config"
echo "============================================================"
echo "Frequencies:   $FREQ_ARGS"
echo "Hop:           ${HOP_ARGS:-(single frequency, no hop)}"
echo "Gain:          ${GAIN_ARGS:-(auto)}"
echo "Extra args:    ${EXTRA:-(none)}"
echo "--- conf file ---"
cat "$CONF"
echo "============================================================"
echo "Starting rtl_433 ..."
echo "============================================================"
# -F log = also write decoded events to stderr (visible in addon log)
exec rtl_433 -c "$CONF" -F log $FREQ_ARGS $GAIN_ARGS $HOP_ARGS ${EXTRA}
