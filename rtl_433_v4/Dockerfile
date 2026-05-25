ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base:latest
FROM ${BUILD_FROM}

# Pinned versions (so rebuilds are reproducible)
ARG RTLSDRBLOG_REF=master
ARG RTL433_REF=master

ENV LANG C.UTF-8

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
RUN git clone --depth 1 --branch ${RTLSDRBLOG_REF} \
        https://github.com/rtlsdrblog/rtl-sdr-blog.git /tmp/rtl-sdr-blog && \
    cd /tmp/rtl-sdr-blog && \
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

# Verify both binaries built and link against our new librtlsdr
RUN ldd /usr/local/bin/rtl_433 | grep -q librtlsdr && \
    /usr/local/bin/rtl_433 -V 2>&1 | head -1

# Clean up build artifacts to keep the image lean
RUN rm -rf /tmp/rtl-sdr-blog /tmp/rtl_433 && \
    apk del build-base cmake git pkgconfig

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
