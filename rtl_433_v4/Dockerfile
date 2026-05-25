ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base:latest
FROM ${BUILD_FROM}

# Pinned versions (so rebuilds are reproducible)
ARG RTLSDRBLOG_REF=master
ARG RTL433_REF=master

ENV LANG=C.UTF-8

# Build deps + runtime deps
RUN apk add --no-cache \
        bash \
        build-base \
        cmake \
        git \
        libusb-dev \
        pkgconfig \
        mosquitto-clients \
        jq \
        bsd-compat-headers

# 1. Build the rtl-sdr-blog fork of librtlsdr (the whole point of this addon).
#    The fork adds support for the RTL-SDR Blog v4 dongle's tuner control.
#
#    IMPORTANT: We patch the source before building to neutralize the v4's
#    automatic direct-sampling probe. By default, on v4 dongles librtlsdr
#    calls rtlsdr_set_direct_sampling(dev, 2) during init to set up HF
#    reception via the v4's special antenna routing. The trouble: the
#    subsequent transition back to normal quadrature mode (when rtl_433
#    asks for VHF/UHF) leaves the R820T tuner in a wedged state — PLL
#    lock fails, no samples flow. Removing the auto-DS calls means the
#    v4 stays in normal quadrature mode and the R820T tuner initializes
#    cleanly for VHF/UHF reception.
RUN git clone --depth 1 --branch ${RTLSDRBLOG_REF} \
        https://github.com/rtlsdrblog/rtl-sdr-blog.git /tmp/rtl-sdr-blog && \
    cd /tmp/rtl-sdr-blog && \
    # === ROOT CAUSE PATCH ===
    # In rtlsdr_set_center_freq (around line 904), the v4-aware librtlsdr does:
    #   dev->direct_sampling = (freq < 24000000 && tuner==R820T && !is_v4l) ? 2 : 0;
    # This is meant for v4 dongles to auto-route HF (<24MHz) requests through
    # direct-sampling input 2. But when rtl_433 sets the sample rate, that
    # internally triggers set_center_freq with `dev->freq` still 0 (uninitialized).
    # 0 < 24M → DS gets set to 2 → tuner->exit() puts R820T to sleep → next
    # frequency set (433.92 MHz) hits "PLL not locked" → tuner doesn't recover.
    # Patch: hardcode `dev->direct_sampling = 0` so the auto-routing never fires.
    # We're doing VHF/UHF reception only, direct sampling is never needed.
    echo "=== Showing the buggy line BEFORE patch: ===" && \
    grep -n "direct_sampling = (freq" src/librtlsdr.c && \
    echo "=== Applying surgical sed patch (busybox-safe: s command, literal spaces) ===" && \
    sed -i 's|^.*dev->direct_sampling = (freq < 24000000.*$|        dev->direct_sampling = 0; /* HA-addon-patch: never auto-enable direct sampling */|' src/librtlsdr.c && \
    echo "=== Showing the patched line AFTER ===" && \
    sed -n '903,906p' src/librtlsdr.c && \
    echo "=== Sanity-check: no more lines should match the original buggy pattern ===" && \
    if grep -q "direct_sampling = (freq" src/librtlsdr.c; then \
        echo "PATCH FAILED — buggy line still present"; exit 1; \
    else \
        echo "OK — buggy line successfully replaced"; \
    fi && \
    mkdir build && cd build && \
    cmake .. \
        -DINSTALL_UDEV_RULES=ON \
        -DDETACH_KERNEL_DRIVER=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig /etc/ld.so.conf.d || true

# 2. Build rtl_433 against the v4-aware librtlsdr we just installed.
RUN git clone --depth 1 --branch ${RTL433_REF} \
        https://github.com/merbanan/rtl_433.git /tmp/rtl_433 && \
    cd /tmp/rtl_433 && \
    mkdir build && cd build && \
    cmake .. \
        -DENABLE_RTLSDR=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j"$(nproc)" && \
    make install

# Verify both binaries built and link against our new librtlsdr.
# NOTE: `set +o pipefail` is critical — HA base images enable pipefail by default,
# which makes ldd (or rtl_433 -V) exit 141 (SIGPIPE) when the consumer in the pipe
# (e.g. grep -q, head) closes its stdin early. Disabling pipefail for this RUN
# makes the verification robust regardless of which side of the pipe closes first.
RUN set +o pipefail && \
    ldd /usr/local/bin/rtl_433 | grep librtlsdr && \
    /usr/local/bin/rtl_433 -V 2>&1 | head -1 && \
    echo "Build verification OK"

# Clean up build artifacts to keep the image lean
RUN rm -rf /tmp/rtl-sdr-blog /tmp/rtl_433 && \
    apk del build-base cmake git pkgconfig

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
