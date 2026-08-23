# archive/builder

Units systemd fora de uso hoje, preservadas por terem valor de referência
futura. **Nunca são stowadas** — vivem fora de `shared/`, `gentoo/`,
`machines/`, então nenhum comando `stow` toca nelas. É leitura pura.

Se algo daqui um dia voltar a fazer sentido, o processo é: copiar pra dentro
do escopo certo (`shared/`, `gentoo/`, ou `machines/<nome>/`), ajustar o que
for preciso, aplicar via `stow` normalmente — igual qualquer pacote novo.

## Por que essas units estão aqui

`idle-suspend.timer` verificava ociosidade do Builder (CPU + conexões distcc
na porta 3632 + tempo de TTY parado) a cada 5min e suspendia a máquina após
~30min ocioso confirmado. Foi **desativado permanentemente em 2026-08-19**,
quando o Builder foi promovido a worker 24/7 fixo do cluster distcc — suspend
automático por ociosidade não combina com esse papel (decisão documentada em
`machines/builder.md` do repo `jkyon-ai-context`). A unit já estava
`disabled`/`inactive` havia meses antes de ser removida do sistema; nada foi
perdido na migração.

Motivo de preservar, não descartar: se o Builder algum dia deixar de ser
worker fixo (voltar a ser máquina de uso esporádico), essas 3 units são o
ponto de partida pra reativar suspend por ociosidade — não precisam ser
reescritas do zero. `systemctl suspend` manual continua disponível via
`ephedrine` (ferramenta própria do Builder), independente disso.

## Conteúdo

| Unit | Papel |
|---|---|
| `idle-suspend.service` | Oneshot que chama o script de verificação |
| `idle-suspend.timer` | Dispara o service a cada 5min (após 10min do boot) |
| `check-idle-suspend.sh` | Lógica real: load avg, conexões ESTABLISHED na porta 3632 (distcc), e idle mínimo entre os TTYs logados via atime de `/dev/tty*`. Após 6 checagens consecutivas ociosas (~30min), chama `systemctl suspend` |
