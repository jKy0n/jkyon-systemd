#!/bin/bash
# Atualiza o borg-ui (ainullcode/borg-ui:latest) do compose em
# ~/Apps/docker/borg-ui-docker. O ":latest" só anda com pull: sem isto a imagem
# fica parada (TheseusMachine ficou na 2.0.6 de 2026-04 até 2026-11-08).
# Roda pelo borg-ui-autoupdate.timer (semanal). Falha -> notify-failure.
#
# - Sem imagem nova: sai sem mexer em nada.
# - Imagem nova: a anterior fica como :previous; espera não ter borg rodando no
#   container (até 60 min, senão adia pro próximo disparo); reinicia a
#   borg-ui.service e espera o container ficar healthy (até 3 min).
#
# Rollback: "image: ainullcode/borg-ui:previous" no docker-compose.yml +
# systemctl restart borg-ui.service, e
# systemctl disable --now borg-ui-autoupdate.timer até resolver.
set -euo pipefail
DIR=/home/jkyon/Apps/docker/borg-ui-docker
IMAGE=ainullcode/borg-ui
cd "$DIR"

image_id() { docker image inspect -f '{{.Id}}' "$IMAGE:latest" 2>/dev/null || true; }
container() { docker compose ps -q | head -1; }

old=$(image_id)
[[ -n $old ]] && docker image tag "$IMAGE:latest" "$IMAGE:previous"
docker compose pull -q
new=$(image_id)
if [[ $new == "$old" ]]; then
    # o label org.opencontainers.image.version só traz o minor (2.4); APP_VERSION é completo
    echo "sem imagem nova ($(docker image inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGE:latest" | sed -n 's/^APP_VERSION=//p'))"
    exit 0
fi
echo "imagem nova: ${old:7:12} -> ${new:7:12}"

# Não derrubar backup/restore/prune em andamento (o container não tem pgrep)
for i in $(seq 60); do
    cid=$(container)
    [[ -z $cid ]] && break
    procs=$(docker top "$cid" -eo pid,args)  # sem pipe direto: grep -q + pipefail = falso negativo
    grep -qE '(^|[ /])borg2?( |$)' <<<"$procs" || break
    if (( i == 60 )); then
        echo "borg rodando há 60 min: adiado pro próximo disparo"
        exit 0
    fi
    echo "borg rodando no container, esperando..."
    sleep 60
done

old_ver=$(docker exec "$(container)" printenv APP_VERSION 2>/dev/null || echo '?')
systemctl restart borg-ui.service

state=
for i in $(seq 36); do
    sleep 5
    cid=$(container)
    [[ -z $cid ]] && continue
    # healthy com healthcheck; running quando o compose não tem healthcheck
    state=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")
    if [[ $state == healthy || $state == running ]]; then
        echo "borg-ui $old_ver -> $(docker exec "$cid" printenv APP_VERSION) ($state)"
        docker image prune -f --filter "label=org.opencontainers.image.title=borg-ui" >/dev/null
        exit 0
    fi
done
echo "ERRO: container não ficou healthy em 3 min (estado: ${state:-sem container})"
exit 1
