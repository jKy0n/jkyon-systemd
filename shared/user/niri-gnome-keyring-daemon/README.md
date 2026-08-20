# niri-gnome-keyring-daemon

Daemon de secrets (login keyring) via gnome-keyring, socket-activated.

## Componentes
- `pkcs11,secrets` (SSH fica separado — ver gpg-agent/ssh-support)

## Arquitetura
- `.socket` escuta em `%t/keyring/control` desde o boot do systemd `--user`
- `.service` sobe sob demanda quando algo conecta no socket (inclui o PAM na fase de login)
- `PartOf=graphical-session.target`: daemon morre junto com o niri (decisão
  de segurança — minimiza janela de keyring desbloqueado fora de sessão ativa)

## Problema histórico (resolvido em a5806ab)
**Sintoma:** prompt gráfico "Authentication required" pedindo senha do
keyring toda sessão, mesmo com PAM configurado corretamente em
`/etc/pam.d/greetd`.

**Causa raiz:** unit original usava `WantedBy=graphical-session.target` +
`Requisite=graphical-session.target` — só subia depois do niri estar de pé.
Mas a fase de sessão do PAM (`pam_gnome_keyring.so auto_start`) roda
*durante* o login do greetd, antes do niri existir. Resultado: PAM não
encontrava daemon (`GNOME_KEYRING_CONTROL` ausente) → spawnava um daemon
órfão temporário sob o UID do greeter (948) → desbloqueava ELE, não o seu
→ 5-12s depois o daemon real subia via systemd, já sem senha, trancado.

**Fix:** socket-activation. O `.socket` existe desde o boot do systemd
`--user` (muito antes do niri), então o PAM sempre encontra algo pra
conversar em vez de criar um órfão.

## Diagnóstico se o sintoma voltar
```bash
journalctl -b --user -u niri-gnome-keyring-daemon.service --no-pager | head -30
journalctl -b | grep -i "gnome-keyring\|pam_gnome_keyring"
```
Procurar: timestamp do `Started GNOME Keyring Daemon` (systemd) vs.
`GNOME_KEYRING_CONTROL=/run/user/1000/keyring` (daemon real) — devem
bater no mesmo segundo. Se houver gap de vários segundos, a race voltou.

## Replicação em outras máquinas
1. Confirmar `pam_gnome_keyring.so` em `session` (com `auto_start`) e
   `auth` (sem flag) no `/etc/pam.d/greetd` — ou equivalente do DM usado
2. Stow deste pacote
3. `systemctl --user daemon-reload`
4. `systemctl --user enable --now niri-gnome-keyring-daemon.socket`
   (NUNCA `disable` no `.service` antigo primeiro — ver regra geral no
   README raiz do repo)
5. Reboot + validar com o diagnóstico acima — testar 2+ vezes
   (race condition, um sucesso isolado não garante consistência)
