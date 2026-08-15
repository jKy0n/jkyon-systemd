#!/usr/bin/env bash
set -euo pipefail

MIRRORS_FILE="/etc/portage/mirrors.list"
TMP_FILE="$(mktemp "${MIRRORS_FILE}.XXXXXX")"
trap 'rm -f "${TMP_FILE}"' EXIT

mirrorselect --server=5 --md5=md5 --output > "${TMP_FILE}"

if [ ! -s "${TMP_FILE}" ]; then
    echo "mirrorselect nao retornou nenhum mirror - abortando, mantendo lista anterior" >&2
    exit 1
fi

mv "${TMP_FILE}" "${MIRRORS_FILE}"
echo "Mirrors atualizados em ${MIRRORS_FILE}"
