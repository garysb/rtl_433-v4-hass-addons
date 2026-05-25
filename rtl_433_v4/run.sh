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

# === DIAGNOSTIC: rtl_test for 5 seconds before launching rtl_433 ===
# Verifies that the dongle can produce raw samples at all, independent of rtl_433's
# frequency-setting code. If `rtl_test` reports successful sample reading (typically
# "Reading samples in async mode..." and per-second sample counts), the dongle hardware
# and our librtlsdr-blog build are fine and any further problem is in rtl_433's tuner
# init. If `rtl_test` errors with PLL lock or USB failures, the dongle is suspect.
bashio::log.info "==========================================="
bashio::log.info "Running rtl_test diagnostic for 5 seconds..."
bashio::log.info "==========================================="
timeout 5 /usr/local/bin/rtl_test -s 2400000 2>&1 | while read line; do
    bashio::log.info "rtl_test: ${line}"
done || true
bashio::log.info "==========================================="
bashio::log.info "rtl_test diagnostic complete"
bashio::log.info "==========================================="

# WORKAROUND for v4 dongle: explicitly disable direct sampling using rtl_sdr before
# launching rtl_433.
#
# Background: the rtl-sdr-blog driver defaults to direct-sampling-input-2 mode on
# v4 dongles (used for HF reception via the v4's special antenna routing). When
# rtl_433 starts, it sees that mode is active, calls rtlsdr_set_direct_sampling(0)
# to disable it, but the R820T tuner doesn't fully re-init for normal quadrature
# reception — the result is a deadlocked state where no samples flow.
#
# rtl_sdr with -D 0 explicitly sets direct sampling off AND properly re-tunes the
# R820T to the requested frequency. Running it briefly before rtl_433 leaves the
# dongle in a known-good state for normal VHF/UHF reception.
#
# (We can't pass `-D 0` to rtl_433 directly because in rtl_433 v25.12+ the -D flag
# was repurposed to control "input device run mode" — it now expects quit/restart/
# pause/manual, not direct-sampling values.)
bashio::log.info "==========================================="
bashio::log.info "Pre-resetting direct sampling mode..."
bashio::log.info "==========================================="
# Read a small fixed number of samples so rtl_sdr self-terminates cleanly (vs
# timeout/SIGKILL which leaves the dongle USB-wedged). 240k samples at 2.4Msps
# is 100ms of capture — enough to confirm direct sampling is disabled and that
# the tuner is on 433.92 MHz, then it cleanly closes the device.
/usr/local/bin/rtl_sdr -D 0 -f 433920000 -s 2400000 -n 240000 /dev/null 2>&1 | head -5 | while read line; do
    bashio::log.info "rtl_sdr: ${line}"
done || true
# Let the USB device fully settle after rtl_sdr's clean close
sleep 1
bashio::log.info "Reset complete; tuner should now be in quadrature mode at 433.92 MHz."
bashio::log.info "==========================================="

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
