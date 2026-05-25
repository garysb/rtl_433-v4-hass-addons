#!/usr/bin/with-contenv bashio
# rtl_433 v4 addon entrypoint
#
# Uses bashio (Home Assistant's official add-on helper library) to read
# Supervisor service-discovery for MQTT credentials. That means as long as the
# Mosquitto broker add-on is installed and this add-on declares
# `services: [mqtt:need]` in config.yaml, MQTT host/port/user/pass are
# auto-injected — no manual configuration needed.

set -e

bashio::log.info "=========================================="
bashio::log.info "rtl_433 v4 addon starting"
bashio::log.info "=========================================="

CONF_FILE=$(bashio::config 'rtl_433_conf_file')
RETAIN=$(bashio::config 'retain')

# Wait for the supervisor's MQTT service to be available
if ! bashio::services.available 'mqtt'; then
    bashio::exit.nok "No internal MQTT service available. Install Mosquitto broker first."
fi

MQTT_HOST=$(bashio::services mqtt 'host')
MQTT_PORT=$(bashio::services mqtt 'port')
MQTT_USER=$(bashio::services mqtt 'username')
MQTT_PASS=$(bashio::services mqtt 'password')

RETAIN_FLAG="0"
if [[ "${RETAIN}" == "true" ]]; then
    RETAIN_FLAG="1"
fi

# Build the MQTT output spec. Publishes to topic rtl_433/<hostname>/events by
# default, which matches the standard pbkhrv MQTT auto-discovery addon's
# subscription topic `rtl_433/+/events`.
MQTT_OUTPUT="mqtt://${MQTT_HOST}:${MQTT_PORT},user=${MQTT_USER},pass=${MQTT_PASS},retain=${RETAIN_FLAG}"

# Show version info — redirect to file to avoid SIGPIPE with `head` under pipefail
/usr/local/bin/rtl_433 -V > /tmp/v.txt 2>&1 || true
bashio::log.info "rtl_433 binary: $(head -1 /tmp/v.txt)"
rm -f /tmp/v.txt

bashio::log.info "Linked librtlsdr:"
ldd /usr/local/bin/rtl_433 | grep librtlsdr | while read line; do
    bashio::log.info "  ${line}"
done

bashio::log.info "MQTT broker: ${MQTT_HOST}:${MQTT_PORT} (user=${MQTT_USER})"
bashio::log.info "Conf file:   ${CONF_FILE:-<none, using rtl_433 defaults>}"
bashio::log.info "Retain:      ${RETAIN}"

if [[ -n "${CONF_FILE}" && -f "${CONF_FILE}" ]]; then
    bashio::log.info "==> Running rtl_433 with conf file ${CONF_FILE}"
    exec /usr/local/bin/rtl_433 \
        -c "${CONF_FILE}" \
        -F "${MQTT_OUTPUT}"
else
    if [[ -n "${CONF_FILE}" ]]; then
        bashio::log.warning "Conf file ${CONF_FILE} does not exist. Falling back to defaults."
    fi
    bashio::log.info "==> Running rtl_433 with defaults (433.92 MHz, all decoders enabled)"
    exec /usr/local/bin/rtl_433 \
        -F "${MQTT_OUTPUT}"
fi
