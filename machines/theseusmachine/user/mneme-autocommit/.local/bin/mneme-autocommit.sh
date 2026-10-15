#!/usr/bin/env bash
#
#        Title:      mneme-autocommit.sh
#        Brief:      Commit automático do vault Mneme (só se houver mudança).
#        Path:       ~/.local/bin/mneme-autocommit.sh
#        Notes:      Versiona edições que chegam pelo Syncthing (celular) ou
#                     feitas no Obsidian da TM. Repo local, SEM remote: nunca
#                     faz push. Rodada com commit em andamento (index.lock, ex:
#                     a Mneme processando o inbox) é pulada, não é falha.
#

set -euo pipefail

VAULT="$HOME/Documents/Obsidian/mneme"

cd "$VAULT"

if [[ -e .git/index.lock ]]; then
    echo "index.lock presente — commit em andamento, pulando esta rodada."
    exit 0
fi

if [[ -z "$(git status --porcelain)" ]]; then
    echo "Sem mudanças."
    exit 0
fi

git add -A
git commit -q -m "auto: $(date '+%Y-%m-%d %H:%M')"
git log --oneline -1
