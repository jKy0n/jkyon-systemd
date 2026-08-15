#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${CACHE_DIRECTORY:?CACHE_DIRECTORY não definida — rode via systemd}"
TARGET_USER="jkyon"
WAYBAR_SIGNAL_NUM=8   # precisa bater com "signal" no módulo custom da waybar (Fase 2)

emerge --sync
eix-update

python3 /usr/local/bin/write-portage-cache.py "${CACHE_DIR}/status.json"

chown "${TARGET_USER}:${TARGET_USER}" "${CACHE_DIR}/status.json"
chmod 644 "${CACHE_DIR}/status.json"

pkill -RTMIN+"${WAYBAR_SIGNAL_NUM}" waybar || true
