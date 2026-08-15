#!/usr/bin/env bash
set -uo pipefail

CACHE_FILE="/var/cache/portage-update-checker/status.json"

OUTPUT=$(jq -c '
    {
        text: (if .count > 0 then "\u2193 " + (.count|tostring) else "" end),
        tooltip: (if .count > 0 then (.packages | join("\n")) else "Sistema atualizado" end),
        class: (if .count > 0 then "has-updates" else "" end)
    }
' "$CACHE_FILE" 2>/dev/null)

if [ -z "$OUTPUT" ]; then
    echo '{"text": "", "tooltip": "Cache do Portage indisponivel"}'
else
    echo "$OUTPUT"
fi
