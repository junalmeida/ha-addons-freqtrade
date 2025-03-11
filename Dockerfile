FROM mcr.microsoft.com/vscode/devcontainers/typescript-node:22-bookworm as frequi
RUN \
    cd / && \
    git clone https://github.com/freqtrade/frequi.git && \
    cd frequi && \
    pnpm install && \
    pnpm run build --base=./


FROM freqtradeorg/freqtrade:stable
USER root

# Build Args
ARG \
    BUILD_FROM \
    BUILD_ARCH \
    BUILD_VERSION

# Default ENV
ENV \
    LANG="C.UTF-8" \
    DEBIAN_FRONTEND="noninteractive" \
    CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt" \
    BASHIO_VERSION="0.16.2" \
    TEMPIO_VERSION="2024.11.2" \
    S6_OVERLAY_VERSION="3.1.6.2"

ENV \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES=1 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_SERVICES_GRACETIME=15000 \
    S6_SERVICES_READYTIME=50 \
    S6_KEEP_ENV=1

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Base system
WORKDIR /usr/src

RUN \
    set -x \
    && apt-get update && apt-get install -y --no-install-recommends \
        bash \
        jq \
        tzdata \
        curl \
        nginx \
        ca-certificates \
        xz-utils \
    && mkdir -p /usr/share/man/man1 \
    \
    && if [ "${BUILD_ARCH}" = "armv7" ]; then \
            export S6_ARCH="arm"; \
        elif [ "${BUILD_ARCH}" = "i386" ]; then \
            export S6_ARCH="i686"; \
        elif [ "${BUILD_ARCH}" = "amd64" ]; then \
            export S6_ARCH="x86_64"; \
        else \
            export S6_ARCH="${BUILD_ARCH}"; \
        fi \
    \
    && curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && mkdir -p /etc/fix-attrs.d \
    && mkdir -p /etc/services.d \
    \
    && curl -L -f -s -o /usr/bin/tempio \
        "https://github.com/home-assistant/tempio/releases/download/${TEMPIO_VERSION}/tempio_${BUILD_ARCH}" \
    && chmod a+x /usr/bin/tempio \
    \
    && mkdir -p /usr/src/bashio \
    && curl -L -f -s "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - --strip 1 -C /usr/src/bashio \
    && mv /usr/src/bashio/lib /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/*

# S6-Overlay
WORKDIR /
USER root
ENTRYPOINT ["/init"]

COPY rootfs /
COPY --from=frequi /frequi /frequi
RUN \
    chmod -R a+rw /var/lib/nginx && \
    chmod -R a+rw /var/log/nginx && \
    chmod -R a+rw /freqtrade && \
    chmod -R a+rx /etc/services.d && \
    chmod a+rx /init

LABEL \
  io.hass.version="$BUILD_VERSION" \
  io.hass.type="addon" \
  io.hass.arch="$BUILD_ARCH"


