#!/bin/bash
LOAD_THRESHOLD=0.5
IDLE_MIN_THRESHOLD=15
REQUIRED_CHECKS=6
COUNTER_FILE="/run/idle-suspend.counter"

# Menor tempo de inatividade (minutos) entre todos os ttys logados,
# calculado via atime do dispositivo — mesma fonte que o 'who' usa,
# mas sem depender de parsing de texto formatado.
min_tty_idle_minutes() {
    local now min_idle=999999
    now=$(date +%s)
    for tty in $(who | awk '{print $2}' | sort -u); do
        local dev="/dev/$tty"
        [ -c "$dev" ] || continue
        local atime
        atime=$(stat -c '%X' "$dev" 2>/dev/null) || continue
        local idle_min=$(( (now - atime) / 60 ))
        (( idle_min < min_idle )) && min_idle=$idle_min
    done
    echo "$min_idle"
}

is_idle() {
    load=$(awk '{print $1}' /proc/loadavg)
    awk "BEGIN{exit !($load > $LOAD_THRESHOLD)}" && return 1

    ss -tn state established '( sport = :3632 )' | grep -q ESTAB && return 1

    idle_minutes=$(min_tty_idle_minutes)
    [ "$idle_minutes" -lt "$IDLE_MIN_THRESHOLD" ] && return 1

    return 0
}

if is_idle; then
    count=$(( $(cat "$COUNTER_FILE" 2>/dev/null || echo 0) + 1 ))
    echo "$count" > "$COUNTER_FILE"
    if [ "$count" -ge "$REQUIRED_CHECKS" ]; then
        logger "idle-suspend: 30min ocioso (CPU+distcc+TTY), suspendendo Builder"
        echo 0 > "$COUNTER_FILE"
        systemctl suspend
    fi
else
    echo 0 > "$COUNTER_FILE"
fi
