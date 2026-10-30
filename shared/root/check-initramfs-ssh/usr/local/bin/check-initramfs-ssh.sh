#!/bin/bash
# Confere se o boot consegue destravar o LUKS por SSH (dropbear no initramfs,
# sys-kernel/dracut-crypt-ssh). Roda no boot (check-initramfs-ssh.service) e a
# cada kernel novo (95-check-initramfs-ssh.install). Falha -> notify-failure.
# Pega: initramfs sem dropbear/rede/chaves, host key trocada, grub.cfg sem o ip=,
# e o ip= do cmdline que não é mais o IP da máquina (mudou a LAN: ver o
# checklist "mudou a LAN do escritório" no AGENTS.md do jkyon-ai-context).
set -uo pipefail
KEY=/etc/dropbear/initramfs_ed25519_key
ACL=/etc/dropbear/initramfs_authorized_keys
fail=0
ok()  { echo "ok: $*"; }
err() { echo "ERRO: $*"; fail=1; }

# 1. cmdline do GRUB: ip= com o IP atual + rd.neednet=1, e o grub.cfg regenerado
cmdline=$(. /etc/default/grub; echo "${GRUB_CMDLINE_LINUX:-}")
ipspec=$(tr ' ' '\n' <<<"$cmdline" | grep -m1 '^ip=')
if [[ -z $ipspec ]]; then
    err "GRUB_CMDLINE_LINUX sem ip="
else
    addr=${ipspec#ip=}; addr=${addr%%:*}
    if ip -4 -o addr show | grep -q " inet $addr/"; then
        ok "ip=$addr é um IP desta máquina"
    else
        err "ip=$addr não é IP desta máquina (mudou a LAN?)"
    fi
    grep -q "ip=$addr:" /boot/grub/grub.cfg && ok "grub.cfg tem o ip=" \
        || err "grub.cfg sem o ip=$addr (rodar grub-mkconfig)"
fi
grep -qw 'rd.neednet=1' <<<"$cmdline" && ok "rd.neednet=1" || err "GRUB_CMDLINE_LINUX sem rd.neednet=1"

# 2. cada initramfs: dropbear, rede, nossa host key, nossa lista de chaves
want_fp=$(ssh-keygen -lf "$KEY.pub" | awk '{print $2}')
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
shopt -s nullglob
imgs=(/boot/initramfs-*.img)
(( ${#imgs[@]} )) || err "nenhum /boot/initramfs-*.img"
for img in "${imgs[@]}"; do
    n=${img##*/}
    list=$(lsinitrd "$img" 2>/dev/null) || { err "$n: lsinitrd falhou"; continue; }
    for f in usr/bin/dropbear usr/lib/systemd/systemd-networkd \
             root/.ssh/authorized_keys etc/dropbear/dropbear_ed25519_host_key; do
        grep -q " $f\$" <<<"$list" || err "$n: falta $f"
    done
    lsinitrd -f etc/dropbear/dropbear_ed25519_host_key "$img" > "$tmp/hk" 2>/dev/null
    fp=$(dropbearkey -y -f "$tmp/hk" 2>/dev/null | grep -o 'SHA256:[^ ]*')
    [[ $fp == "$want_fp" ]] && ok "$n: host key própria ($fp)" \
        || err "$n: host key ${fp:-ausente} != $want_fp"
    if diff -q <(lsinitrd -f root/.ssh/authorized_keys "$img" 2>/dev/null) "$ACL" >/dev/null; then
        ok "$n: authorized_keys = $ACL"
    else
        err "$n: authorized_keys diferente de $ACL (regenerar o initramfs)"
    fi
done

(( fail )) && { echo "FALHOU: o desbloqueio remoto pode não funcionar no próximo boot"; exit 1; }
echo "tudo ok"
