#!/usr/bin/env bash
#
#       Title:      hdd-backup-standby-check.sh
#       Brief:      Standby do HDD de backup (WD Purple) após 30min sem I/O de bloco.
#       Author:     John Kennedy a.k.a. jKyon
#       Notes:      Roda a cada 1min via hdd-backup-standby-check.timer (root).
#                   Substitui o timer interno do disco (hdparm -S): o firmware
#                   do WD Purple ignora esse timer (testado com -S 12 = 1min,
#                   150s sem I/O e sem poll do udisks2, disco seguiu ativo),
#                   mas aceita standby imediato (hdparm -y). A ociosidade é
#                   medida pelos contadores de I/O de bloco
#                   (/sys/block/<dev>/stat), que comandos ATA passthrough
#                   (SMART do udisks2, hdparm -C) não alteram.
#

set -euo pipefail

DISK_ID="/dev/disk/by-id/ata-WDC_WD11PURZ-85C5HY0_WD-WCC4J7NXS8DN"
IDLE_SECS=1800
STATE="/run/hdd-backup-standby.state"

dev=$(readlink -f "$DISK_ID")
[[ -b "$dev" ]] || { echo "disco não encontrado: $DISK_ID" >&2; exit 1; }

# reads completed + writes completed
io=$(awk '{print $1, $5}' "/sys/block/${dev##*/}/stat")
now=$(date +%s)

if [[ -f "$STATE" ]]; then
    read -r last_io_r last_io_w last_change < "$STATE"
    if [[ "$io" != "$last_io_r $last_io_w" ]]; then
        echo "$io $now" > "$STATE"
        exit 0
    fi
else
    echo "$io $now" > "$STATE"
    exit 0
fi

(( now - last_change >= IDLE_SECS )) || exit 0

if hdparm -C "$dev" | grep -q 'active/idle'; then
    hdparm -y "$dev" >/dev/null
    logger -t hdd-backup-standby "standby após $(( (now - last_change) / 60 ))min sem I/O ($dev)"
fi
