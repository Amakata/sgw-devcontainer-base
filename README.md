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
  どちらも **同じ `sekimore-gw` イメージ** (`ARG SEKIMORE_GW_IMAGE`、既定 `ghcr.io/amakata/sekimore-gw:0.2.13`)
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

## はじめかた (新規プロジェクト)

このイメージ単体では使えない。gateway (sekimore-gw) と dev の 2 コンテナを compose で組み、
ホスト側の操作を mise task にまとめた一式が要る。それが
[`examples/sgw-sample/`](examples/sgw-sample/) で、**新規はここを複製して始める。**

```bash
# 1. 雛形を自分のプロジェクトへ複製する
cp -r examples/sgw-sample/.devcontainer  /path/to/your-project/
cp    examples/sgw-sample/mise.toml      /path/to/your-project/

# 2. 値を埋める
cd /path/to/your-project
cp .devcontainer/.env.sample .devcontainer/.env     # 案件名、ユーザ名、メール
$EDITOR .devcontainer/config/config.yml             # relay.project.repos と permissions
```

そのあとは [`examples/sgw-sample/README.md`](examples/sgw-sample/README.md) の手順に従う。
要点だけ:

| | |
| --- | --- |
| `mise run vscode` | **`code` コマンドではなくこれで開く。** 依頼者の ssh-agent を dev に渡さないため |
| `mise run gw:unlock` | 秘密ストアの解錠。**gateway を作り直すたびに毎回** |
| `mise run gw:login` | 初回だけ。解錠より先には実行できない (保存先が開いていないため) |
| `mise run dev:signing-key` | 出た公開鍵を GitHub に Signing Key として登録する |
| `mise run relay:verify` | 一式の確認。ここが緑になって完了 |

`mise.toml` と `.devcontainer/` は**複製した時点であなたのもの**で、こちらが更新しても
自動では追従しない。下の「更新のしかた」を参照。

## 更新のしかた

追いかける版が 3 つある。**独立していないので順に上げる。**

```
sekimore-gw (gateway)  ── このイメージが relay バイナリを取り込む
        ↓
sgw-devcontainer-base  ── あなたの .devcontainer/Dockerfile が FROM する
        ↓
あなたのプロジェクトの複製 (mise.toml / .devcontainer/)
```

### 1. gateway を上げる

`.devcontainer/docker-compose.yml` の `image:` タグを上げて:

```bash
mise run gw:recreate     # pull して作り直す。docker restart では入れ替わらない
mise run gw:unlock       # 鍵はメモリにしか無いので、作り直したら必ず
```

何が変わるかは [sekimore-gw の CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.ja.md)
と [relay の CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.ja.md) にある。

### 2. base イメージを上げる

`.devcontainer/Dockerfile` の `FROM` のタグを上げて、VS Code の **Rebuild Container**。

### 3. 複製したファイルを追従させる

**これが抜けやすい。** `mise.toml` と `.devcontainer/scripts/sgw.sh` はあなたの複製なので、
雛形が変わっても届かない。実際、公開されていた雛形は `gw:unlock` を 4 版ぶん欠いたままで、
0.2.19 の gateway では GitHub API が使えない状態だった。

gateway を上げたら、雛形との差分を見る:

```bash
diff -u /path/to/sgw-devcontainer-base/examples/sgw-sample/mise.toml  mise.toml
diff -u /path/to/sgw-devcontainer-base/examples/sgw-sample/.devcontainer/scripts/sgw.sh \
        .devcontainer/scripts/sgw.sh
```

自分で足したタスクは残し、`gw:*` の追加分だけ取り込む。

### 0.0.8 以前の gateway から上げる場合

**設定は書き換えなくてよい。** v0.0.8 から現在までの `config.yml` は**追加だけ**で、
キーの削除も改名も無い (`allow_domains` / `block_domains` / `allow_ips` / `block_ips` /
`proxy` / `network` / `database_path` はそのまま通る)。イメージのタグを上げて
`mise run gw:recreate` するだけで、DNS フィルタ・ファイアウォール・Squid はそれまでどおり動く。

