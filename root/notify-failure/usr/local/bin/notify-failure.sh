#!/usr/bin/env bash
set -euo pipefail

FAILED_UNIT="${1:?uso: notify-failure.sh <nome-da-unit>}"
TARGET_USER="jkyon"
UID_NUM="$(id -u "$TARGET_USER")"

XDG_RUNTIME_DIR="/run/user/${UID_NUM}"
DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
ICON="/usr/share/icons/Papirus/48x48/status/dialog-error.svg"

runuser -u "$TARGET_USER" -- \
    env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    notify-send --urgency=critical -i "$ICON" \
        "Falha: ${FAILED_UNIT}" \
        "Rode: journalctl -u ${FAILED_UNIT} -e"
