#!/bin/bash
# Restringe portas de containers Docker publicadas em 0.0.0.0 à Tailscale + LAN do
# escritório. Necessário porque o Docker manipula nftables direto (tabelas
# `nat`/DNAT e `filter`/FORWARD), o que ignora completamente as regras do ufw
# (chain INPUT) — achado da auditoria de segurança 2026-08-31, ver
# machines/viamar-pc.md. DOCKER-USER é a chain oficial que o Docker garante não
# sobrescrever (só garante que ela exista e que o FORWARD pule pra ela cedo).
#
# Disparado via ExecStartPost do docker.service (drop-in, não mexe na unit
# package-owned) — roda de novo em todo start do dockerd, já que a chain é
# recriada vazia a cada boot (regras nftables não persistem por padrão).
set -euo pipefail

nft flush chain ip filter DOCKER-USER 2>/dev/null || true
nft flush chain ip6 filter DOCKER-USER 2>/dev/null || true

# borg-ui (porta 8081) — só Tailscale (100.64.0.0/10) + LAN do escritório (192.168.5.0/24)
nft add rule ip filter DOCKER-USER ip saddr 100.64.0.0/10 tcp dport 8081 accept
nft add rule ip filter DOCKER-USER ip saddr 192.168.5.0/24 tcp dport 8081 accept
nft add rule ip filter DOCKER-USER tcp dport 8081 counter drop

# equivalente IPv6 (Tailscale v6)
nft add rule ip6 filter DOCKER-USER ip6 saddr fd7a:115c:a1e0::/48 tcp dport 8081 accept 2>/dev/null || true
nft add rule ip6 filter DOCKER-USER tcp dport 8081 counter drop 2>/dev/null || true
