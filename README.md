# sgw-devcontainer-base

*[日本語版](README.ja.md)*

The **base image** for a DevContainer. It assumes a network that goes through
sekimore-gw (the security gateway), and bakes in only the project-independent part,
so that every build after it is fast.

Published at: `ghcr.io/amakata/sgw-devcontainer-base`
Platforms: `linux/amd64`, `linux/arm64`

## What's inside

- Base: `mcr.microsoft.com/devcontainers/base:bookworm` (`vscode` user, uid=1000)
- Shell tooling: `fzf`, `iptables`, `iproute2`, `iputils-ping`, `dnsutils`, `jq`, `nano`, `vim`, `pv`, `wget`, `curl`, `unzip`, `sudo`, `rsync`, `gnupg`
- DB client dev headers: `libpq-dev`, `default-libmysqlclient-dev`
- `git-delta`
- **GitHub CLI (`gh`)**
- zsh + oh-my-zsh + plugins
  (`zsh-completions`, `zsh-autosuggestions`, `zsh-syntax-highlighting`,
   `fast-syntax-highlighting`, `zsh-autocomplete`)
- **`mise` (jdx/mise) pre-installed**
  One binary that manages python / node / ruby / php / rust / go and the rest.
  No language version is included — `mise use -g python@3.13.0` and the like belong
  to the project. The shims directory (`~/.local/share/mise/shims`) is first on
  `ENV PATH` in the Dockerfile, so a language command resolves **from a
  non-interactive process** too: a tool call from Claude Code, `docker exec cmd`,
  a postCreateCommand. To pre-install a language in the project's own image, stage
  `~/.local/share/mise/installs` into `~/.local/share/mise/installs-default`; a volume
  mount then leaves it empty, and post-create restores it with
  `rsync -a --ignore-existing ~/.local/share/mise/installs-default/ \
    ~/.local/share/mise/installs/ && mise reshim`
  (see the sample, `examples/sgw-sample/`)
- Claude Code CLI
- AWS CLI v2
- Docker CE + buildx + compose plugin
- The `sekimore-gw` agent-setup script (`/usr/local/bin/sekimore-agent-setup.sh`),
  the `sekimore-relay` CLI (`/usr/local/bin/sekimore-relay`) and the `sekimore` wrapper.
  All of them are taken with `COPY --from` out of the **same `sekimore-gw` image**, so
  they cannot drift apart. Which gateway that is, is decided by `ARG SEKIMORE_GW_IMAGE`
  in the Dockerfile — currently `ghcr.io/amakata/sekimore-gw:0.2.31` — and by nothing
  else; a local build overrides it with `--build-arg SEKIMORE_GW_IMAGE=...`.
  When the gateway runs the relay (the git / GitHub API relay), agent-setup arranges the
  disposable key, the project token, `known_hosts` and the signing key on its own (see
  `examples/sgw-sample/.devcontainer/docker-compose.relay.yml`).
  A token lasts `relay.token_ttl` (12 hours by default) and, when it expires, the
  `sekimore` wrapper re-runs the bootstrap and gets another — the container does not
  have to be restarted
- Default zsh rc.d snippets (`/etc/skel/zsh-rc.d/`)
  XDG settings, mise activate, aliases, plugin configuration. Post-create copies them
  into `~/.config/zsh/rc.d/`

## What's NOT inside

Nothing project-specific. The project's own devcontainer provides:

- Build dependencies for a language (`build-essential`, `autoconf`, `libssl-dev`,
  `libyaml-dev`, `libxml2-dev` and so on) — needed where `mise` builds a language from
  source (Ruby, PHP). The sample `examples/sgw-sample/Dockerfile` shows Ruby and Rust
  enabled and PHP commented out
- The `sekimore-gw` service itself (a separate service in docker-compose)
- Per-project configuration: `.env`, `config.yml`, the squid settings
- A project's own zsh rc.d overlay, where it overrides or adds to the defaults
- The workspace mount
- The runtime privileges the Docker daemon needs (`NET_ADMIN`, `privileged`, cgroup,
  the `/var/lib/docker` volume)

## Usage

The complete sample is [`examples/sgw-sample/`](examples/sgw-sample/). Its `mise.toml`
collects the host-side operations (`mise run vscode` / `gw:login` / `relay:verify` …).
The smallest possible use is:

```dockerfile
# a version, not latest: `mise run upgrade` reads it and moves it
FROM ghcr.io/amakata/sgw-devcontainer-base:0.2.26

# only what this project adds
# e.g. mise use -g python@3.13.0 && mise reshim
```

