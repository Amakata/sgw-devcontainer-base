# sgw-devcontainer-base

DevContainer で利用する **ベースイメージ**。
sekimore-gw (セキュリティゲートウェイ) を経由するネットワーク構成を前提に、
毎回のビルドを速くするために案件非依存の共通部分だけを焼き込んだイメージ。

配布先: `ghcr.io/amakata/sgw-devcontainer-base`
対応プラットフォーム: `linux/amd64`, `linux/arm64`

## What's inside

- Base: `mcr.microsoft.com/devcontainers/base:bookworm` (`vscode` user, uid=1000)
- Shell tooling: `fzf`, `iptables`, `iproute2`, `iputils-ping`, `dnsutils`, `jq`, `nano`, `vim`, `pv`, `wget`, `curl`, `unzip`, `sudo`, `rsync`, `gnupg`
- DB client dev headers: `libpq-dev`, `default-libmysqlclient-dev`
- `git-delta`
- **GitHub CLI (`gh`)**
- zsh + oh-my-zsh + プラグイン
  (`zsh-completions`, `zsh-autosuggestions`, `zsh-syntax-highlighting`,
   `fast-syntax-highlighting`, `zsh-autocomplete`)
- **`anyenv` + `anyenv-update`, `pyenv` / `nodenv` / `rbenv` / `phpenv` プラグイン pre-installed**
  (言語の具体バージョンは含まない — `pyenv install 3.x` 等は利用側で)
  `~/.anyenv/envs` は `~/.anyenv/envs-default` にステージングされているので、
  volume マウントで `~/.anyenv/envs` が空になっても
  `rsync -a ~/.anyenv/envs-default/ ~/.anyenv/envs/` で復元できる
- Claude Code CLI
- AWS CLI v2
- Docker CE + buildx + compose plugin (**rootless mode**, `dockerd-rootless.sh` 経由)
  `vscode` ユーザーで `$XDG_RUNTIME_DIR/docker.sock` に listen。`DOCKER_HOST` は
  rc.d スニペットで自動 export される
- `sekimore-gw` agent-setup script (`/usr/local/bin/sekimore-agent-setup.sh`)
- デフォルト zsh rc.d スニペット (`/etc/skel/zsh-rc.d/`)
  XDG 設定、anyenv init、エイリアス、プラグイン設定を含む。
  post-create で `~/.config/zsh/rc.d/` にコピーして使う

## What's NOT inside

案件固有の情報は一切含まない。以下は利用側の devcontainer で用意する:

- PHP ビルド依存 (`build-essential`, `autoconf`, `libxml2-dev` 等) — `phpenv install` したい場合のみ追加
  (サンプル `examples/sgw-sample/Dockerfile` を参照)
- `sekimore-gw` サービス本体 (docker-compose の別サービスとして動かす)
- `.env` / `config.yml` / squid 設定などの案件別コンフィグ
- プロジェクト固有の zsh rc.d オーバーレイ (base のデフォルトを上書き・追加する場合)
- workspace のマウント
- Docker daemon 起動に必要なランタイム権限。`--privileged` は不要。
  devcontainer 側に以下を設定する(docker-compose の場合):
  - `cap_add: [NET_ADMIN]` (agent-setup 用。NET_RAW / SETUID / SETGID は Docker デフォルト cap に含まれる)
  - `security_opt: [seccomp=unconfined, apparmor=unconfined, systempaths=unconfined]`
  - `devices: [/dev/fuse:/dev/fuse]` (fuse-overlayfs フォールバック用)
  - rootless dockerd のデータ領域 (`~/.local/share/docker`) 用の named volume

## Usage

完全なサンプルは [`examples/sgw-sample/`](examples/sgw-sample/) を参照。
最小構成は次の通り:

```dockerfile
FROM ghcr.io/amakata/sgw-devcontainer-base:latest

# 案件固有の追加だけを書く
# 例: phpenv install 8.3.0
```

## Tags

GitHub Actions (`.github/workflows/build-and-push.yml`) が次のタグで GHCR に push する:

| トリガー | タグ |
| --- | --- |
| `main` への push | `main`, `latest`, `sha-<short>` |
| `v1.2.3` タグ push | `1.2.3`, `1.2`, `1`, `sha-<short>` |
| PR | (push しない、ビルドのみ) |

## Local build

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t sgw-devcontainer-base:dev \
  .
```

単一プラットフォームでのローカルテスト:

```sh
docker build -t sgw-devcontainer-base:dev .
docker run --rm -it sgw-devcontainer-base:dev zsh
```

## License

MIT
