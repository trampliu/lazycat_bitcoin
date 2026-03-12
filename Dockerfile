# syntax=docker/dockerfile:1.7

FROM debian:bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_MIRROR=deb.debian.org
ARG ENABLE_WALLET=ON
ARG WITH_ZMQ=OFF
ARG ENABLE_IPC=OFF
ARG BUILD_TESTS=OFF
ARG BUILD_BENCH=OFF

RUN sed -i "s|deb.debian.org|${APT_MIRROR}|g; s|security.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true update \
    && apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    build-essential \
    cmake \
    pkgconf \
    python3 \
    ca-certificates \
    libevent-dev \
    libboost-dev \
    libsqlite3-dev \
    libcapnp-dev \
    libzmq3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_GUI=OFF \
    -DBUILD_TESTS=${BUILD_TESTS} \
    -DBUILD_BENCH=${BUILD_BENCH} \
    -DBUILD_FUZZ_BINARY=OFF \
    -DENABLE_WALLET=${ENABLE_WALLET} \
    -DWITH_ZMQ=${WITH_ZMQ} \
    -DENABLE_IPC=${ENABLE_IPC} \
    -DWITH_USDT=OFF \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build --prefix /opt/bitcoin

FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_MIRROR=deb.debian.org

RUN sed -i "s|deb.debian.org|${APT_MIRROR}|g; s|security.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true update \
    && apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    ca-certificates \
    gosu \
    tini \
    libevent-dev \
    libboost-dev \
    libsqlite3-0 \
    libzmq5 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /usr/sbin/nologin bitcoin

COPY --from=builder /opt/bitcoin /opt/bitcoin
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh
ENV PATH="/opt/bitcoin/bin:${PATH}"

WORKDIR /home/bitcoin
VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8333 8332

ENTRYPOINT ["/usr/bin/tini", "--", "/bin/sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["-printtoconsole", "-server=1", "-datadir=/home/bitcoin/.bitcoin"]
