#!/bin/bash
# Vigia da TheseusMachine, rodando no Builder (as duas ficam 24/7).
# Os alertas do parque saem do Grafana da TheseusMachine pro ntfy: se ela cair,
# ninguém avisa. Este script cobre esse ponto cego.
#
# A cada disparo (theseus-watchdog.timer, 2 min) testa o /api/health do Grafana
# pelo Tailscale. Na 3ª falha seguida (~6 min) manda UM aviso pro ntfy; quando
# volta a responder, manda "voltou" e zera. Antes de contar a falha, confere se
# o próprio Builder tem saída pra internet (senão o problema é dele, não dela).
#
# Tópico em /etc/theseus-watchdog/ntfy.conf (root 0600, fora do git: no ntfy.sh
# público o nome do tópico funciona como credencial). Conteúdo:
#   NTFY_URL="https://ntfy.sh/<tópico>"
#
# Teste sem derrubar nada: HEALTH_URL=http://100.100.10.10:1/ theseus-watchdog.sh
set -euo pipefail

CONF=/etc/theseus-watchdog/ntfy.conf
STATE_DIR=/var/lib/theseus-watchdog
STATE="$STATE_DIR/state"          # "<falhas seguidas> <já avisou: 0|1>"
HEALTH_URL="${HEALTH_URL:-http://100.100.10.10:3000/api/health}"
THRESHOLD=3

# shellcheck source=/dev/null
. "$CONF"
: "${NTFY_URL:?NTFY_URL ausente em $CONF}"

mkdir -p "$STATE_DIR"
read -r fails alerted 2>/dev/null < "$STATE" || { fails=0; alerted=0; }

ntfy() { # título, prioridade, tags, mensagem
    curl -fsS --max-time 15 -H "Title: $1" -H "Priority: $2" -H "Tags: $3" \
        -d "$4" "$NTFY_URL" >/dev/null
}

if curl -fsS --max-time 10 "$HEALTH_URL" >/dev/null 2>&1; then
    if (( alerted )); then
        ntfy "TheseusMachine voltou" default white_check_mark \
            "Grafana respondendo de novo (visto do Builder)."
        echo "voltou depois de $fails falhas, aviso enviado"
    fi
    echo "0 0" > "$STATE"
    exit 0
fi

# Sem internet no Builder: não conta (nem teria como avisar).
if ! curl -fsS --max-time 10 -o /dev/null "${NTFY_URL%/*}/v1/health"; then
    echo "Builder sem saída pro ntfy; falha da TheseusMachine não contada" >&2
    exit 0
fi

fails=$(( fails + 1 ))
echo "Grafana sem resposta ($fails/$THRESHOLD): $HEALTH_URL"
if (( fails >= THRESHOLD && ! alerted )); then
    ntfy "TheseusMachine sem resposta" high rotating_light \
        "Grafana (${HEALTH_URL}) não responde há ${fails} tentativas seguidas, visto do Builder. Sem ele, os alertas do parque estão parados."
    alerted=1
fi
echo "$fails $alerted" > "$STATE"
