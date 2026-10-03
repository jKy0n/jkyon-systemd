#!/usr/bin/env bash
#
#       Title:      nginx-tailscale-cert-renew.sh
#       Brief:      Renova o cert Tailscale do nginx (TLS do sccache-scheduler) e recarrega o nginx.
#       Path:       /etc/jkyon-systemd/machines/builder/root/nginx-tailscale-cert-renew/usr/local/bin/nginx-tailscale-cert-renew.sh
#       Author:     John Kennedy a.k.a. jKyon
#       Notes:      Só no Builder. Roda como root via nginx-tailscale-cert-renew.timer (semanal).
#                    `tailscale cert --min-validity` só pede cert novo à CA quando o atual
#                    vale menos que MIN_VALIDITY; fora disso devolve o mesmo cert, então
#                    rodar toda semana é inofensivo. nginx só recarrega se o cert mudou.
#

set -euo pipefail

DOMAIN="builder.tail2aecab.ts.net"
CERT="/etc/nginx/tailscale/builder.crt"
KEY="/etc/nginx/tailscale/builder.key"
MIN_VALIDITY="720h"     # 30 dias — cert Let's Encrypt vale 90
ALERT_DAYS=14           # rede de segurança: falha (OnFailure) se ainda valer menos que isso

before=$(sha256sum "$CERT" 2>/dev/null | cut -d' ' -f1 || true)

tailscale cert --min-validity="$MIN_VALIDITY" --cert-file="$CERT" --key-file="$KEY" "$DOMAIN"

after=$(sha256sum "$CERT" | cut -d' ' -f1)

echo "$(openssl x509 -in "$CERT" -noout -enddate)"

if [[ "$before" != "$after" ]]; then
    echo "Cert renovado — validando config e recarregando nginx"
    nginx -t
    systemctl reload nginx
else
    echo "Cert inalterado — nginx não recarregado"
fi

if ! openssl x509 -in "$CERT" -noout -checkend $(( ALERT_DAYS * 86400 )) >/dev/null; then
    echo "ERRO: cert vence em menos de ${ALERT_DAYS} dias mesmo após a renovação" >&2
    exit 1
fi
