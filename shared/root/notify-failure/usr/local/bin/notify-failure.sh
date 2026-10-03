#!/usr/bin/env bash
set -euo pipefail

FAILED_UNIT="${1:?uso: notify-failure.sh <nome-da-unit>}"
TARGET_USER="jkyon"
UID_NUM="$(id -u "$TARGET_USER")"

XDG_RUNTIME_DIR="/run/user/${UID_NUM}"
DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
ICON="/usr/share/icons/Papirus/48x48/status/dialog-error.svg"

# Canal ntfy: opcional, só liga se este arquivo existir (root 0600, fora do git —
# o nome do tópico no ntfy público funciona como credencial). Conteúdo:
#   NTFY_URL="https://ntfy.sh/<tópico>"
NTFY_CONF="/etc/notify-failure/ntfy.conf"

sent=0

# Canal desktop: notify-send no D-Bus da sessão gráfica. Pulado sem sessão
# (headless, ex.: Builder) em vez de falhar.
if [[ -S "${XDG_RUNTIME_DIR}/bus" ]] && command -v notify-send >/dev/null 2>&1; then
    runuser -u "$TARGET_USER" -- \
        env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        notify-send --urgency=critical -i "$ICON" \
            "Falha: ${FAILED_UNIT}" \
            "Rode: journalctl -u ${FAILED_UNIT} -e" \
        && sent=1
fi

if [[ -r "$NTFY_CONF" ]]; then
    # shellcheck source=/dev/null
    . "$NTFY_CONF"
    curl -fsS --max-time 15 \
        -H "Title: Falha: ${FAILED_UNIT} ($(hostname))" \
        -H "Priority: high" \
        -H "Tags: rotating_light" \
        -d "Rode: journalctl -u ${FAILED_UNIT} -e" \
        "${NTFY_URL:?NTFY_URL ausente em $NTFY_CONF}" >/dev/null \
        && sent=1
fi

if (( ! sent )); then
    echo "Nenhum canal entregou a notificação de ${FAILED_UNIT}" >&2
    exit 1
fi
