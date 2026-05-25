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
    echo "=== Searching for direct_sampling-related lines in librtlsdr.c ===" && \
    grep -n "direct_sampling" src/librtlsdr.c | head -40 || echo "(no matches)" && \
    echo "=== Applying patch: comment out rtlsdr_set_direct_sampling(...,2) calls ===" && \
    sed -i 's|rtlsdr_set_direct_sampling(dev, 2);|/* HA-addon: was rtlsdr_set_direct_sampling(dev, 2); */|g' src/librtlsdr.c && \
    sed -i 's|rtlsdr_set_direct_sampling(devt, 2);|/* HA-addon: was rtlsdr_set_direct_sampling(devt, 2); */|g' src/librtlsdr.c && \
    echo "=== After patch, lines containing rtlsdr_set_direct_sampling: ===" && \
    grep -n "rtlsdr_set_direct_sampling" src/librtlsdr.c | head -20 || echo "(no matches)" && \
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
# NOTE: Don't pipe rtl_433's output through `head` — pipefail + SIGPIPE makes the
# whole RUN step fail when head closes its stdin. Redirect to a file instead.
RUN ldd /usr/local/bin/rtl_433 | grep -q librtlsdr && \
    /usr/local/bin/rtl_433 -V > /tmp/rtl433_version.txt 2>&1 && \
    head -1 /tmp/rtl433_version.txt && \
    rm /tmp/rtl433_version.txt

# Clean up build artifacts to keep the image lean
RUN rm -rf /tmp/rtl-sdr-blog /tmp/rtl_433 && \
    apk del build-base cmake git pkgconfig

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
