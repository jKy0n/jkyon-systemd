#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${CACHE_DIRECTORY:-/var/cache/portage-update-checker}"
TARGET_USER="jkyon"
WAYBAR_SIGNAL_NUM=8

mkdir -p "${CACHE_DIR}"
python3 /usr/local/bin/write-portage-cache.py "${CACHE_DIR}/status.json"
chown "${TARGET_USER}:${TARGET_USER}" "${CACHE_DIR}/status.json"
chmod 644 "${CACHE_DIR}/status.json"

pkill -RTMIN+"${WAYBAR_SIGNAL_NUM}" waybar || true
