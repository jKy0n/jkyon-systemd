#!/usr/bin/env bash
set -euo pipefail

SYNC_MAX_TRIES=3
SYNC_RETRY_DELAY=90  # segundos — dá tempo do mirror rsync do Gentoo terminar de publicar o snapshot

sync_ok=0
for i in $(seq 1 "${SYNC_MAX_TRIES}"); do
    if emerge --sync; then
        sync_ok=1
        break
    fi
    echo "emerge --sync falhou (tentativa ${i}/${SYNC_MAX_TRIES})" >&2
    if [ "${i}" -lt "${SYNC_MAX_TRIES}" ]; then
        echo "Aguardando ${SYNC_RETRY_DELAY}s antes de tentar novamente..." >&2
        sleep "${SYNC_RETRY_DELAY}"
    fi
done

if [ "${sync_ok}" -ne 1 ]; then
    echo "emerge --sync falhou após ${SYNC_MAX_TRIES} tentativas — desistindo" >&2
    exit 1
fi

/usr/local/bin/refresh-portage-cache.sh
