# archive/theseusmachine

Units systemd fora de uso hoje, preservadas por terem valor de referência
futura. **Nunca são stowadas** — vivem fora de `shared/`, `gentoo/`,
`machines/`, então nenhum comando `stow` toca nelas. É leitura pura.

Se algo daqui um dia voltar a fazer sentido, o processo é: copiar pra dentro
do escopo certo (`shared/`, `gentoo/`, ou `machines/<nome>/`), ajustar o que
for preciso, aplicar via `stow` normalmente — igual qualquer pacote novo.

## Por que essas units estão aqui

Todas datam de quando a TheseusMachine rodava **AwesomeWM sobre X11**, antes
da migração pra niri/Wayland. Nenhuma delas roda hoje — dependem de coisas
específicas de X11 (`DISPLAY=:0`, compositor `picom`) que não existem sob
Wayland.

Motivo de preservar, não descartar: o dono do repositório mantém a
possibilidade em aberto de voltar a rodar Awesome/X11 no futuro (ou testar
outro compositor de janelas fora do Wayland). Se isso acontecer, essas
5 units são o ponto de partida - não precisam ser reescritas do zero.

## Conteúdo

| Unit | Papel |
|---|---|
| `jkyon-picom.service` | Compositor X11 (transparência, sombras, vsync) |
| `jkyon-picom-memoryUsageMonitor.service`/`.timer` | Monitorava uso de memória do picom, reiniciava se necessário |
| `jkyon-picom-restartRoutine.service`/`.timer` | Reinício periódico do picom (workaround de estabilidade) |
| `lockScreen.service` + `lockScreen.sh` | Tela de bloqueio, dependia de `DISPLAY=:0` |

## Nota sobre versões antigas descartadas (não arquivadas)

Durante a migração pro `jkyon-systemd`, várias outras units antigas foram
**descartadas sem arquivar** (não preservadas aqui) por serem substituídas
diretamente por uma versão atual em produção, ou por não terem valor de
referência (testes manuais, experimentos de app específico). O histórico
delas continua acessível via `git log` do repositório `~/ShellScript`, que
não teve seu histórico apagado.
