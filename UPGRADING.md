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
