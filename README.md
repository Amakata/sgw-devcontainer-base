# sgw-devcontainer-base

*[日本語版](README.ja.md)*

**Give an AI agent your development environment without handing over your GitHub account or your keys.**

An agent is useful only when it can do the work. However, a token grants it the `repo` scope,
which is **read and write access to every repository your account can access**, and an agent with a terminal
can read `~/.ssh` and `.env`.

VS Code Dev Containers confines the environment to a container, and this setup **routes all
traffic that leaves the container through the gateway (sekimore-gw)**. The credentials therefore
stay outside the agent. The agent holds only a disposable key, which is valid nowhere except at
the gateway.

GitHub operations go through the `sekimore` command, and **you choose which operations to allow**
from 33 permissions: for example, `pr:create` allowed and `pr:merge` denied. The image
deliberately does not include `gh`: given a token, `gh` would connect to GitHub directly past the
gateway, and none of those permissions would apply.

This image is the dev side of that setup.

## Features

| | |
|---|---|
| **git without handing over a key** | The agent holds a disposable key that only the gateway accepts. GitHub receives only what the gateway forwards with your key |
| **GitHub operations allowed one at a time** | For example, `pr:merge` denied and `issue:create` allowed. No operation reaches a repository outside the project |
| **Access only to allowed destinations** | An unlisted domain does not resolve, and the firewall drops a connection to its IP address |
| **A limit on outbound data** | The gateway counts the bytes sent to the destinations it handles, and closes and records the connection when the count exceeds the limit |
| **Commits that show as Verified** | The signing key is on the gateway side. The dev container can request a signature and nothing else; it cannot read the key itself |
| **Fast builds** | Everything except the language runtimes is already in the image |

