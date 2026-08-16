#!/bin/bash
set -euo pipefail

NAME="systemd-failsafe-monitor"
LOG_DIR="${HOME}/.logs/${NAME}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/${NAME}"
FAILED_SERVICES_CACHE="${CACHE_DIR}/failed-services.txt"
MONITOR_LOG="${LOG_DIR}/monitor.log"
NOTIFICATION_TIMEOUT=10000
NOTIFICATION_URGENCY="critical"

mkdir -p "${LOG_DIR}" "${CACHE_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${MONITOR_LOG}"
}

send_notification() {
    local title="$1"
    local message="$2"
    notify-send \
        --urgency="${NOTIFICATION_URGENCY}" \
        --expire-time="${NOTIFICATION_TIMEOUT}" \
        --app-name="${NAME}" \
        --icon="dialog-warning" \
        "${title}" \
        "${message}"
    log "Notificacao enviada: ${title} - ${message}"
}

get_failed_services() {
    {
        systemctl --user list-units --failed --no-pager --plain --no-legend 2>/dev/null \
            | awk '{print "user:" $1}'
        systemctl list-units --failed --no-pager --plain --no-legend 2>/dev/null \
            | awk '{print "system:" $1}'
    }
}

has_own_handler() {
    local scoped="$1"
    local scope="${scoped%%:*}"
    local service="${scoped#*:}"
    local flag=""
    [[ "${scope}" == "user" ]] && flag="--user"

    local onfailure
    onfailure=$(systemctl ${flag} show "${service}" --property=OnFailure --value 2>/dev/null)
    [[ -n "${onfailure}" ]]
}

get_service_info() {
    local scoped="$1"
    local scope="${scoped%%:*}"
    local service="${scoped#*:}"
    local flag=""
    [[ "${scope}" == "user" ]] && flag="--user"

    local active_status
    active_status=$(systemctl ${flag} show "${service}" --property=ActiveState --value 2>/dev/null || echo "Unknown")

    local last_error
    last_error=$(journalctl ${flag} -u "${service}" -n 1 --no-pager 2>&1 | tail -1 || echo "Sem logs disponiveis")

    echo "Escopo: ${scope} | Status: ${active_status}"
    echo "Ultimo log: ${last_error}"
}

check_new_failures() {
    local current_failed="$1"
    local previous_failed=""

    if [[ -f "${FAILED_SERVICES_CACHE}" ]]; then
        previous_failed=$(cat "${FAILED_SERVICES_CACHE}")
    fi

    echo "${current_failed}" > "${FAILED_SERVICES_CACHE}"

    if [[ -z "${previous_failed}" ]]; then
        echo "${current_failed}"
    else
        comm -23 <(echo "${current_failed}" | sort) <(echo "${previous_failed}" | sort)
    fi
}

main() {
    log "=== Iniciando verificacao (system + user) ==="

    failed_services=$(get_failed_services)

    if [[ -z "${failed_services}" ]]; then
        log "Nenhuma unit falhada detectada"
        exit 0
    fi

    new_failures=$(check_new_failures "${failed_services}")

    if [[ -z "${new_failures}" ]]; then
        log "Falhas ja conhecidas, nada novo"
        exit 0
    fi

    while IFS= read -r scoped; do
        [[ -z "${scoped}" ]] && continue
        service="${scoped#*:}"

        if has_own_handler "${scoped}"; then
            log "Pulando ${scoped} - ja tem OnFailure= proprio configurado"
            continue
        fi

        log "Nova falha sem handler proprio: ${scoped}"
        service_info=$(get_service_info "${scoped}")
        send_notification "Servico Falhado: ${service}" "${service_info}"
        log "${service_info}"
    done <<< "${new_failures}"

    log "=== Verificacao concluida ==="
}

main "$@"
