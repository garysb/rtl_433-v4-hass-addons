#!/usr/bin/env bash
set -euo pipefail

OPTS=/data/options.json
CONF=/tmp/rtl_433.conf

FREQ=$(jq -r '.frequency // "433.92M"' "$OPTS")
GAIN=$(jq -r '.gain // 0' "$OPTS")
MQTT_HOST=$(jq -r '.mqtt_host // "core-mosquitto"' "$OPTS")
MQTT_PORT=$(jq -r '.mqtt_port // 1883' "$OPTS")
MQTT_USER=$(jq -r '.mqtt_user // ""' "$OPTS")
MQTT_PASS=$(jq -r '.mqtt_pass // ""' "$OPTS")
PULSE_DETECT=$(jq -r '.pulse_detect // "autolevel"' "$OPTS")
EXTRA=$(jq -r '.extra_args // ""' "$OPTS")

cat > "$CONF" <<EOF
# Auto-generated from add-on options on every start.
frequency $FREQ
sample_rate 250k
gain $GAIN
pulse_detect $PULSE_DETECT
convert si
report_meta time:iso:usec:tz

# MQTT output — topic structure matches pbkhrv autodiscovery expectations
output mqtt://${MQTT_HOST}:${MQTT_PORT},user=${MQTT_USER},pass=${MQTT_PASS},retain=1,devices=rtl_433/9b13b3f4-rtl433/devices[/type][/model][/subtype][/channel][/id],events=rtl_433/9b13b3f4-rtl433/events,states=rtl_433/9b13b3f4-rtl433/states

# Also log human-readable events to stderr (visible in addon log)
EOF

echo "============================================================"
echo "RTL_433 v4 add-on — effective config"
echo "============================================================"
cat "$CONF"
echo "============================================================"
echo "Starting rtl_433 ..."
echo "============================================================"

# -F log = also write decoded events to stderr/addon log
exec rtl_433 -c "$CONF" -F log ${EXTRA}
