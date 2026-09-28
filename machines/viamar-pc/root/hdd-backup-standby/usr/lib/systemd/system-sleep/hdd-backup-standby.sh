#!/bin/bash
# Resume de S3 força COMRESET no link SATA e o disco volta girando.
# Zera o estado do hdd-backup-standby-check.sh pra contar os 30min de
# ociosidade a partir do resume (o relógio anda durante a suspensão sem
# o timer rodar — sem isso, o disco poderia ser mandado pra standby logo
# no 1º minuto depois de acordar).
case "$1" in
    post)
        rm -f /run/hdd-backup-standby.state
        logger "hdd-backup-standby: estado de ociosidade zerado após resume"
        ;;
esac
