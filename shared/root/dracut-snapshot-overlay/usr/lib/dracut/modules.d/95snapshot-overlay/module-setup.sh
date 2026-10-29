#!/bin/bash
# Boot de snapshot do grub-btrfs com overlay gravável em RAM (equivalente dracut
# do hook grub-btrfs-overlayfs do mkinitcpio). Só age com rd.snapshot.overlay=1
# no cmdline (que só as entradas de snapshot têm) e se o root montado for um
# subvolume read-only. O 70overlayfs do próprio dracut não serve: ele depende
# do /run/rootfsbase, que só o boot "live" (dmsquash-live) cria.

check() {
    require_binaries btrfs || return 1
    return 255
}

depends() {
    echo btrfs
}

installkernel() {
    hostonly='' instmods overlay
}

install() {
    inst_hook pre-pivot 50 "$moddir/snapshot-overlay.sh"
}
