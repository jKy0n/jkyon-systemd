#!/usr/bin/env bash
set -euo pipefail

MIRRORS_FILE="/etc/portage/mirrors.list"
KEEP=5
TMP_FILE="$(mktemp "${MIRRORS_FILE}.XXXXXX")"
trap 'rm -f "${TMP_FILE}"' EXIT

# O modo rápido (netselect) devolve o IP em vez do nome quando o host tem vários
# endereços (ex.: Cloudflare), e https://<IP>/ falha no TLS (certificado é do nome).
# Pede mais candidatos, descarta os IPs (v4 e v6) e fica com os KEEP mais rápidos.
mapfile -t urls < <(
    mirrorselect --servers=$((KEEP * 3)) --output 2>/dev/null \
        | grep -oE '(https?|ftp)://[^ "\\]+' \
        | grep -vE '^[a-z]+://([0-9.]+|\[[0-9a-fA-F:]+\])(:[0-9]+)?/' \
        | head -n "${KEEP}"
)

if [ "${#urls[@]}" -eq 0 ]; then
    echo "mirrorselect nao retornou nenhum mirror com nome - abortando, mantendo lista anterior" >&2
    exit 1
fi

printf 'GENTOO_MIRRORS="%s"\n' "${urls[*]}" > "${TMP_FILE}"
mv "${TMP_FILE}" "${MIRRORS_FILE}"
chmod 644 "${MIRRORS_FILE}"
echo "Mirrors atualizados em ${MIRRORS_FILE}: ${urls[*]}"
