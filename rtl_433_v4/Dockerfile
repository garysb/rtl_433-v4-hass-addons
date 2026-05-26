ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8

# Install build deps + runtime libusb
RUN apk add --no-cache \
        bash \
        jq \
        libusb \
        libusb-dev \
        build-base \
        cmake \
        git \
        pkgconfig

# Build rtl-sdr-blog librtlsdr (current master — v4-aware)
RUN git clone --depth 1 https://github.com/rtlsdrblog/rtl-sdr-blog.git /src/rtl-sdr-blog && \
    cd /src/rtl-sdr-blog && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DDETACH_KERNEL_DRIVER=ON \
        -DINSTALL_UDEV_RULES=ON && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig /usr/local/lib

# Build rtl_433 (current master)
RUN git clone --depth 1 https://github.com/merbanan/rtl_433.git /src/rtl_433 && \
    cd /src/rtl_433 && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_MQTT=ON && \
    make -j"$(nproc)" && \
    make install

# Strip build deps to keep image lean
RUN apk del build-base cmake git pkgconfig libusb-dev && \
    rm -rf /src /var/cache/apk/* /root/.cache

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
