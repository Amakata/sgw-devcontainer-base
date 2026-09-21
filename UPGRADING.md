<!-- reviewed-up-to: 0.2.26 -->
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
