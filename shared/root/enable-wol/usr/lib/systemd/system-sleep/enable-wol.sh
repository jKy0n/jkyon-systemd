#!/bin/bash
# A Realtek (r8169) zera o modo de WOL a cada transição S3, e o NetworkManager
# (802-3-ethernet.wake-on-lan=magic no br0-slave) só aplica ao ativar a conexão,
# não depois de um resume. Sem este hook, só o 1º suspend depois do boot acorda
# por magic packet. Reaplica antes de cada suspend.
case "$1" in
    pre)
        ethtool -s enp6s0 wol g
        logger -t enable-wol "WOL (magic packet) reaplicado no enp6s0"
        ;;
esac
