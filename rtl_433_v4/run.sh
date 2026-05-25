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

# v1.0.13: rtl_test diagnostic removed. We've already confirmed (multiple times)
# that the dongle hardware works and produces clean samples. The diagnostic was
# leaving the v4 in a state rtl_433 didn't fully recover from — opening rtl_433
# fresh, as the only consumer of the dongle, should give it a clean slate.

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
# v1.0.16: scan BOTH EU bands (868.3 + 433.92) with 60s hopping, force 250 kSps,
# enable classic FSK detector for max protocol coverage.
#
# Argument-order gotcha (from rtl_433.c line 987): when -f is parsed for a freq
# > 800 MHz, rtl_433 auto-bumps samp_rate to 1M IF samp_rate looks like the
# default (250000). So -s MUST come AFTER -f, otherwise it gets silently
# overwritten by the auto-bump. Order here: -f's first, then -s overrides.
#
# Two -f flags + -H 60 = hop between 868.3 and 433.92 every 60 seconds.
# Catches sensors on either band — EU 868 (meters, alarms) AND 433 (weather,
# older sensors).
RTL433_EXTRA_ARGS="-f 868300000 -f 433920000 -H 60 -s 250000 -Y classic"

if [[ -n "${CONF_FILE}" && -f "${CONF_FILE}" ]]; then
    bashio::log.info "==> Running rtl_433 with conf file ${CONF_FILE}"
    exec /usr/local/bin/rtl_433 \
        ${RTL433_EXTRA_ARGS} \
        -c "${CONF_FILE}" \
        -F "${MQTT_OUTPUT}"
else
    if [[ -n "${CONF_FILE}" ]]; then
        bashio::log.warning "Conf file ${CONF_FILE} does not exist. Falling back to defaults."
    fi
    bashio::log.info "==> Running rtl_433 hopping 868.3/433.92 MHz (60s), classic mode, 250 kSps"
    exec /usr/local/bin/rtl_433 \
        ${RTL433_EXTRA_ARGS} \
        -F "${MQTT_OUTPUT}"
fi
