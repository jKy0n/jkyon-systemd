# jkyon-systemd

Systemd units, timers e scripts atrelados, versionados e gerenciados via GNU Stow.

## Estrutura

Cada pasta dentro de `root/` ou `user/` é um **pacote stow independente**.
Dentro de cada pacote, o caminho espelha o destino real no filesystem
(ex: `root/portage-auto-sync/etc/systemd/system/foo.service` vira
`/etc/systemd/system/foo.service`).

- `root/` — pacotes que exigem privilégio de root (target = `/`)
- `user/` — pacotes que vivem dentro do `$HOME` (target = `$HOME`), sem sudo

## Pacotes atuais

- `root/notify-failure/` — infraestrutura compartilhada: dispara notificação
  crítica (via ponte pro DBus de sessão do usuário) quando qualquer unit
  referenciar `OnFailure=notify-failure@%n.service`.
- `root/portage-auto-sync/` — Timer B: sync diário do Portage + eix-update +
  cache JSON de pacotes desatualizados, consumido pela waybar.

## Aplicando um pacote

Sempre testar com `-n` (dry-run) antes:

```bash
sudo stow -n -v --dir=root --target=/ notify-failure
sudo stow -n -v --dir=root --target=/ portage-auto-sync
```

Se o output bater com o esperado, aplica de verdade (sem `-n`):

```bash
sudo stow --dir=root --target=/ notify-failure
sudo stow --dir=root --target=/ portage-auto-sync
```

Depois de linkar, sempre:

```bash
sudo systemctl daemon-reload
```

## Migrando unit já existente e solta em /etc

Se o arquivo já existe de verdade em `/etc/systemd/system/` (não é symlink),
o stow recusa sobrescrever. Usar `--adopt` pra puxar o arquivo real pra
dentro do repo (aí ele vira o "source of truth" e o stow cria o symlink):

```bash
sudo stow --adopt --dir=root --target=/ nome-do-pacote
git status   # conferir o que --adopt trouxe antes de commitar
```