関所 (relay) は **v0.0.8 には存在しない**。0.1.0 で入った追加機能で、**opt-in** である。
`config.yml` に `domain_handlers` と `relay` を書かなければ relay は起動せず、
それ以外は何も変わらない。つまり:

| やりたいこと | 必要な作業 |
| --- | --- |
| 版を上げるだけ | image タグを上げて `gw:recreate`。設定はそのまま |
| AI に GitHub を触らせる (関所を使う) | `config.yml` に `domain_handlers` + `relay` を足す。下記 |

関所を使うなら、0.0.8 の構成に無いものが要る。**relay 側は独立した overlay compose に
まとまっている**ので、足すのは 3 つ:

1. `config.yml` に `domain_handlers` と `relay`
   ([`config/config.sample.yml`](https://github.com/Amakata/sekimore-gw/blob/main/config/config.sample.yml) の末尾がそのまま雛形)
2. [`docker-compose.relay.yml`](examples/sgw-sample/.devcontainer/docker-compose.relay.yml) を複製し、
   `devcontainer.json` の `dockerComposeFile` に `docker-compose.yml` の**後ろ**に並べる。
   ssh-agent のマウントと使い捨て鍵の volume はこれが持っている
3. `.env.sample` を `.env` にして案件名などを埋める (上の overlay が参照する)

そのあと `mise run gw:unlock` → `gw:login` → `dev:signing-key` → `relay:verify`。

やめたくなったら `dockerComposeFile` から overlay を外し、`config.yml` の
`domain_handlers` と `relay` を消すだけで 0.0.8 相当の動きに戻る。

ここまで足すと 0.0.8 の `.devcontainer/` とは別物なので、**雛形を複製し直して
`config.yml` の `allow_domains` などを持ち込むほうが早い。**

0.1.x 以降に関所を使っていた場合だけ、途中の破壊的変更が効く
(0.1.9 の権限統合、0.2.6 の `handler: git-relay` → `github`、0.2.7 の `relay.project.boards` 必須化)。
0.0.8 からなら関所を新規に書くので、どれも当たらない。

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
| 0.2.16 以降 | `0.2.15` (`ARG SEKIMORE_GW_IMAGE`) | base 自身の変更のみ。gateway は据え置き。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.15 | `0.2.14` | リロードで静的 IP が落ちる件ほかの修正。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.14 | `0.2.13` | 設定の反映に窓を設けた (`reload:`)。境界のレビューで見つかった穴の修正。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.13 | `0.2.13` (`ARG SEKIMORE_GW_IMAGE`) | 設定の反映に窓を設けた (`reload:`)。境界のレビューで見つかった穴の修正。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.12 | `0.2.11` | 内部構造の整理のみ (CLI とハンドラの分割)。挙動の変更なし。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.11 | `0.2.10` | 死蔵コードの削除、効いていなかった環境変数の修正、`login` 失敗時にプロキシ経由かを示す。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.10 | `0.2.9` | merge オプション、reopen、`release edit`、`ci rerun`、`repo vocabulary`。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.9 | `0.2.8` | PR / Issue の読み取り (`pr view` / `pr comments` / `issue view` ほか) と案件横断の `sekimore search`。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.8 | `0.2.7` | セキュリティ修正 (タグ / ref のパス traversal、Projects のボード限定)。`sekimore pr request-review`、`sekimore project fields`。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.7 | `0.2.6` | `sekimore release create --tag vX.Y.Z` (本文は GitHub が生成)。handler は `github` (`git-relay` も引き続き有効)。`--build-arg SEKIMORE_GW_IMAGE=...` で差し替え可 |
| 0.2.6 | `0.2.5` | CLI が英語 / 日本語を切り替える (`SEKIMORE_LANG`、既定は英語)。`sekimore guide --lang en\|ja`。AI 向けの指示は英語で置く |
| 0.2.5 | `0.2.2` | relay 同梱 (`sekimore guide`、agent-setup が Claude / Codex 向けの入口を置く、送信上限) |
| 0.2.4 | `0.2.0` | relay 同梱 (複数上流 / `--upstream`) |
| 0.2.3 | `0.1.7` | relay 同梱 (`ci runs --ref`) |

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
