#!/bin/sh
type getargbool > /dev/null 2>&1 || . /lib/dracut-lib.sh

getargbool 0 rd.snapshot.overlay || return 0

if [ "$(btrfs property get -ts "$NEWROOT" ro 2> /dev/null)" != "ro=true" ]; then
    warn "rd.snapshot.overlay: o root não é um subvolume read-only, nada feito"
    return 0
fi

# bind + overlay por cima (e não mount --move): no initramfs com systemd o
# /sysroot fica sob uma montagem compartilhada, e o kernel recusa o --move
# ("moving a mount residing under a shared mount is unsupported").
base=/run/snapshot-overlay
mkdir -p "$base/lower" "$base/upper" "$base/work"
mount --bind "$NEWROOT" "$base/lower" || return 0
if ! mount -t overlay snapshot-overlay \
    -o "lowerdir=$base/lower,upperdir=$base/upper,workdir=$base/work" "$NEWROOT"; then
    warn "rd.snapshot.overlay: falha ao montar o overlay, seguindo read-only"
    umount "$base/lower"
    return 0
fi
info "rd.snapshot.overlay: snapshot com overlay gravável em RAM ($base/upper)"
