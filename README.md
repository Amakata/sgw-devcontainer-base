# sgw-devcontainer-base

DevContainer で利用する **ベースイメージ**。
sekimore-gw (セキュリティゲートウェイ) を経由するネットワーク構成を前提に、
毎回のビルドを速くするためにプロジェクト非依存の共通部分だけを焼き込んだイメージ。

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
- `sekimore-gw` agent-setup script (`/usr/local/bin/sekimore-agent-setup.sh`) と
  `sekimore-relay` CLI (`/usr/local/bin/sekimore-relay`)、ラッパー `sekimore`。
  どちらも **同じ `sekimore-gw` イメージ** (`ARG SEKIMORE_GW_IMAGE`、既定 `ghcr.io/amakata/sekimore-gw:0.1.2`)
  から `COPY --from` で取るので版がずれない。gateway に relay (git / GitHub API 中継関所) が居れば
  agent-setup が使い捨て鍵・案件トークン・known_hosts・署名鍵を自動で用意する
  (`examples/sgw-sample/.devcontainer/docker-compose.relay.yml` 参照)
- デフォルト zsh rc.d スニペット (`/etc/skel/zsh-rc.d/`)
  XDG 設定、mise activate、エイリアス、プラグイン設定を含む。
  post-create で `~/.config/zsh/rc.d/` にコピーして使う

## What's NOT inside

プロジェクト固有の情報は一切含まない。以下は利用側の devcontainer で用意する:

- 言語ビルド依存 (`build-essential`, `autoconf`, `libssl-dev`, `libyaml-dev`,
  `libxml2-dev` 等) — `mise` でソースビルドが必要な言語 (Ruby, PHP など) を
  入れる場合に利用側で追加。サンプル `examples/sgw-sample/Dockerfile` に
  Ruby / Rust 有効 + PHP コメントアウトの構成例がある
- `sekimore-gw` サービス本体 (docker-compose の別サービスとして動かす)
- `.env` / `config.yml` / squid 設定などのプロジェクト別コンフィグ
- プロジェクト固有の zsh rc.d オーバーレイ (base のデフォルトを上書き・追加する場合)
- workspace のマウント
- Docker daemon 起動に必要なランタイム権限 (`NET_ADMIN`, `privileged`, cgroup, `/var/lib/docker` ボリュームなど)

## Usage

完全なサンプルは [`examples/sgw-sample/`](examples/sgw-sample/) を参照。
sample の `mise.toml` にホスト側の操作 (`mise run vscode` / `gw:login` / `relay:verify` など) がまとまっている。
最小構成は次の通り:

```dockerfile
FROM ghcr.io/amakata/sgw-devcontainer-base:latest

# プロジェクト固有の追加だけを書く
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

## sekimore-gw との版の組合せ

| このイメージ | 取り込む sekimore-gw | 備考 |
| --- | --- | --- |
| main 以降 | `0.1.2` (`ARG SEKIMORE_GW_IMAGE`) | relay 同梱。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |

更新順序: sekimore-gw をタグ → GHCR 公開 → このリポジトリの `SEKIMORE_GW_IMAGE` 既定を上げて push →
GHCR 公開 → `examples/sgw-sample` の compose の image tag を追従。base はバイナリを gateway イメージから取るため、
順序を飛ばせない。ビルドには `ghcr.io` と `pkg-containers.githubusercontent.com` への到達が必要。

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
# ローカルでビルドした sekimore-gw イメージから relay を取る場合
docker build -t sgw-devcontainer-base:dev --build-arg SEKIMORE_GW_IMAGE=sekimore-gw:relay-dev .
```

## License

MIT
