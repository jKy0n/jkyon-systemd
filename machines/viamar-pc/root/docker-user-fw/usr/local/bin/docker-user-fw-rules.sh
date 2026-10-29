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
#
# Usa iptables/ip6tables (não nft direto) desde 2026-10-27: o Docker cria a
# DOCKER-USER pelo backend do iptables do sistema. No Arch ele é nft, mas no
# Gentoo veio legacy (xtables-legacy), e aí `nft ... ip filter DOCKER-USER` não
# acha a chain, o script falha e derruba o docker.service. O iptables funciona
# nos dois backends.
set -euo pipefail

iptables -F DOCKER-USER 2>/dev/null || true
ip6tables -F DOCKER-USER 2>/dev/null || true

# borg-ui (porta 8081) — só Tailscale (100.64.0.0/10) + LAN do escritório (192.168.15.0/24)
iptables -A DOCKER-USER -s 100.64.0.0/10 -p tcp --dport 8081 -j ACCEPT
iptables -A DOCKER-USER -s 192.168.15.0/24 -p tcp --dport 8081 -j ACCEPT
iptables -A DOCKER-USER -p tcp --dport 8081 -j DROP

# equivalente IPv6 (Tailscale v6)
ip6tables -A DOCKER-USER -s fd7a:115c:a1e0::/48 -p tcp --dport 8081 -j ACCEPT 2>/dev/null || true
ip6tables -A DOCKER-USER -p tcp --dport 8081 -j DROP 2>/dev/null || true