> After introducing a new language version with `mise use -g`, run `mise reshim` to
> regenerate the shims directory.

## Getting started (a new project)

This image is not usable on its own. It needs two containers in one compose stack —
the gateway (sekimore-gw) and dev — and the host-side operations collected as mise
tasks. That is [`examples/sgw-sample/`](examples/sgw-sample/), and **a new project
starts by copying it.**

```bash
# 1. copy the template into your project
cp -r examples/sgw-sample/.devcontainer  /path/to/your-project/
cp    examples/sgw-sample/mise.toml      /path/to/your-project/

# 2. fill in the values
cd /path/to/your-project
cp .devcontainer/.env.sample .devcontainer/.env     # project name, user name, email
$EDITOR .devcontainer/config/config.yml             # relay.project.repos and permissions
```

[`config.yml`](examples/sgw-sample/.devcontainer/config/config.yml) is the **whole menu**:
every key the gateway reads is in it, the ones the sample sets and the rest commented out
with their default and a line on why you would change one. All 28 permission keys are
listed, one per line; the consequential ones (`pr:merge`, `ci:rerun`, `security:dismiss`
and the like) are left commented, so a project turns one on by uncommenting it.

Then follow [`examples/sgw-sample/README.md`](examples/sgw-sample/README.md). The points
that matter:

| | |
| --- | --- |
| `mise run vscode` | **Open with this, not with `code`.** It is what keeps the operator's ssh-agent out of dev |
| `mise run gw:unlock` | Unlock the secret store. **Every time the gateway is recreated** |
| `mise run gw:login` | Once, at the start. It cannot run before the unlock — the store it writes to is not open yet |
| `mise run dev:signing-key` | Register the public key it prints with GitHub, as a Signing Key |
| `mise run relay:verify` | Checks the whole set-up. Green here means done |

Everything you copy **is yours from that moment, except `.devcontainer/sgw/`** — the host
scripts and tasks, which `mise run upgrade:apply` replaces. Put your own tasks in
`mise.toml`; a task there with the same name as a distributed one wins.

## Keeping up to date

```bash
mise run upgrade          # what is newer, which files it would change, what UPGRADING asks. Changes nothing
mise run upgrade:apply    # move to it
```

`upgrade:apply` raises the gateway's `image:` tag in `.devcontainer/docker-compose.yml` and
the base's `FROM` tag in `.devcontainer/Dockerfile` to the newest on GHCR, replaces
`.devcontainer/sgw/` with the files of those versions, recreates the gateway after asking,
and unlocks it (`gw:unlock-auto`, when the passphrase is kept on the host). It ends with
what only you can do:

- **Rebuild Container** in VS Code, when the base moved
- the sections of [UPGRADING.md](UPGRADING.md) in between — only releases that ask you to
  edit a file you own (`config.yml`, say) are there, and `mise run upgrade:notes` prints them
- `git diff`, and commit

A file in `.devcontainer/sgw/` that was edited by hand stops it, with the diff, before
anything is written. Move the change into `mise.toml`, restore the file, and run it again.

The language of what it prints, and of the task descriptions, is the first of `LC_ALL`,
`LC_MESSAGES` and `LANG` that says `ja` or `en` (`SEKIMORE_LANG` before all of them). After
changing it, `mise run upgrade:sync` takes the task files again.

The three versions are not independent, which is why one command moves them:

```
sekimore-gw (the gateway)  ── this image copies the relay binaries out of it
        ↓
sgw-devcontainer-base      ── your .devcontainer/Dockerfile FROMs it
        ↓
.devcontainer/sgw/         ── the host scripts and tasks for both
```

