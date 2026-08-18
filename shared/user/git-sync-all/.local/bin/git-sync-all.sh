#!/usr/bin/env bash
#
#        Title:      git-sync-all.sh
#        Brief:      Sync (git pull --ff-only) all jKyon repos in a defined table.
#        Path:       ~/.local/bin/git-sync-all.sh
#        Notes:      Shared entre toda a frota — o remote não importa pro pull,
#                     só o path local. Repo ausente ou não-git (ex: dotfiles do
#                     Builder, ainda em yadm) é pulado, não é falha.
#

set -u

NAME="git-sync-all"
LOG_DIR="$HOME/.logs/$NAME"
LOG_FILE="$LOG_DIR/${NAME}-error.log"
MAX_LOG_LINES=200

REPOS=(
    "$HOME/.jkyon-ai-context:ai-context"
    "$HOME/.dotfiles:dotfiles"
    "$HOME/.config/nvim:nvim"
    "$HOME/ShellScript:ShellScript"
    "$HOME/.jkyon-systemd:systemd"
    "$HOME/.jKy0n-terminal:terminal"
)

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

trim_log() {
    [[ -f "$LOG_FILE" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"
}

log_error() {
    mkdir -p "$LOG_DIR"
    {
        echo
        echo "[$(timestamp)] ERRO em $(uname -n) — $1"
        echo "$2"
    } >> "$LOG_FILE"
    trim_log
}

notify_error() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send \
        -u critical \
        -a "$NAME" \
        "❌ $NAME: falha em ${#FAILED[@]} repo(s)" \
        "${FAILED[*]} — log: $LOG_FILE" \
        >/dev/null 2>&1 || true
}

FAILED=()

for entry in "${REPOS[@]}"; do
    path="${entry%%:*}"
    repo_name="${entry##*:}"

    [[ -d "$path" ]] || continue
    git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || continue

    output="$(git -C "$path" pull --ff-only 2>&1)"
    status=$?

    if (( status != 0 )); then
        log_error "$repo_name" "$output"
        FAILED+=("$repo_name")
    fi
done

if (( ${#FAILED[@]} > 0 )); then
    notify_error
    exit 1
fi

exit 0