The gateway itself is documented in [sekimore-gw](https://github.com/Amakata/sekimore-gw).

Published at: `ghcr.io/amakata/sgw-devcontainer-base`
Platforms: `linux/amd64`, `linux/arm64`

## Getting started with a new project

This image cannot be used on its own. It requires a compose stack with two containers, the
gateway (sekimore-gw) and dev, and the host-side operations packaged as mise tasks.
[`examples/sgw-sample/`](examples/sgw-sample/) provides all of this, and **a new project starts
as a copy of it.**

```bash
# 1. copy the template into your project
cp -r examples/sgw-sample/.devcontainer  /path/to/your-project/
cp    examples/sgw-sample/mise.toml      /path/to/your-project/

# 2. fill in the values
cd /path/to/your-project
cp .devcontainer/.env.sample .devcontainer/.env     # project name, user name, email
$EDITOR .devcontainer/config/config.yml             # relay.project.repos and permissions
```

[`config.yml`](examples/sgw-sample/.devcontainer/config/config.yml) lists **every key the
gateway reads**. The keys that the sample sets are active. The others are commented out, each
with its default value and a note on when to change it. All 33 permission keys are listed, one
per line. The consequential ones (`pr:merge`, `ci:rerun`, `security:dismiss` and others) are
commented out, so a project enables one by uncommenting it. The comments are written in English.

Then follow [`examples/sgw-sample/README.md`](examples/sgw-sample/README.md). The key steps are:

| | |
| --- | --- |
| `mise run vscode` | **Open VS Code with this task, not with `code`.** The task keeps the operator's ssh-agent out of the dev container |
| `mise run gw:unlock` | Unlocks the secret store. **Required every time the gateway is recreated** |
| `mise run gw:login` | Run once, at the start. It cannot run before the unlock, because the store it writes to is not yet open |
| `mise run dev:signing-key` | Prints a public key. Register it with GitHub as a Signing Key |
| `mise run relay:verify` | Checks the whole setup. When this check passes, the setup is complete |

**Everything you copy belongs to your project from then on, except `.devcontainer/sgw/`**, which
contains the host scripts and tasks and is replaced by `mise run upgrade:apply`. Put your own
tasks in `mise.toml`. A task there with the same name as a distributed task takes precedence.

### Minimal project Dockerfile

Once the stack is in place, a project's own Dockerfile needs only the following:

```dockerfile
# a version, not latest: `mise run upgrade` reads it and raises it
FROM ghcr.io/amakata/sgw-devcontainer-base:0.2.34

# only what this project adds
# e.g. mise use -g python@3.13.0 && mise reshim
```

> After you install a new language version with `mise use -g`, run `mise reshim` to regenerate
> the shims directory.

## Image contents

| | |
|---|---|
| Base | `mcr.microsoft.com/devcontainers/base:bookworm` (`vscode` user, uid=1000) |
| Shell | zsh, oh-my-zsh and plugins, `fzf`, `jq`, `vim`, `nano`, `curl`, `wget`, `unzip`, `rsync`, `pv`, `gnupg`, `sudo` |
| Network | `iptables`, `iproute2`, `iputils-ping`, `dnsutils` |
| Git | `git-delta` |
| DB headers | `libpq-dev`, `default-libmysqlclient-dev` |
| Languages | `mise`, a single binary that manages Python, Node.js, Ruby, PHP, Rust and Go. No language version is included ([below](#mise-and-the-shims)) |
| AI | Claude Code CLI, OpenAI Codex CLI |
| Cloud | AWS CLI v2, Docker CE with buildx and compose |
| Gateway | `sekimore-agent-setup.sh`, the `sekimore-relay` CLI and the `sekimore` wrapper ([below](#gateway-tools)) |
| zsh defaults | `/etc/skel/zsh-rc.d/`: XDG settings, mise activation, aliases and plugins. Post-create copies them into `~/.config/zsh/rc.d/` |

### mise and the shims

The image includes no language version. The project adds its own, for example with
`mise use -g python@3.13.0`. The shims directory (`~/.local/share/mise/shims`) is first in
`ENV PATH`, so language commands resolve **from non-interactive processes** as well: a tool call
from Claude Code, `docker exec cmd` or a postCreateCommand. Debian's `/etc/profile` resets `PATH`
for login shells and drops the shims directory, so a script in `/etc/profile.d` adds it back.

To pre-install a language in the project's own image, copy `~/.local/share/mise/installs` to
`~/.local/share/mise/installs-default` at build time. A volume mounted over the first directory
leaves it empty, and post-create restores it with the following command:

```bash
rsync -a --ignore-existing ~/.local/share/mise/installs-default/ \
  ~/.local/share/mise/installs/ && mise reshim
```

### Gateway tools

`sekimore-agent-setup.sh` and the `sekimore-relay` CLI are copied with `COPY --from` from the
**same `sekimore-gw` image**, so their versions cannot diverge. The `sekimore` wrapper is part of
this repository (`scripts/sekimore`) and runs `sekimore-relay agent`. The gateway image is
determined only by `ARG SEKIMORE_GW_IMAGE` in the Dockerfile, currently
`ghcr.io/amakata/sekimore-gw:0.2.36`. A local build can override it with
`--build-arg SEKIMORE_GW_IMAGE=...`.

When the gateway runs the relay, agent-setup provisions the disposable key, the project token,
`known_hosts` and the signing key automatically (see
`examples/sgw-sample/.devcontainer/docker-compose.relay.yml`). A project token is valid for
`relay.token_ttl` (12 hours by default). When the token expires, the `sekimore` wrapper runs the
bootstrap again and obtains a new token, so the container does not need to be restarted.

## Not included

The image contains nothing project-specific. The project's own dev container provides the
following:

- Build dependencies for languages (`build-essential`, `autoconf`, `libssl-dev`, `libyaml-dev`,
  `libxml2-dev` and others), which are required where `mise` builds a language from source (Ruby,
  PHP). The sample `examples/sgw-sample/.devcontainer/Dockerfile` enables Ruby and Rust and has
  PHP commented out
- The `sekimore-gw` service itself (a separate service in docker-compose.yml)
- Per-project configuration: `.env`, `config.yml` and the Squid settings
- The project's own zsh rc.d overlay, which overrides or extends the defaults
- The workspace mount
- The runtime privileges that the Docker daemon requires (`NET_ADMIN`, `privileged`, cgroup, the
  `/var/lib/docker` volume)

## Keeping up to date

```bash
mise run upgrade          # what is newer, which files it would change, what UPGRADING asks. Changes nothing
mise run upgrade:apply    # move to it
```

`upgrade:apply` raises the gateway's `image:` tag in `.devcontainer/docker-compose.yml` and the
base's `FROM` tag in `.devcontainer/Dockerfile` to the newest versions on GHCR, and replaces
`.devcontainer/sgw/` with the files of those versions. After asking for confirmation, it
recreates the gateway and unlocks it (with `gw:unlock-auto`, when the passphrase is stored on the
host). Finally, it lists the steps that only you can perform:

- **Rebuild Container** in VS Code, when the base version changed
- The sections of [UPGRADING.md](UPGRADING.md) between the old and new versions. Only releases
  that require you to edit a file you own (for example, `config.yml`) have a section, and
  `mise run upgrade:notes` prints them
- `git diff`, and a commit

If a file in `.devcontainer/sgw/` was edited by hand, `upgrade:apply` stops before writing
anything and shows the diff. Move the change into `mise.toml`, restore the file, and run the
command again.

The language of the output and of the task descriptions is determined by the first of `LC_ALL`,
`LC_MESSAGES` and `LANG` that specifies `ja` or `en`. `SEKIMORE_LANG` takes precedence over all of
them. After you change the language, run `mise run upgrade:sync` to fetch the task files again.

The three versions depend on one another, which is why a single command updates all of them:

```
sekimore-gw (the gateway)  ── this image copies the relay binaries out of it
        ↓
sgw-devcontainer-base      ── your .devcontainer/Dockerfile FROMs it
        ↓
.devcontainer/sgw/         ── the host scripts and tasks for both
```

The changes are described in the
[gateway's CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.md), the
[relay's CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.md) and
[this repository's CHANGELOG](CHANGELOG.md).

A project created before `.devcontainer/sgw/` was introduced must migrate to it once, by hand:
[UPGRADING.md](UPGRADING.md#base-0220-devcontainersgw-and-mise-run-upgrade).

<!-- UPGRADING.md and UPGRADING.ja.md link here by the heading this section used to have -->
<a name="008-以前の-gateway-から上げる場合" id="008-以前の-gateway-から上げる場合"></a>

### Upgrading from gateway 0.0.8 or earlier

**No configuration needs to be rewritten.** Since v0.0.8, keys have only been **added** to
`config.yml`; none has been removed or renamed (`allow_domains`, `block_domains`, `allow_ips`,
`block_ips`, `proxy`, `network` and `database_path` are all still accepted). Raise the image tag
and run `mise run gw:recreate`, and the DNS filter, the firewall and Squid work as before.

The relay **does not exist in v0.0.8**. It was added in 0.1.0 and is **opt-in**. If `config.yml`
has no `domain_handlers` and `relay`, the relay does not start and nothing else changes:

| Goal | Required steps |
| --- | --- |
| Only move to a newer version | Raise the image tag and run `gw:recreate`. The configuration stays as it is |
| Let an AI agent use GitHub (use the relay) | Add `domain_handlers` and `relay` to `config.yml`, as described below |

The relay requires components that a 0.0.8 setup does not have. **The relay's part of the setup is
in a separate overlay compose file**, so three additions are needed:

1. `domain_handlers` and `relay` in `config.yml`
   (the end of [`config/config.sample.yml`](https://github.com/Amakata/sekimore-gw/blob/main/config/config.sample.yml)
   is the current template)
2. A copy of [`docker-compose.relay.yml`](examples/sgw-sample/.devcontainer/docker-compose.relay.yml),
   listed in `dockerComposeFile` in `devcontainer.json` **after** `docker-compose.yml`.
   This file contains the ssh-agent mount and the disposable-key volume
3. `.env.sample` copied to `.env`, with the project name and the other values filled in (the
   overlay reads it)

Then run `mise run gw:unlock`, `gw:login`, `dev:signing-key` and `relay:verify`, in that order.

To stop using the relay, remove the overlay from `dockerComposeFile` and delete `domain_handlers`
and `relay` from `config.yml`. The gateway then behaves as 0.0.8 did.

With all of these additions, the `.devcontainer/` differs substantially from a 0.0.8 setup, so
**it is faster to copy the template again and carry over `allow_domains` and the other
settings.**

The breaking changes between versions affect only setups that have used the relay since 0.1.x
(permissions consolidated in 0.1.9, `handler: git-relay` renamed to `github` in 0.2.6,
`relay.project.boards` made mandatory in 0.2.7). An upgrade from 0.0.8 configures the relay from
scratch, so none of them applies.

## Tags

GitHub Actions (`.github/workflows/build-and-push.yml`) pushes the following tags to GHCR:

| Trigger | Tags |
| --- | --- |
| Push to `main` | `main`, `latest`, `sha-<short>` |
| Push of a `v1.2.3` tag | `1.2.3`, `1.2`, `1`, `sha-<short>` |
| Pull request | (build only, nothing pushed) |

## Gateway version used by this image

The gateway components that this image installs **in the dev container**, the `sekimore-relay`
CLI and `agent-setup.sh`, come from the image that `ARG SEKIMORE_GW_IMAGE` in the Dockerfile
names, currently `ghcr.io/amakata/sekimore-gw:0.2.36`. Only that ARG determines it, and a local
build can override it with `--build-arg SEKIMORE_GW_IMAGE=...`. [CHANGELOG.md](CHANGELOG.md)
records the gateway version that each release used.

The gateway that a project **runs** is set separately, by the `image:` tag in your
`.devcontainer/docker-compose.yml`, and can be updated independently. Raise the tag and run
`mise run gw:recreate`; you do not need to wait for a new release of this image. The two versions
currently match: this image takes 0.2.36 and the gateway is at 0.2.36. [UPGRADING.md](UPGRADING.md)
lists what each gateway version requires of you; most versions require nothing.

The release order is as follows:

1. Tag sekimore-gw.
2. Publish it to GHCR.
3. Raise the `SEKIMORE_GW_IMAGE` default in this repository and push.
4. Publish this image to GHCR.
5. Update the image tag in the compose file of `examples/sgw-sample`.

When the base is released, the sample's `.devcontainer/Dockerfile` moves to the new `FROM` tag,
and `scripts/sync-sample-sgw.sh` updates its `.devcontainer/sgw/` to match
(`tests/test_sample_sgw.sh` fails until they agree). The base copies its binaries from the
gateway image, so no step can be skipped. The build requires access to `ghcr.io` and
`pkg-containers.githubusercontent.com`.

## Local build

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t sgw-devcontainer-base:dev \
  .
```

A single-platform build for local testing:

```sh
docker build -t sgw-devcontainer-base:dev .
docker run --rm -it sgw-devcontainer-base:dev zsh
# to take the relay from a locally built sekimore-gw image
docker build -t sgw-devcontainer-base:dev --build-arg SEKIMORE_GW_IMAGE=sekimore-gw:relay-dev .
```

## License

MIT