What changed is in the
[gateway's CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.md), the
[relay's CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.md) and
[this one](CHANGELOG.md).

A project from before `.devcontainer/sgw/` moves to it once, by hand:
[UPGRADING.md](UPGRADING.md#base-0220-devcontainersgw-and-mise-run-upgrade).

<!-- UPGRADING.md and UPGRADING.ja.md link here by the heading this section used to have -->
<a name="008-以前の-gateway-から上げる場合" id="008-以前の-gateway-から上げる場合"></a>

### Upgrading from a gateway older than 0.0.8

**No configuration has to be rewritten.** From v0.0.8 to today, `config.yml` has only
**gained** keys — none was removed or renamed (`allow_domains` / `block_domains` /
`allow_ips` / `block_ips` / `proxy` / `network` / `database_path` all still parse).
Raise the image tag, run `mise run gw:recreate`, and the DNS filter, the firewall and
Squid work as they did.

The relay **does not exist in v0.0.8**. It arrived in 0.1.0 as an addition, and it is
**opt-in**. Without `domain_handlers` and `relay` in `config.yml` it does not start and
nothing else changes. So:

| what you want | what it takes |
| --- | --- |
| Just to be on a newer version | Raise the image tag and `gw:recreate`. The configuration stays as it is |
| To let an AI use GitHub (to use the relay) | Add `domain_handlers` + `relay` to `config.yml`. See below |

Using the relay needs things a 0.0.8 set-up does not have. **The relay's side is collected
in its own overlay compose file**, so there are three additions:

1. `domain_handlers` and `relay` in `config.yml`
   (the end of [`config/config.sample.yml`](https://github.com/Amakata/sekimore-gw/blob/main/config/config.sample.yml)
   is the template as it stands)
2. A copy of [`docker-compose.relay.yml`](examples/sgw-sample/.devcontainer/docker-compose.relay.yml),
   listed in `devcontainer.json`'s `dockerComposeFile` **after** `docker-compose.yml`.
   The ssh-agent mount and the disposable-key volume are in it
3. `.env.sample` copied to `.env` with the project name and the rest filled in (the
   overlay above reads it)

Then `mise run gw:unlock` → `gw:login` → `dev:signing-key` → `relay:verify`.

To stop using it, drop the overlay from `dockerComposeFile` and delete `domain_handlers`
and `relay` from `config.yml`; the behaviour is 0.0.8's again.

With all of that added, the `.devcontainer/` is a different thing from 0.0.8's, so
**copying the template afresh and carrying over `allow_domains` and the rest is quicker.**

Only a set-up that has been using the relay since 0.1.x meets the breaking changes along
the way (permissions consolidated in 0.1.9, `handler: git-relay` → `github` in 0.2.6,
`relay.project.boards` made mandatory in 0.2.7). Coming from 0.0.8 the relay is written
from scratch, so none of them applies.

## Tags

GitHub Actions (`.github/workflows/build-and-push.yml`) pushes these tags to GHCR:

| trigger | tags |
| --- | --- |
| push to `main` | `main`, `latest`, `sha-<short>` |
| push of a `v1.2.3` tag | `1.2.3`, `1.2`, `1`, `sha-<short>` |
| pull request | (build only, nothing pushed) |

## Which sekimore-gw this image takes

The gateway this image ships **for the dev container** — the `sekimore` CLI and
`agent-setup.sh` — is whatever `ARG SEKIMORE_GW_IMAGE` in the Dockerfile names, currently
`ghcr.io/amakata/sekimore-gw:0.2.31`. That ARG is the only thing that decides it, and a
local build overrides it with `--build-arg SEKIMORE_GW_IMAGE=...`. Which version each
release took is recorded release by release in [CHANGELOG.md](CHANGELOG.md).

The gateway a project **runs** is a different thing: it is the `image:` tag in your
`.devcontainer/docker-compose.yml`, and it moves on its own. Raise it and run
`mise run gw:recreate`; there is no need to wait for this image. The two are in step at the
moment: this image takes 0.2.31 and the gateway is at 0.2.31. What each gateway version
asks of you is in [UPGRADING.md](UPGRADING.md); most ask nothing.

The order of a release: tag sekimore-gw → publish to GHCR → raise the `SEKIMORE_GW_IMAGE`
default in this repository and push → publish to GHCR → follow with the image tag in
`examples/sgw-sample`'s compose. When the base is released, the sample's `.devcontainer/Dockerfile`
moves to the new `FROM` tag, and `scripts/sync-sample-sgw.sh` rewrites its `.devcontainer/sgw/`
to match (`tests/test_sample_sgw.sh` fails until they agree). The base takes its binaries out of the gateway image, so
no step can be skipped. The build needs to reach `ghcr.io` and
`pkg-containers.githubusercontent.com`.

## Local build

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t sgw-devcontainer-base:dev \
  .
```

A single-platform build, for testing locally:

```sh
docker build -t sgw-devcontainer-base:dev .
docker run --rm -it sgw-devcontainer-base:dev zsh
# to take the relay out of a locally built sekimore-gw image
docker build -t sgw-devcontainer-base:dev --build-arg SEKIMORE_GW_IMAGE=sekimore-gw:relay-dev .
```

## License

MIT
