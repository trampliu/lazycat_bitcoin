#!/bin/sh
set -eu

DATADIR="${BITCOIN_DATADIR:-/home/bitcoin/.bitcoin}"

mkdir -p "$DATADIR"

if [ "$(id -u)" = "0" ]; then
  chown -R 1000:1000 /home/bitcoin "$DATADIR"
  exec gosu bitcoin bitcoind "$@"
fi

exec bitcoind "$@"
