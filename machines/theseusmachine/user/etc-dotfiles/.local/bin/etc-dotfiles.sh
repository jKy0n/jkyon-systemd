#!/bin/bash
SRC="/etc"
DEST="$HOME/.theseusMachine-core/etc"
FILTER="/etc/.rsync-filter"
{
    mkdir -p "$DEST" &&
    rsync -av --delete --filter="dir-merge $FILTER" "$SRC/" "$DEST/" &&
    cd "$HOME/.theseusMachine-core" &&
    git add . &&
    git diff --cached --quiet || git commit -m "Sync configs $(date +'%Y-%m-%d %H:%M')" &&
    git push
} || notify-send -u critical "Erro ao sincronizar /etc" "Backup e commit dos arquivos de configuração falhou!"
