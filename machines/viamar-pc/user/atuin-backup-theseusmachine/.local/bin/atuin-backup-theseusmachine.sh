#!/usr/bin/env bash
# Backup do Postgres do Atuin (self-hosted na TheseusMachine) -> Viamar-PC
# Pull via SSH não-interativo, dump comprimido, retenção de 14 dias.
set -euo pipefail

DEST="/mnt/backup/atuin-theseusmachine"
TS="$(date +%Y-%m-%d_%H-%M)"
KEY="$HOME/.ssh/viamar_to_theseusmachine-backup-auto"
REMOTE="jkyon@100.100.10.10"

mkdir -p "$DEST"

ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$KEY" "$REMOTE" \
  'docker compose -f ~/Apps/docker/atuin-server/docker-compose.yml exec -T db pg_dump -U atuin atuin' \
  | gzip > "$DEST/atuin-${TS}.sql.gz"

# retenção: mantém só os últimos 14 dumps
cd "$DEST"
ls -1t atuin-*.sql.gz | tail -n +15 | xargs -r rm -v

echo "Backup concluído: $DEST/atuin-${TS}.sql.gz ($(du -h "$DEST/atuin-${TS}.sql.gz" | cut -f1))"
