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
- **`mise` (jdx/mise) pre-installed**
  単一バイナリで python / node / ruby / php / rust / go 等を一括管理。
  言語の具体バージョンは含まない — `mise use -g python@3.13.0` 等は利用側で。
  shims ディレクトリ (`~/.local/share/mise/shims`) は Dockerfile の `ENV PATH`
  で先頭に入れているので、Claude Code の tool 実行や `docker exec cmd`、
  postCreateCommand などの **非対話プロセスからも** 言語コマンドが解決できる。
  利用側で言語を pre-install する場合は `~/.local/share/mise/installs` を
  `~/.local/share/mise/installs-default` にステージングし、volume マウントで
  空になっても post-create で
  `rsync -a --ignore-existing ~/.local/share/mise/installs-default/ \
    ~/.local/share/mise/installs/ && mise reshim`
  で復元できる (サンプル `examples/sgw-sample/` を参照)
- Claude Code CLI
- AWS CLI v2
- Docker CE + buildx + compose plugin
- `sekimore-gw` agent-setup script (`/usr/local/bin/sekimore-agent-setup.sh`)
- デフォルト zsh rc.d スニペット (`/etc/skel/zsh-rc.d/`)
  XDG 設定、mise activate、エイリアス、プラグイン設定を含む。
  post-create で `~/.config/zsh/rc.d/` にコピーして使う

## What's NOT inside

案件固有の情報は一切含まない。以下は利用側の devcontainer で用意する:

- 言語ビルド依存 (`build-essential`, `autoconf`, `libssl-dev`, `libyaml-dev`,
  `libxml2-dev` 等) — `mise` でソースビルドが必要な言語 (Ruby, PHP など) を
  入れる場合に利用側で追加。サンプル `examples/sgw-sample/Dockerfile` に
  Ruby / Rust 有効 + PHP コメントアウトの構成例がある
- `sekimore-gw` サービス本体 (docker-compose の別サービスとして動かす)
- `.env` / `config.yml` / squid 設定などの案件別コンフィグ
- プロジェクト固有の zsh rc.d オーバーレイ (base のデフォルトを上書き・追加する場合)
- workspace のマウント
- Docker daemon 起動に必要なランタイム権限 (`NET_ADMIN`, `privileged`, cgroup, `/var/lib/docker` ボリュームなど)

## Usage

完全なサンプルは [`examples/sgw-sample/`](examples/sgw-sample/) を参照。
最小構成は次の通り:

```dockerfile
FROM ghcr.io/amakata/sgw-devcontainer-base:latest

# 案件固有の追加だけを書く
# 例: mise use -g python@3.13.0 && mise reshim
```

> 新しい言語バージョンを `mise use -g` で導入したあとは `mise reshim` を
> 実行して shims ディレクトリを再生成すること。

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
