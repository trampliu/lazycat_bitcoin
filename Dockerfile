# syntax=docker/dockerfile:1.7

FROM debian:bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG ENABLE_WALLET=ON
ARG WITH_ZMQ=OFF
ARG ENABLE_IPC=OFF
ARG BUILD_TESTS=OFF
ARG BUILD_BENCH=OFF

RUN apt-get update && apt-get install -y --no-install-recommends \
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tini \
    libevent-2.1-7 \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libsqlite3-0 \
    libzmq5 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /usr/sbin/nologin bitcoin

COPY --from=builder /opt/bitcoin /opt/bitcoin
ENV PATH="/opt/bitcoin/bin:${PATH}"

USER bitcoin
WORKDIR /home/bitcoin
VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8333 8332

ENTRYPOINT ["/usr/bin/tini", "--", "bitcoind"]
CMD ["-printtoconsole", "-server=1", "-datadir=/home/bitcoin/.bitcoin", "-conf=/home/bitcoin/.bitcoin/bitcoin.conf"]
