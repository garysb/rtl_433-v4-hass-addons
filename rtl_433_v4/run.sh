#!/usr/bin/env bash
# rtl_433 v4 addon entrypoint
#
# Reads addon options from /data/options.json:
#   rtl_433_conf_file: optional path to an rtl_433 .conf file (e.g. /share/rtl_433.conf)
#   retain: whether published MQTT messages should be retained (bool, default true)
#
# Pulls MQTT broker credentials from Home Assistant Supervisor's service discovery
# (i.e. you don't have to specify host/user/password — Supervisor injects them when
# the addon has `services: [mqtt:need]` in config.yaml and Mosquitto is installed).

set -euo pipefail

OPTIONS_FILE="/data/options.json"
CONF_FILE="$(jq -r '.rtl_433_conf_file // ""' "${OPTIONS_FILE}")"
RETAIN="$(jq -r '.retain // true' "${OPTIONS_FILE}")"

# Pull MQTT details from Supervisor's mqtt service.
# These come from the addon's `services: [mqtt:need]` declaration.
MQTT_HOST="$(curl -fsSL -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    http://supervisor/services/mqtt | jq -r '.data.host')"
MQTT_PORT="$(curl -fsSL -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    http://supervisor/services/mqtt | jq -r '.data.port')"
MQTT_USER="$(curl -fsSL -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    http://supervisor/services/mqtt | jq -r '.data.username')"
MQTT_PASS="$(curl -fsSL -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    http://supervisor/services/mqtt | jq -r '.data.password')"

RETAIN_FLAG="0"
if [[ "${RETAIN}" == "true" ]]; then
    RETAIN_FLAG="1"
fi

# Build the MQTT output spec for rtl_433.
# Publishes to topic rtl_433/<hostname>/events by default — matches the standard
# pbkhrv MQTT auto-discovery addon's subscription topic `rtl_433/+/events`.
MQTT_OUTPUT="mqtt://${MQTT_HOST}:${MQTT_PORT},user=${MQTT_USER},pass=${MQTT_PASS},retain=${RETAIN_FLAG}"

echo "==> rtl_433 v4 addon starting"
echo "    rtl_433 binary version:"
/usr/local/bin/rtl_433 -V 2>&1 | head -1 | sed 's/^/    /'
echo "    librtlsdr links:"
ldd /usr/local/bin/rtl_433 | grep librtlsdr | sed 's/^/    /'
echo "    MQTT broker: ${MQTT_HOST}:${MQTT_PORT} (user=${MQTT_USER})"
echo "    Conf file: ${CONF_FILE:-<none, using defaults>}"

if [[ -n "${CONF_FILE}" && -f "${CONF_FILE}" ]]; then
    echo "==> Running rtl_433 with conf file ${CONF_FILE}"
    exec /usr/local/bin/rtl_433 \
        -c "${CONF_FILE}" \
        -F "${MQTT_OUTPUT}"
else
    if [[ -n "${CONF_FILE}" ]]; then
        echo "==> WARNING: conf file ${CONF_FILE} does not exist, falling back to defaults"
    fi
    echo "==> Running rtl_433 with default config (433.92 MHz, all decoders enabled)"
    exec /usr/local/bin/rtl_433 \
        -F "${MQTT_OUTPUT}"
fi
