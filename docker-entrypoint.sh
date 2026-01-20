#!/bin/sh
set -e

DATA_DIR=/app/data

mkdir -p "$DATA_DIR"
chown -R appuser:appgroup "$DATA_DIR"

exec "$@"
