# jkyon-systemd

Systemd units, timers e scripts atrelados, versionados e gerenciados via GNU Stow.
Repositório central único — não um por máquina (ver seção "Por que um repo só").

## Estrutura

Dois eixos ortogonais organizam o repositório:

1. **Abrangência** (pasta de topo): quantas máquinas aquela unit serve
2. **Permissão** (`root/` ou `user/`, dentro de cada escopo): quem roda a unit
3.
```
jkyon-systemd/
  ├── shared/ # funciona em QUALQUER máquina, QUALQUER distro
  │   ├── root/
  │   └── user/
  ├── gentoo/ # específico de distro, qualquer máquina Gentoo
  │   ├── root/
  │   └── user/
  ├── arch/ # específico de distro, qualquer máquina Arch (ainda vazio)
  │   ├── root/
  │   └── user/
  └── machines/ # específico de UMA máquina só (ainda vazio)
      └── <hostname>/
          ├── root/
          └── user/
```

Cada pasta de pacote (ex: `gentoo/root/portage-auto-sync/`) espelha o caminho de
destino real do filesystem por dentro dela (ex:
`gentoo/root/portage-auto-sync/etc/systemd/system/foo.service` vira
`/etc/systemd/system/foo.service` quando stowado).

Nota: git não versiona diretório vazio. `arch/` e `machines/` só vão aparecer
de verdade num `git status`/clone quando tiverem algum arquivo dentro.

## Onde uma unit nova deve entrar — árvore de decisão

1. Funcionaria em qualquer distro? → `shared/`
2. Não, mas funcionaria em qualquer máquina *dessa* distro? → `gentoo/` ou `arch/`
3. Só faz sentido nessa máquina específica (hardware, hostname, algo físico único)? → `machines/<nome>/`

## Por que um repo só (não um por máquina)

Boa parte da infra (ex: `notify-failure`) não é específica de uma máquina nem
de uma distro — é genérica. Um repo por máquina duplicaria isso 4x sem motivo.
A escolha de arquitetura foi: **repo único, escopo interno explícito**. Cada
máquina, ao aplicar, só roda `stow` nos escopos que fazem sentido pra ela
(uma Arch nunca referencia `gentoo/`, por exemplo).

## Pacotes atuais

| Pacote | Escopo | O que faz |
|---|---|---|
| `notify-failure` | `shared/root/` | Infra compartilhada: dispara notificação crítica (ponte pro DBus de sessão do usuário) quando qualquer unit referenciar `OnFailure=notify-failure@%n.service` |
| `portage-auto-sync` | `gentoo/root/` | Timer B: sync diário do Portage + eix-update + cache JSON de pacotes desatualizados, consumido pela waybar via signal |
| `mirrorselect-update` | `gentoo/root/` | Timer C: mirrorselect semanal (quarta 04h), com wake-from-suspend e auto-suspend após sucesso |

## Convenções

- **Signal da waybar**: `portage-auto-sync` usa `pkill -RTMIN+8 waybar`. Qualquer
  timer futuro que precise sinalizar a waybar deve usar um número **diferente**
  de 8, pra não colidir.
- **Notificação de falha**: toda `.service` que rode desatendido (via timer)
  deve ter `OnFailure=notify-failure@%n.service`.
- **Cache em `/var/cache/`**: dados regeneráveis (JSON de status, etc.) usam
  `CacheDirectory=` na unit, nunca caminho hardcoded — evita problema de
  permissão e centraliza a limpeza.
- **Escrita atômica em `/etc`**: qualquer script que sobrescreva um arquivo de
  config do sistema (ex: `mirrors.list`) escreve num temp file no mesmo
  diretório primeiro, valida o conteúdo, só então usa `mv` pra trocar.
  Lembrar de restaurar a permissão certa depois do `mv` (`mktemp` cria `0600`
  por padrão, config normalmente precisa de `0644`).

## Aplicando um pacote

Sempre testar com `-n` (dry-run) antes:

```bash
sudo stow -n -v --dir=<escopo>/root --target=/ <pacote>
```

Se o output bater com o esperado, aplica de verdade (sem `-n`):

```bash
sudo stow --dir=<escopo>/root --target=/ <pacote>
sudo systemctl daemon-reload
```

## Migrando unit já existente e solta em /etc

Se o arquivo já existe de verdade em `/etc/systemd/system/` (não é symlink),
o stow recusa sobrescrever. Usar `--adopt` pra puxar o arquivo real existente
pra dentro do repo (ele vira o "source of truth", e o stow cria o symlink):

```bash
sudo stow --adopt --dir=<escopo>/root --target=/ <pacote>
git status   # conferir o que --adopt trouxe antes de commitar
git diff     # se der diff, o arquivo real divergia do que estava documentado
```

## Testando antes de confiar

Unit com `OnSuccess=`/`OnFailure=` encadeando outra ação (ex: suspend) deve
ser testada em duas etapas, nessa ordem:

1. Rodar o **script** isolado, direto (`sudo /caminho/script.sh`) — zero
   efeito colateral do systemd envolvido.
2. Só depois, rodar a **unit completa** (`systemctl start`) — sabendo de
   antemão qualquer efeito encadeado (`mirrorselect-update.service`, por
   exemplo, suspende a máquina de verdade em caso de sucesso).

## TODOs conhecidos (não bloqueantes)

- `write-portage-cache.py`: o exit code do `eix -cu` quando não há NENHUMA
  atualização pendente (0 matches) não foi confirmado em execução real ainda.
  O script trata 0 e 1 como "execução válida" — validar isso da próxima vez
  que o sistema estiver 100% atualizado.
## Setup após clonar

```bash
git config core.hooksPath .githooks
```

Ativa o hook de pre-commit (`gitleaks`) que bloqueia commit se detectar segredo
no staged diff. Requer `gitleaks` instalado (`eix -S gitleaks`).

### Setup do systemd-failsafe-monitor (primeira vez em cada máquina)

```bash
mkdir -p ~/.logs/systemd-failsafe-monitor ~/.cache/systemd-failsafe-monitor
```

Necessário porque `ReadWritePaths=` no sandbox exige que o diretório já
exista no disco antes do processo iniciar — o `mkdir -p` interno do script
roda tarde demais (depois do mount namespace já montado).
