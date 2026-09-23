# sgw-devcontainer-base changelog

*[日本語版](CHANGELOG.ja.md)*

The devcontainer base image: the Dockerfile and the tools baked into it, the zsh
configuration and the scripts it ships, and the sample devcontainer under
`examples/`.

Entries are grouped **Security**, **Fix**, **Enhancement** — most urgent first —
and say what changed, with the pull request that changed it. The reasoning is in
the pull request.

Every release names the sekimore-gw version it takes (`ARG SEKIMORE_GW_IMAGE` in
the Dockerfile), so the pairing between the two is this file.

Starts at 0.2.18. Releases before it are not written up here; the pull requests
and the tag on each are the record. The gateway each of them took is at the
bottom.

## 0.2.23 (2026-09-23)

### Fix

- `dev:shell` gets `raw = true`: in mise's prefix output mode its stdout was a pipe, so the shell started without a terminal and showed no prompt. CI now fails on any task that starts a shell or goes through `gw-tty` without `raw = true` (#51)
- `relay:verify` checks that `user.signingkey` is the key the gateway's signing socket offers, and says so when it is not — an inline `key::` value, or a key file the socket does not offer (#51)

### Enhancement

- takes gateway 0.2.31 (#51)

## 0.2.22 (2026-09-23)

### Fix

- `postStartCommand` runs the distributed `.devcontainer/sgw/post-start.sh`, which passes every `SEKIMORE_*` variable through `sudo` to agent-setup; a variable missing from a hand-kept `--preserve-env=` list was silently ignored, and the sample had none. `mise run upgrade` points at the one-line change, and a plain check now shows what the project's own files need (#49)

## 0.2.21 (2026-09-23)

### Enhancement

- takes gateway 0.2.30, and the sample runs gateway 0.2.30 with its task file (#47)

## 0.2.20 (2026-09-23)

### Enhancement

- `mise run upgrade` compares the pinned gateway and base with the newest on GHCR and says what would change; `upgrade:apply` rewrites the two tags, replaces `.devcontainer/sgw/`, recreates the gateway after asking and unlocks it, then lists only what a person has to do. A hand-edited distributed file stops it with the diff before anything is written. `upgrade:sync` replaces `gw:sync-tasks`, and `upgrade:notes` prints the UPGRADING sections in between (#45)
- the host scripts and tasks move into `.devcontainer/sgw/`, which `upgrade` owns; `mise.toml` keeps only the includes and the project's own tasks, and a task there wins over the distributed one of the same name. The sample moves to the layout and pins `FROM` to a version (#45)
- what `upgrade.sh`, `sgw.sh` and `vscode.sh` print, and the task descriptions, follow the relay's language rule: `SEKIMORE_LANG`, `LC_ALL`, `LC_MESSAGES`, `LANG` (#45)

## 0.2.19 (2026-09-22)

### Fix

- the sample devcontainer takes gateway 0.2.29 — the one this image takes — instead of the 0.2.19 it was pinned to, its comments are English throughout as the rest of the sample has been since 0.2.18, and `gw:sync-tasks` pulls the English task file out of the image, so the `gateway.mise.toml` committed beside it is 0.2.29's and has `gw:unlock-auto` (#41)
- `mise run web` opens the port the gateway actually publishes, read off the running container through the new `sgw.sh port <service> [container-port]`, instead of a number written into the task. The sample publishes `8080:8080` so its literal was right, which is what hid this: it breaks once a project moves the port because 8090 is taken, which is what a sample is copied in order to do (#42)

## 0.2.18 (2026-09-21)

### Fix

- the `sekimore` wrapper renews an expired project token again: it calls `POST /bootstrap` (`sekimore-relay agent bootstrap` never existed) and rewrites the env file in place, because its directory is root's (#38)

### Enhancement

- takes gateway 0.2.29 (#40)
- README.md is English and README.ja.md Japanese, as the other repositories are; the sample `config.yml` is commented in English and lists every key the gateway reads, all 28 permissions among them (#39)
- added this changelog, in English and Japanese, in the shape the gateway and the relay already use (#26)

## Before 0.2.18

Not written up: the pull request and the tag on each is the record. What is kept
here is the gateway each one took.

- 0.2.17 took gateway 0.2.15
- 0.2.16 took gateway 0.2.15
- 0.2.15 took gateway 0.2.14
- 0.2.14 took gateway 0.2.13
- 0.2.13 took gateway 0.2.13
- 0.2.12 took gateway 0.2.11
