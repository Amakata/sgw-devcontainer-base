# sgw-sample

*[日本語版](README.ja.md)*

The smallest devcontainer built on `sgw-devcontainer-base`.

- A network kept apart, everything going through `sekimore-gw`
- Set up for `sekimore-relay`, the relay that carries git and the GitHub API
  (`docker-compose.relay.yml`). The AI uses `git@github.com:Org/Repo.git` as it is, but its key
  is disposable and the upstream is authenticated by the operator's ssh-agent inside the
  gateway. Repositories outside the project, and operations that are not permitted, are refused
  by the relay
- A thin `Dockerfile` that only does `FROM` the base image
- An example of installing particular versions of Python / Node.js / Ruby / Rust with `mise`
  (PHP is commented out in the Dockerfile and can be enabled when it is wanted)

## Using it

The host-side operations (Mac + Docker Desktop) are mise tasks (`mise tasks` lists them). They
live in `.devcontainer/sgw/`, which `mise run upgrade:apply` keeps current; `mise.toml` is yours,
and only includes them.

1. Copy `.devcontainer/.env.sample` to `.devcontainer/.env` and fill in the values
   (`SEKIMORE_AGENT_SOCK` is the operator's ssh-agent socket; on Docker Desktop the default is
   right)
2. Rewrite `config/config.yml`'s `relay.project.repos` / `permissions` to this project's own
3. Start Docker Desktop (with the ssh-agent usable), **quit VS Code completely (Cmd+Q)**, then run
   **`mise run vscode`** in Terminal.app and "Reopen in Container".
   macOS's `code` CLI starts the app through `open`, so `env -u SSH_AUTH_SOCK code` does not
   reach it. This task removes `SSH_AUTH_SOCK` from launchd, starts the app directly, and checks
   the app's environment afterwards (`mise run vscode:check`). Run
   `mise run vscode:restore-agent-env` before restarting Docker Desktop.
   VS Code is started without `SSH_AUTH_SOCK` because the Dev Containers extension forwards the
   operator's ssh-agent into dev unconditionally, with no setting to turn it off. Opened the
   ordinary way, post-create **stops with an ERROR** and points at this procedure
4. Unlock the secret store with **`mise run gw:unlock`**. **Needed every time the gateway is
   recreated.** Since 0.2.19 the upstream API token lives in that store, and while it is locked
   the relay cannot use the GitHub API at all (git push/pull go over SSH, so they still work).
   The key is only ever in memory, so unlock again whenever the gateway restarts
5. On the gateway, the first time only, **`mise run gw:login`** (device flow; it saves the
   upstream token and known_hosts). It cannot run before the unlock — there is nowhere open to
   save to
6. Register the signing public key that **`mise run dev:signing-key`** prints on GitHub under
   Settings -> SSH and GPG keys, as a "Signing Key" (the AI's commits are signed with that key
   rather than yours). The key's comment, which becomes the Title on GitHub, is
   "sekimore-agent-signing: \<project\> / \<your name\> \<email\>". To change it, set
   `SEKIMORE_SIGNING_KEY_COMMENT` in `.env`
7. Check the whole set with **`mise run relay:verify`** (the gateway's state, that no agent
   reaches dev, git through the relay, and the denial of a repository outside the project)

Day to day: `mise run gw:check` (state) / `mise run gw:tokens` / `mise run gw:audit` (the audit
log) / `mise run gw:revoke-project` (the project is over) /
`mise run gw -- <any sekimore-relay subcommand>`.

Without the relay, drop `docker-compose.relay.yml` from `devcontainer.json`'s
`dockerComposeFile` and delete `domain_handlers:` / `relay:` from `config/config.yml` (the gw:* and
relay:* tasks are then unnecessary too).

To use this for a new project, copy `.devcontainer/` and `mise.toml`. From then on,
`mise run upgrade` says whether anything is newer and `mise run upgrade:apply` moves to it.

## The files

```
sgw-sample/
├── README.md
├── mise.toml                       # yours: includes .devcontainer/sgw/, and your own tasks
└── .devcontainer/
    ├── devcontainer.json
    ├── docker-compose.yml          # two services, dev and sekimore-gw
    ├── docker-compose.relay.yml    # the overlay for sekimore-relay (the agent socket's mount, the key volume)
    ├── Dockerfile                  # FROM sgw-devcontainer-base + particular versions installed with mise
    ├── .env.sample
    ├── .gitignore
    ├── config/
    │   ├── config.yml              # sekimore-gw's list of permitted domains + the relay's project policy
    │   └── squid/
    │       └── squid.conf.template
    ├── scripts/
    │   └── post-create.sh          # unpacks zsh rc.d, detects agent forwarding (and stops with an ERROR)
    ├── sgw/                        # distributed: mise run upgrade:apply replaces all of it. Do not edit
    │   ├── tasks.mise.toml         # the host-side tasks (vscode / web / relay:verify / upgrade …)
    │   ├── gateway.mise.toml       # the gateway's tasks (gw:*), for the version it runs
    │   ├── sgw.sh                  # finds the gateway / dev container by compose label and docker execs into it
    │   ├── vscode.sh               # mise run vscode
    │   ├── upgrade.sh              # mise run upgrade
    │   ├── post-start.sh           # what postStartCommand runs: agent-setup (with every SEKIMORE_* variable), docker-init, post-create
    │   └── MANIFEST                # what upgrade wrote last, to tell an edit apart
    └── zsh-config/
        └── rc.d/                   # the project's own zsh configuration
```
