<!-- reviewed-up-to: 0.2.29 -->
# Upgrading (what each release asks of you)

*[日本語版](UPGRADING.ja.md)*

**Only the releases that need you to change a file you own are listed here.**
For anything not listed, raising the image tag and running `mise run gw:recreate`
is the whole upgrade. What changed is in the changelogs —
[gateway](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.md) /
[relay](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.md) /
[base](CHANGELOG.md).

"A file you own" means one you copied out of the sample:

| file | whose |
|---|---|
| `.devcontainer/config/config.yml` | yours. The relay's configuration lives here |
| `mise.toml` | yours. The host-side operations |
| `.devcontainer/scripts/sgw.sh` | yours. What finds the container and execs into it |
| `.devcontainer/docker-compose.yml` | yours. The gateway's image tag is here |

## Where to start reading

| the gateway you are on | read from |
|---|---|
| 0.0.x | [0.1.0](#010-the-relay-arrived) onward — but **nothing at all** if you do not want the relay |
| 0.1.0 – 0.1.8 | [0.1.9](#019-permissions-moved) onward |
| 0.1.9 – 0.2.6 | [0.2.7](#027-declare-your-projects-boards-breaking) onward |
| 0.2.7 – 0.2.14 | [0.2.15](#0215-a-secret-store-appeared) onward |
| 0.2.15 – 0.2.18 | [0.2.19](#0219-unlocking-became-required) |
| 0.2.19 – 0.2.21 | [0.2.22](#0222-the-proxy-credential-moved-into-the-store) — **only if your upstream proxy needs a password** |
| 0.2.22 – 0.2.26 | [0.2.27](#0227-tags-have-to-be-signed) — **only if the agent pushes tags** |
| 0.2.27 | [0.2.28](#0228-dependabot-alerts-are-optional) — **only if you want the agent to read Dependabot alerts** |
| 0.2.28 | [0.2.29](#0229-unattended-unlock-is-available) — **only if you want unattended unlock, or AI commits that stay Verified** |

---

## 0.1.0 the relay arrived

**It is opt-in.** Without `domain_handlers` and `relay` in `config.yml` the relay
does not start and you keep the 0.0.x gateway: DNS filtering, the firewall and
Squid, unchanged. No configuration key was removed or renamed —
`allow_domains`, `block_domains`, `allow_ips`, `block_ips`, `proxy`, `network`
and `database_path` all still parse.

To adopt it, see the README's
[0.0.8 section](README.md#008-以前の-gateway-から上げる場合).

## 0.1.9 permissions moved

`relay.allow_tags` and `relay.allow_delete` are deprecated. **They are still
read** — folded into the `relay.project` defaults with a warning at start-up —
so nothing breaks if you leave them. To move:

```yaml
relay:
  project:
    tags: ["*"]        # was relay.allow_tags: true
    delete: true       # was relay.allow_delete: true
```

## 0.2.7 declare your Projects boards (breaking)

**Action required if you use Projects v2.** Without a list of the boards this
project may touch, **every** Projects operation is refused. A board's node id is
opaque and says nothing about its owner, so with no list any board the upstream
token can see would be reachable.

```yaml
relay:
  project:
    boards:
      - { org: acme, number: 3 }       # github.com/orgs/acme/projects/3
      - { user: someone, number: 1 }   # github.com/users/someone/projects/1
```

Nothing to do if you do not use Projects.

The same release renamed `handler: git-relay` to `handler: github`. The old name
**still works as an alias**, so no edit is needed.

## 0.2.13 a window for config reloads

The default is `auto`, which behaves as before. But `config.yml` is writable
from the dev container, so **close the window before handing work to an agent**:

```yaml
reload: manual        # or a duration, e.g. 30m
```

```bash
mise run gw:reload-freeze    # close it now
mise run gw:reload-status    # which is it
```

This needs the three `gw:reload-*` tasks in `mise.toml` (they are in the sample).

## 0.2.15 a secret store appeared

`mise.toml` needs the unlock tasks, and `sgw.sh` needs **`gw-tty`** — the branch
that gets a terminal to the passphrase prompt. The plain `gw` decides on `-t` by
looking at stdout as well, and a task runner makes stdout a pipe, so the prompt
ends up with no terminal.

Take them from the sample:

```bash
diff -u <base>/examples/sgw-sample/mise.toml mise.toml
diff -u <base>/examples/sgw-sample/.devcontainer/scripts/sgw.sh .devcontainer/scripts/sgw.sh
```

The tasks: `gw:unlock` `gw:lock` `gw:store-status` `gw:passphrase`

## 0.2.18 the store can be backed up

Add `gw:store-export` / `gw:store-import` to `mise.toml`. An export needs no key,
so it works on a locked store. It stays sealed, but **the passphrase is the only
thing guarding it**.

## 0.2.19 unlocking became required

**The upstream API token now lives in the secret store, so the relay cannot
reach the GitHub API until you unlock.** git push and pull are unaffected —
those go over SSH.

- `mise run gw:unlock` **every time** the gateway is recreated or restarts. The
  key only ever lives in memory
- `whoami`, `check` and `logout` need the relay running now, since they go
  through its control socket
- An existing `/data/relay/upstream_token` is moved into the store the first
  time it is read, then deleted. **Nothing to do by hand**

If you skipped 0.2.15 you are stuck here: no `gw:unlock`, and adding one will
not work without `gw-tty`. Do that section first.

The same release refuses a push that moves a tag the upstream already
advertises. **Cutting a new tag is untouched**, so your release flow is
unchanged.

## 0.2.20 tasks come from the gateway now

**Optional, and worth doing once.** The image carries its own `gw:*` tasks, so a
project can stop keeping a copy:

The sample (`examples/sgw-sample/`) is already in this shape, so a new project
starts there. An existing one adds `gw:sync-tasks` and runs it once:

```toml
# mise.toml — the one task you keep. It cannot come from the image: it is what fetches from it
[tasks."gw:sync-tasks"]
description = "Pull the gw:* tasks out of the running gateway (after gw:recreate)"
run = "bash \"$SGW\" gw cat /usr/local/share/sekimore/gateway.mise.en.toml > \"$MISE_PROJECT_ROOT/.devcontainer/gateway.mise.toml\" && echo wrote"
```

```bash
mise run gw:sync-tasks      # or .ja.toml — it only changes what `mise tasks` prints
```

```toml
# mise.toml — delete the gw:* tasks, keep your own
[task_config]
includes = [".devcontainer/gateway.mise.toml"]

[env]
SGW = "{{config_root}}/.devcontainer/scripts/sgw.sh"
```

Re-extract after every `mise run gw:recreate`, and the tasks are always the ones
the running gateway has. This is what stops the drift that made 0.2.15 and
0.2.19 above into traps.

`sgw.sh` still has to be yours, and still has to have `gw-tty`. The shipped file
names the four primitives it uses in its header.

**Commit the extracted file.** `mise` **silently ignores an include that is
missing** — no error, no warning — so gitignoring it would leave every `gw:*`
task quietly not existing for whoever clones next. Committing it also means a
gateway upgrade shows up in `git diff`, which is the only place it is visible.

## 0.2.22 the proxy credential moved into the store

**Only for a gateway behind a corporate proxy that asks for a password.**
Everyone else: nothing to do.

`upstream_proxy_username` / `upstream_proxy_password` in `config.yml`, and the
`SEKIMORE_UPSTREAM_PROXY_*` variables, are readable from the dev container —
`config.yml` sits in the worktree and `.devcontainer/.env` is the agent's own
`env_file`. The credential belongs in the secret store:

```bash
mise run gw:proxy-credential -- set     # asks for the username and password on the terminal
```

Then remove the two keys from `config.yml` and the two variables from wherever
they were set, and `mise run gw:recreate`. Both are **still read** if left in
place, so this is not a breaking change; it is the removal that closes the hole.

Two things follow from the store being sealed at start-up:

- Squid runs **without** upstream authentication until `mise run gw:unlock`,
  and picks the credential up on its own once the store opens. Behind a proxy
  that rejects anonymous requests, the gateway still starts — nothing in it
  goes through the proxy before unlock
- `gw:proxy-credential` is a gateway task: it arrives through the include
  ([0.2.20](#0220-tasks-come-from-the-gateway-now)) after `mise run gw:sync-tasks`

0.2.21 and 0.2.23 – 0.2.26 ask nothing of you.

## 0.2.27 tags have to be signed

**Only for a project whose `tags:` globs let the agent push tags.** Everyone else:
nothing to do.

A pushed tag now has to be an annotated tag object carrying a signature —
`git tag -s`, in any format git knows (OpenPGP, SSH, X.509). A lightweight tag
(`git tag v1`) and an unsigned annotated one (`git tag -a`) are refused with
`[remote rejected]` and a message that says why. The relay checks that a
signature is *present*, not whose it is.

The dev container already signs: `agent-setup.sh` sets `tag.gpgsign true` with
the agent's SSH signing key, so `git tag -s` and plain `git tag -a` both come out
signed there. What this catches is a tag made *around* that — `-c
tag.gpgsign=false`, or from a shell without the setup — which is how the first
`v0.2.18` of the gateway itself went up.

If you would rather not have the check, it is one line, at whichever layer:

```yaml
# .devcontainer/config/config.yml
relay:
  project:
    signed_tags: false          # or under upstreams.<domain>, or on one entry of repos[]
```

Then `mise run gw:recreate`. `mise run gw:check` shows the effective value per
repository (`signed_tags=true|false`).

0.2.23 – 0.2.26 ask nothing of you.

## 0.2.28 Dependabot alerts are optional

**Nothing to do unless you want them.** Two new permission keys exist,
`security:read` (list and view the repository's Dependabot alerts) and
`security:dismiss` (set one aside with a reason, or reopen it). Neither is granted
by anything you have.

To turn them on:

```yaml
# .devcontainer/config/config.yml
relay:
  project:
    permissions:
      - security:read
      # - security:dismiss      # hiding a vulnerability is a separate authority; grant it deliberately
```

Then `mise run gw:recreate`, **and `mise run gw:login` once more**: the alerts API
needs the `security_events` OAuth scope, which logins before 0.2.28 did not ask
for. Without it `sekimore security alerts` gets GitHub's 403.

## 0.2.29 unattended unlock is available

**Nothing to do unless you want it.** `mise run gw:unlock` is unchanged, and a host
that stores nothing behaves exactly as before.

Run `mise run gw:sync-tasks` to pick up the two new tasks, then, once per host:

```bash
mise run gw:keychain-set     # asks for the passphrase and puts it in this host's keychain
```

From then on `mise run gw:recreate` unlocks the store by itself, and
`mise run gw:unlock-auto` does it on its own after a `docker restart`.

Where it looks, in this order, for `<project>` = the name of the directory
`MISE_PROJECT_ROOT` points at (so two projects on one host keep separate entries):

| | where | what binds it to this machine |
|---|---|---|
| macOS | Keychain, service `sekimore-gw`, account `<project>` | your login. Locked until you log in |
| Linux desktop | Secret Service (`secret-tool`), `service=sekimore-gw project=<project>` | your login session |
| a server | `/etc/sekimore/<project>.passphrase.cred`, read with `systemd-creds decrypt` | the TPM or the host key. A copied disk does not carry it |
| a server, last resort | `/etc/sekimore/<project>.passphrase`, root-owned 0600 | **nothing.** Whoever reads the file has the passphrase |

`gw:keychain-set` prints the exact commands for the two server forms on a host that
has neither keychain. Keep `/etc/sekimore` itself at 0755 — the task only reaches for
`sudo -n` after it has seen the file, and it never prompts for a sudo password,
because `gw:recreate` must not hang waiting for one.

This `/etc/sekimore` is the **host's**. The gateway has a directory of the same
name inside the container (its `config.yml` lives there); mounting the host's into
it would hand the gateway the passphrase this whole design keeps away from it.

Two things this does **not** change:

- The gateway learns nothing. The passphrase is read on the host and piped into
  `sekimore-relay unlock --stdin`; it still arrives over the control socket, which
  the dev container does not mount, and nothing inside the gateway can go looking
  for it. An export is still guarded by the passphrase alone.
- The first passphrase is still typed. `unlock --stdin` refuses a store that has
  never been initialised, because the first one is chosen rather than recalled and
  is asked for twice.

To keep the gateway locked after a recreate on one host, or on all of them:

```bash
SGW_NO_AUTO_UNLOCK=1 mise run gw:recreate
```

`SGW_PASSPHRASE_DIR` moves the file lookup off `/etc/sekimore`.

## 0.2.29 one signing key per person

**Optional, and nothing changes if you skip it.** Without `relay.signing_key` the
dev container generates its own signing key exactly as before.

The key it generates is disposable, and a signing key cannot be. It is registered
with GitHub by hand, and deleting it takes the Verified badge off every commit it
ever signed — so a wiped keys volume does not regenerate it, it loses it, and
every commit made after that is signed by a key GitHub does not know. Nothing
said so, because `commit.gpgsign` was set unconditionally and nothing checked
that the key was registered.

To adopt the replacement — one key per person, registered once:

1. Make the key on your machine, if you do not have one for this. **Not your own
   signing key**: a separate one is what keeps AI commits distinguishable in the
   history.

   ```bash
   ssh-keygen -t ed25519 -C "sekimore AI signing key" -f ~/.ssh/sekimore_signing
   ssh-add ~/.ssh/sekimore_signing          # --apple-use-keychain on a Mac
   ssh-keygen -lf ~/.ssh/sekimore_signing.pub   # the SHA256:… fingerprint
   ```

2. Register the **public** half with GitHub once: Settings → SSH and GPG keys →
   New SSH key → Key type: **Signing Key**.

3. Put the fingerprint in `.devcontainer/config/config.yml`:

   ```yaml
   relay:
     signing_key:
       fingerprint: "SHA256:…"     # from step 1
   ```

   Your own keys may stay in the same agent. The relay hands the dev container a
   *filtered* socket that answers for this one fingerprint and signs nothing that
   is not a git signature, so the rest stay invisible and the socket cannot
   authenticate anywhere.

4. Add the socket's volume to **both** services in
   `.devcontainer/docker-compose.relay.yml` (the sample already has it):

   ```yaml
   services:
     sekimore-gw:
       volumes:
         - sekimore-signing:/run/sekimore
     dev:
       volumes:
         - sekimore-signing:/run/sekimore

   volumes:
     sekimore-signing:
       name: sekimore-signing-${DEVCONTAINER_ID}
   ```

5. `mise run gw:recreate`, then Rebuild Container. Check it took:

   ```bash
   mise run gw:check     # "signing key: … in the host agent"
   ```

   Inside dev, `ssh-add -l` now lists **exactly one** key — the signing key, through
   the filtered socket. If your `mise.toml` has the 0.1.x `relay:verify` that fails
   when `ssh-add -l` succeeds, replace that block:

   ```bash
   echo "== dev: only the gateway's filtered signing key may be reachable"
   n=$(bash "$SGW" dev ssh-add -l 2>/dev/null | grep -c . || true)
   if [ "$n" = 1 ]; then
     echo "OK: exactly one key (the signing key, via the gateway's filtered agent)"
   elif [ "$n" = 0 ]; then
     echo "OK: no ssh-agent in dev"
   else
     echo "❌ FAIL: ssh-add -l lists $n keys inside dev — the operator's keys are exposed to the AI. Reopen with: mise run vscode"
     fail=1
   fi
   ```

The old `~/.ssh/sekimore/signing_ed25519` is left alone rather than deleted: it
signed commits that are in the history, and its public half has to stay
registered with GitHub for those to keep their badge.

**`signing: required`** is separate and also optional. It makes the relay refuse a
push to a branch when any commit it brings has no signature — the check that
would have caught this twenty commits earlier. `optional` is the default, so no
existing project changes behaviour.

```yaml
relay:
  project:
    signing: required     # or per upstream, or per repos[]
```

Turn it on only after step 5 works: with it on and no key, every push is refused.

`required` also **needs the upstream API**. Where a push's history leaves the pack, the
relay asks the upstream whether it already holds that commit — a commit hidden behind a
delta looks the same from inside the pack otherwise. So the gateway has to be unlocked
(`mise run gw:unlock`) and logged in, or pushes fail closed with a message saying which.

## base 0.2.19 `mise run web` finds the port itself

**Optional.** Nothing breaks if you skip it — until you move the Web UI's
published port, which is when the old `web` task goes to the wrong place.

The task had the port written into it as a literal while the compose file is
what actually decides it. A project that already has 8090 taken moves the
published port, the task keeps opening the old number, and `mise run web` lands
on nothing — or on another project's gateway, which is worse.

This one is not keyed to a gateway version: it is the sample's own files, and
the gateway is unchanged.

Take both from the sample — `sgw.sh` gains a `port` branch and `mise.toml`'s
`web` task calls it:

```bash
diff -u <base>/examples/sgw-sample/.devcontainer/scripts/sgw.sh .devcontainer/scripts/sgw.sh
diff -u <base>/examples/sgw-sample/mise.toml mise.toml
```

Then `mise run web` prints the URL it opens, so a wrong port is visible rather
than silent.
