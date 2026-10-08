#!/bin/bash
# Resume de S3 com as CPUs 5/21 offline quebra o NVMe raiz (nvme0): o
# controlador é reinicializado no resume e realoca as IRQs gerenciadas
# espalhadas por todas as CPUs possíveis — as filas q6/q22 ficam com
# afinidade nas CPUs 5/21 (offline, IRQ desligada), mas o blk-mq continua
# mandando I/O das CPUs 20/28 pra elas. Completion nunca chega, só via
# "I/O tag … timeout, completion polled" a cada 30s (incidente 2026-10-07).
# Religa o core 5 só durante o sleep e desliga de novo depois do resume —
# hotplug normal migra as IRQs direito (validado ao vivo em 2026-10-07).
case "$1" in
    pre)
        echo 1 > /sys/devices/system/cpu/cpu5/online
        echo 1 > /sys/devices/system/cpu/cpu21/online
        logger "mce-offline-core5: CPUs 5/21 online antes do $2"
        ;;
    post)
        echo 0 > /sys/devices/system/cpu/cpu5/online
        echo 0 > /sys/devices/system/cpu/cpu21/online
        logger "mce-offline-core5: CPUs 5/21 offline de novo após $2"
        ;;
esac
