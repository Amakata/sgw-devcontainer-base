# sgw-devcontainer-base

*[日本語版](README.ja.md)*

The dev-container side of [sekimore-gw](https://github.com/Amakata/sekimore-gw) (sgw for short). It is
not used on its own; the sekimore-gw README explains why the setup exists.

Published at: `ghcr.io/amakata/sgw-devcontainer-base`
Platforms: `linux/amd64`, `linux/arm64`

## Start a project

A project starts as a copy of [`examples/sgw-sample/`](examples/sgw-sample/): the gateway and dev
containers and the host-side mise tasks. Run the steps on the host, in order;
[`examples/sgw-sample/README.md`](examples/sgw-sample/README.md) describes each one in detail.

1. Clone this repository: `git clone https://github.com/Amakata/sgw-devcontainer-base.git`.
2. Copy `examples/sgw-sample/.devcontainer/` and `examples/sgw-sample/mise.toml` into the project.
3. Copy `.devcontainer/.env.sample` to `.devcontainer/.env` and fill in the project name, the user name and the email address.
4. In `.devcontainer/config/config.yml`, set `relay.project.repos` and `permissions`. The file lists every key the gateway reads; the consequential permissions are commented out.
5. Quit VS Code completely, run `mise run vscode`, and select "Reopen in Container". The task opens VS Code without `SSH_AUTH_SOCK`, so the operator's ssh-agent does not reach the dev container.
6. Run `mise run gw:unlock` to unlock the secret store. The first run sets the passphrase, and the store must be unlocked again every time the gateway is recreated. To avoid that, run `mise run gw:keychain-set` once: it stores the passphrase on the host (in the macOS Keychain, the Secret Service or a root-owned file), and `gw:recreate` then unlocks the store automatically.
7. Run `mise run gw:login` (first time only). It logs in to GitHub with the device flow and stores the upstream token and `known_hosts`. It requires an unlocked store.
8. Run `mise run dev:signing-key` and register the public key it prints on GitHub as a Signing Key. The agent's commits are signed with this key.
9. Run `mise run relay:verify`. It checks the whole setup, and the setup is complete when it passes.

## Project Dockerfile

The project's `.devcontainer/Dockerfile` needs only the following:

```dockerfile
# a version, not latest: `mise run upgrade` reads it and raises it
FROM ghcr.io/amakata/sgw-devcontainer-base:0.2.34

# only what this project adds
# e.g. mise use -g python@3.13.0 && mise reshim
```

The sample's [Dockerfile](examples/sgw-sample/.devcontainer/Dockerfile) shows how to pre-install
language versions and keep them when a volume is mounted over the mise data directory.

## Image contents

| | |
|---|---|
| Base | `mcr.microsoft.com/devcontainers/base:bookworm` (`vscode` user, uid=1000) |
| Shell | zsh, oh-my-zsh and plugins, `fzf`, `jq`, `vim`, `nano`, `curl`, `wget`, `unzip`, `rsync`, `pv`, `gnupg`, `sudo` |
| Network | `iptables`, `iproute2`, `iputils-ping`, `dnsutils` |
| Git | `git-delta` |
| DB headers | `libpq-dev`, `default-libmysqlclient-dev` |
| Languages | `mise`, which manages Python, Node.js, Ruby, PHP, Rust and Go. No language version is included |
| AI | Claude Code CLI, OpenAI Codex CLI |
| Cloud | AWS CLI v2, Docker CE with buildx and compose |
| Gateway | `sekimore-agent-setup.sh`, the `sekimore-relay` CLI and the `sekimore` wrapper |
| zsh defaults | `/etc/skel/zsh-rc.d/`: XDG settings, mise activation, aliases and plugins. Post-create copies them into `~/.config/zsh/rc.d/` |

`sekimore-agent-setup.sh` and `sekimore-relay` come from the same sekimore-gw image, so their
versions cannot diverge. The image contains nothing project-specific: language build dependencies,
the configuration and the Docker daemon's privileges come from the project, as in the sample.

## Ownership and keeping up to date

Everything copied from the sample belongs to the project, except `.devcontainer/sgw/`, which
contains the host scripts and tasks and is replaced by `mise run upgrade:apply`. Do not edit it
by hand. To change a distributed task, define a task with the same name in the project's
`mise.toml`; that definition takes precedence. `.devcontainer/sgw/gateway.mise.toml` holds the
`gw:*` tasks. The gateway image ships it in English and Japanese, and `mise run upgrade:sync`
fetches the one for the current language (`SEKIMORE_LANG`, then `LC_ALL`, `LC_MESSAGES`, `LANG`).
Set `SGW_NO_AUTO_UNLOCK=1` to keep `gw:recreate` from unlocking the store with the stored passphrase.

```bash
mise run upgrade          # what is newer, which files it would change, what UPGRADING asks. Changes nothing
mise run upgrade:apply    # move to it
```

`upgrade:apply` raises the gateway's `image:` tag and the `FROM` tag to the newest versions on GHCR,
replaces `.devcontainer/sgw/`, recreates the gateway after asking, and unlocks it when the
passphrase is stored. It then lists what only the operator can do: Rebuild Container when the base
changed, the [UPGRADING.md](UPGRADING.md) sections the upgrade crosses, and a commit. It stops without writing
if a file in `.devcontainer/sgw/` was edited by hand.

The three parts depend on one another, which is why a single command updates all of them:

```
sekimore-gw (the gateway)  ── this image copies the relay binaries out of it
        ↓
sgw-devcontainer-base      ── your .devcontainer/Dockerfile FROMs it
        ↓
.devcontainer/sgw/         ── the host scripts and tasks for both
```

sgw-devcontainer-base and sekimore-gw are separate 0.2.x series that move independently. The relay
CLI and agent-setup in this image come from the gateway image that `ARG SEKIMORE_GW_IMAGE` in the
Dockerfile names, currently `ghcr.io/amakata/sekimore-gw:0.2.36`. The gateway that a project runs is
set by the `image:` tag in its compose file, and `mise run gw:recreate` applies a raised tag without
a new release of this image. The two currently match: this image takes 0.2.36 and the gateway is at 0.2.36.

## Tags

GitHub Actions (`.github/workflows/build-and-push.yml`) pushes the following tags to GHCR:

| Trigger | Tags |
| --- | --- |
| Push to `main` | `main`, `latest`, `sha-<short>` |
| Push of a `v1.2.3` tag | `1.2.3`, `1.2`, `1`, `sha-<short>` |
| Pull request | (build only, nothing pushed) |

## Links

- [UPGRADING.md](UPGRADING.md) — what each release requires of a project, including the move from
  gateway 0.0.x and the one-time move to `.devcontainer/sgw/` for projects created before base 0.2.20
- [CHANGELOG.md](CHANGELOG.md) — this image, with the gateway version each release used. The
  gateway's [CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.md) and the
  relay's [CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.md)
- [RELEASING.md](RELEASING.md) — the release order and local builds, for maintainers
- License: MIT ([LICENSE](LICENSE))
