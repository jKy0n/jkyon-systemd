#!/bin/bash
# Resume de S3 força COMRESET no link SATA, que reseta o timer de
# standby programado no disco de volta pro default (desabilitado) —
# mesmo tipo de problema já documentado pro WOL desta máquina
# (enable-wol.sh), mas reagindo em "post" (depois do resume), não "pre":
# o timer de standby só é resetado durante o próprio resume.
case "$1" in
    post)
        /usr/bin/hdparm -S 180 /dev/disk/by-id/ata-WDC_WD11PURZ-85C5HY0_WD-WCC4J7NXS8DN
        logger "hdd-backup-standby: timer de standby reaplicado após resume"
        ;;
esac
