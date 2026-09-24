# sgw-devcontainer-base

*[English](README.md)*

**AI エージェントに開発環境を渡しても、GitHub アカウントと鍵は渡さない devcontainer。**

エージェントは作業をさせてこそ役に立つ。しかしトークンを渡せば `repo` スコープ、つまり
**アカウントがアクセスできるすべてのリポジトリへの読み書き権限**が渡り、ターミナルを持つエージェントは
`~/.ssh` も `.env` も読める。

VS Code の Dev Containers で環境をコンテナに閉じ込め、この構成では**コンテナから外へ出る通信を
すべてゲートウェイ (sekimore-gw) に通す**。そのため、資格情報はエージェントの外に置かれたままになる。
エージェントが持つのは使い捨ての鍵だけで、この鍵はゲートウェイ以外では通用しない。

GitHub の操作は `sekimore` コマンドで行い、**どの操作を許可するかは 33 種類の権限から選べる**
(例: `pr:create` は許可、`pr:merge` は拒否)。このイメージには意図して `gh` を入れていない。
トークンを持たせると `gh` はゲートウェイを通らずに GitHub へ直接接続し、それらの権限がどれも効かなくなるためである。

このイメージは、その構成の dev 側である。

## 特長

| | |
|---|---|
| **鍵を渡さずに git を使える** | エージェントが持つのは、ゲートウェイだけが受け付ける使い捨ての鍵。GitHub に届くのは、ゲートウェイがあなたの鍵で転送したものだけ |
| **GitHub の操作を 1 つずつ許可できる** | 例: `pr:merge` は拒否、`issue:create` は許可。プロジェクト外のリポジトリにはどの操作も届かない |
| **許可した宛先にしか接続できない** | 許可リストにないドメインは名前解決できず、その IP アドレスへの接続はファイアウォールが破棄する |
| **外へ送るデータ量に上限がある** | ゲートウェイが扱う宛先への送信バイト数を数え、上限を超えたら接続を切断して記録する |
| **コミットが Verified になる** | 署名鍵はゲートウェイ側にある。dev コンテナからは署名を依頼できるだけで、鍵そのものは読み出せない |
| **ビルドが速い** | 言語ランタイム以外はすべてイメージに入っている |

ゲートウェイそのものについては [sekimore-gw](https://github.com/Amakata/sekimore-gw) を参照。

配布先: `ghcr.io/amakata/sgw-devcontainer-base`
対応プラットフォーム: `linux/amd64`, `linux/arm64`

## 新規プロジェクトのはじめかた

このイメージ単体では使えない。ゲートウェイ (sekimore-gw) と dev の 2 コンテナからなる compose 構成と、
ホスト側の操作をまとめた mise タスクが必要である。これを一式にしたものが
[`examples/sgw-sample/`](examples/sgw-sample/) で、**新規プロジェクトはこれを複製して始める。**

```bash
# 1. 雛形を自分のプロジェクトへ複製する
cp -r examples/sgw-sample/.devcontainer  /path/to/your-project/
cp    examples/sgw-sample/mise.toml      /path/to/your-project/

# 2. 値を埋める
cd /path/to/your-project
cp .devcontainer/.env.sample .devcontainer/.env     # プロジェクト名、ユーザー名、メール
$EDITOR .devcontainer/config/config.yml             # relay.project.repos と permissions
```

[`config.yml`](examples/sgw-sample/.devcontainer/config/config.yml) には **ゲートウェイが読むキーが
すべて載っている**。サンプルが設定しているキーは有効になっており、それ以外のキーは既定値と
「どういうときに変えるか」の説明を添えてコメントアウトしてある。権限キーは 33 個すべてが
1 行ずつ並んでいる。影響の大きい操作 (`pr:merge`、`ci:rerun`、`security:dismiss` など) は
コメントアウトしてあるので、プロジェクトで必要になったらコメントを外して有効にする。コメントは英語で書いてある。

そのあとは [`examples/sgw-sample/README.md`](examples/sgw-sample/README.md) の手順に従う。
要点は次のとおり。

| | |
| --- | --- |
| `mise run vscode` | **`code` コマンドではなく、このタスクで VS Code を開く。** 運用者の ssh-agent を dev コンテナに渡さないため |
| `mise run gw:unlock` | 秘密ストアを解錠する。**ゲートウェイを作り直すたびに必要** |
| `mise run gw:login` | 最初に一度だけ実行する。書き込み先のストアがまだ開いていないため、解錠より先には実行できない |
| `mise run dev:signing-key` | 公開鍵を表示する。これを GitHub に Signing Key として登録する |
| `mise run relay:verify` | 構成全体を確認する。この確認が通れば設定は完了 |

**複製したものはその時点からプロジェクトのものになるが、`.devcontainer/sgw/` だけは例外である。**
ここにはホスト側のスクリプトとタスクが入っており、`mise run upgrade:apply` が入れ替える。
自分のタスクは `mise.toml` に書く。配布タスクと同じ名前のタスクを書くと、`mise.toml` のほうが優先される。

### プロジェクトの最小の Dockerfile

一式を配置したあと、プロジェクト自身の Dockerfile に必要なのは次の内容だけである。

```dockerfile
# latest ではなく版を書く。`mise run upgrade` がこれを読んで上げる
FROM ghcr.io/amakata/sgw-devcontainer-base:0.2.34

# プロジェクト固有の追加だけを書く
# 例: mise use -g python@3.13.0 && mise reshim
```

> `mise use -g` で新しい言語バージョンを導入したあとは、`mise reshim` を実行して
> shims ディレクトリを再生成する。

## イメージの内容

| | |
|---|---|
| ベース | `mcr.microsoft.com/devcontainers/base:bookworm` (`vscode` ユーザー、uid=1000) |
| シェル | zsh、oh-my-zsh とプラグイン、`fzf`, `jq`, `vim`, `nano`, `curl`, `wget`, `unzip`, `rsync`, `pv`, `gnupg`, `sudo` |
| ネットワーク | `iptables`, `iproute2`, `iputils-ping`, `dnsutils` |
| Git | `git-delta` |
| DB ヘッダ | `libpq-dev`, `default-libmysqlclient-dev` |
| 言語 | `mise`。Python、Node.js、Ruby、PHP、Rust、Go を単一のバイナリで管理する。言語のバージョンは含まない ([後述](#mise-と-shims)) |
| AI | Claude Code CLI、OpenAI Codex CLI |
| クラウド | AWS CLI v2、Docker CE (buildx と compose を含む) |
| ゲートウェイ | `sekimore-agent-setup.sh`、`sekimore-relay` CLI、`sekimore` ラッパー ([後述](#ゲートウェイのツール)) |
| zsh の既定設定 | `/etc/skel/zsh-rc.d/`: XDG 設定、mise の activate、エイリアス、プラグイン。post-create が `~/.config/zsh/rc.d/` に複製する |

### mise と shims

このイメージには言語のバージョンを含めない。`mise use -g python@3.13.0` などで、プロジェクト側で追加する。
shims ディレクトリ (`~/.local/share/mise/shims`) は `ENV PATH` の先頭にあるので、
**非対話プロセスからも**言語のコマンドを解決できる。Claude Code のツール呼び出し、`docker exec cmd`、
postCreateCommand がこれにあたる。ログインシェルでは Debian の `/etc/profile` が `PATH` を設定し直して
shims ディレクトリが外れるため、`/etc/profile.d` のスクリプトがこれを戻している。

プロジェクト側のイメージで言語をプリインストールするには、ビルド時に `~/.local/share/mise/installs` を
`~/.local/share/mise/installs-default` にコピーしておく。前者のディレクトリは volume をマウントすると
空になるが、post-create が次のコマンドで復元する。

```bash
rsync -a --ignore-existing ~/.local/share/mise/installs-default/ \
  ~/.local/share/mise/installs/ && mise reshim
```

### ゲートウェイのツール

`sekimore-agent-setup.sh` と `sekimore-relay` CLI は、**同じ `sekimore-gw` イメージ**から
`COPY --from` で取り込むので、両者の版はずれない。`sekimore` ラッパーはこのリポジトリの一部
(`scripts/sekimore`) で、`sekimore-relay agent` を実行する。ゲートウェイイメージを決めるのは
Dockerfile の `ARG SEKIMORE_GW_IMAGE` だけで、現在は `ghcr.io/amakata/sekimore-gw:0.2.36` である。
ローカルビルドでは `--build-arg SEKIMORE_GW_IMAGE=...` で差し替えられる。

ゲートウェイで関所 (sekimore-relay) が動いている場合、agent-setup が使い捨ての鍵、プロジェクトトークン、`known_hosts`、
署名鍵を自動で用意する (`examples/sgw-sample/.devcontainer/docker-compose.relay.yml` を参照)。
プロジェクトトークンの有効期間は `relay.token_ttl` (既定 12 時間) である。トークンが期限切れになると
`sekimore` ラッパーが bootstrap を再実行して新しいトークンを取得するので、コンテナを再起動する必要はない。

## 含まれないもの

このイメージにプロジェクト固有のものは一切含まれない。以下はプロジェクト側の dev コンテナ で用意する。

- 言語のビルド依存 (`build-essential`, `autoconf`, `libssl-dev`, `libyaml-dev`, `libxml2-dev` など)。
  `mise` が言語をソースからビルドする場合 (Ruby、PHP) に必要。サンプルの
  `examples/sgw-sample/.devcontainer/Dockerfile` では Ruby と Rust を有効にし、PHP をコメントアウトしている
- `sekimore-gw` サービス本体 (docker-compose.yml の別サービス)
- プロジェクトごとの設定: `.env`、`config.yml`、Squid の設定
- プロジェクト固有の zsh rc.d オーバーレイ (既定の設定を上書き・追加するもの)
- workspace のマウント
- Docker デーモンに必要な実行時権限 (`NET_ADMIN`、`privileged`、cgroup、`/var/lib/docker` の volume)

## 最新に保つ

```bash
mise run upgrade          # 何が新しいか、どのファイルが変わるか、UPGRADING が何を求めるか。何も変更しない
mise run upgrade:apply    # 更新する
```

`upgrade:apply` は、`.devcontainer/docker-compose.yml` のゲートウェイの `image:` タグと
`.devcontainer/Dockerfile` の base の `FROM` タグを GHCR の最新の版に上げ、`.devcontainer/sgw/` を
その版のファイルに入れ替える。確認を求めたうえでゲートウェイを作り直し、解錠する (パスフレーズを
ホストに保存している場合は `gw:unlock-auto` を使う)。最後に、人にしかできない作業を表示する。

- base の版が変わった場合は、VS Code の **Rebuild Container**
- 旧版から新版までの間にある [UPGRADING.ja.md](UPGRADING.ja.md) の節。節があるのは、あなたのファイル
  (`config.yml` など) の編集を必要とするリリースだけである。`mise run upgrade:notes` で表示できる
- `git diff` の確認とコミット

`.devcontainer/sgw/` のファイルが手で書き換えられている場合、`upgrade:apply` は何も書き込まずに
差分を表示して止まる。変更を `mise.toml` に移し、ファイルを元に戻してから、もう一度実行する。

出力とタスクの説明の言語は、`LC_ALL`、`LC_MESSAGES`、`LANG` のうち最初に `ja` か `en` を示すもので決まる。
`SEKIMORE_LANG` はそれらすべてに優先する。言語を変えたら、`mise run upgrade:sync` でタスクファイルを取り直す。

3 つの版は互いに依存している。1 つのコマンドですべてを更新するのはそのためである。

```
sekimore-gw (ゲートウェイ)  ── このイメージが関所のバイナリを取り込む
        ↓
sgw-devcontainer-base  ── あなたの .devcontainer/Dockerfile が FROM する
        ↓
.devcontainer/sgw/     ── 両方に合わせたホスト側のスクリプトとタスク
```

変更内容は [ゲートウェイの CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.ja.md)、
[関所の CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.ja.md)、
[このリポジトリの CHANGELOG](CHANGELOG.ja.md) に書いてある。

`.devcontainer/sgw/` の導入より前に作ったプロジェクトは、一度だけ手で移行する:
[UPGRADING.ja.md](UPGRADING.ja.md#base-0220-devcontainersgw-と-mise-run-upgrade)。

### 0.0.8 以前のゲートウェイから上げる場合

**設定を書き換える必要はない。** v0.0.8 以降、`config.yml` のキーは**追加されただけ**で、
削除や改名はない (`allow_domains`、`block_domains`、`allow_ips`、`block_ips`、`proxy`、`network`、
`database_path` はすべてそのまま受け付けられる)。イメージのタグを上げて `mise run gw:recreate` を
実行すれば、DNS フィルタ、ファイアウォール、Squid はそれまでどおり動く。

関所は **v0.0.8 には存在しない**。0.1.0 で追加された機能で、**opt-in** である。
`config.yml` に `domain_handlers` と `relay` がなければ関所は起動せず、それ以外は何も変わらない。

| やりたいこと | 必要な作業 |
| --- | --- |
| 新しい版に上げるだけ | イメージのタグを上げて `gw:recreate` を実行する。設定はそのまま |
| AI エージェントに GitHub を使わせる (関所を使う) | `config.yml` に `domain_handlers` と `relay` を追加する。手順は下記 |

関所を使うには、0.0.8 の構成にないものが必要になる。**関所側の構成は独立した overlay compose
ファイルにまとまっている**ので、追加するのは次の 3 つである。

1. `config.yml` の `domain_handlers` と `relay`
   ([`config/config.sample.yml`](https://github.com/Amakata/sekimore-gw/blob/main/config/config.sample.yml) の末尾が現在の雛形)
2. [`docker-compose.relay.yml`](examples/sgw-sample/.devcontainer/docker-compose.relay.yml) の複製。
   `devcontainer.json` の `dockerComposeFile` に、`docker-compose.yml` の**後ろ**に並べる。
   ssh-agent のマウントと使い捨ての鍵の volume はこのファイルに入っている
3. `.env.sample` を `.env` に複製し、プロジェクト名などの値を埋めたもの (上の overlay が読む)

そのあと `mise run gw:unlock`、`gw:login`、`dev:signing-key`、`relay:verify` を順に実行する。

関所の利用をやめるには、`dockerComposeFile` から overlay を外し、`config.yml` から
`domain_handlers` と `relay` を削除する。ゲートウェイは 0.0.8 と同じ動作に戻る。

これらをすべて追加すると `.devcontainer/` は 0.0.8 の構成とは大きく異なるものになるため、
**雛形を複製し直して `allow_domains` などの設定を移すほうが早い。**

途中の版の破壊的変更が影響するのは、0.1.x から関所を使っている構成だけである
(0.1.9 の権限の統合、0.2.6 の `handler: git-relay` から `github` への改名、0.2.7 の `relay.project.boards` の必須化)。
0.0.8 から上げる場合は関所を新規に設定するので、どれも該当しない。

## タグ

GitHub Actions (`.github/workflows/build-and-push.yml`) が次のタグを GHCR に push する。

| トリガー | タグ |
| --- | --- |
| `main` への push | `main`, `latest`, `sha-<short>` |
| `v1.2.3` タグの push | `1.2.3`, `1.2`, `1`, `sha-<short>` |
| プルリクエスト | (ビルドのみ。push しない) |

## このイメージが使うゲートウェイの版

このイメージが **dev コンテナに入れる** ゲートウェイの構成要素、つまり `sekimore-relay` CLI と
`agent-setup.sh` は、Dockerfile の `ARG SEKIMORE_GW_IMAGE` が指定するイメージから取り込む。
現在は `ghcr.io/amakata/sekimore-gw:0.2.36` である。これを決めるのはこの ARG だけで、
ローカルビルドでは `--build-arg SEKIMORE_GW_IMAGE=...` で差し替えられる。各リリースがどの版を
使ったかは [CHANGELOG.ja.md](CHANGELOG.ja.md) に記録してある。

**プロジェクトが実際に動かす** ゲートウェイはこれとは別で、`.devcontainer/docker-compose.yml` の
`image:` タグで決まり、独立に更新できる。タグを上げて `mise run gw:recreate` を実行すればよく、
このイメージの新しいリリースを待つ必要はない。現在は 2 つの版が揃っている (このイメージもゲートウェイも 0.2.36)。
ゲートウェイの各版が何を求めるかは [UPGRADING.ja.md](UPGRADING.ja.md) にある。ほとんどの版は何も求めない。

リリースの順序は次のとおり。

1. sekimore-gw にタグを付ける。
2. GHCR に公開する。
3. このリポジトリの `SEKIMORE_GW_IMAGE` の既定値を上げて push する。
4. このイメージを GHCR に公開する。
5. `examples/sgw-sample` の compose ファイルのイメージタグを更新する。

base をリリースするときは、サンプルの `.devcontainer/Dockerfile` の `FROM` タグを新しい版に上げ、
`scripts/sync-sample-sgw.sh` でサンプルの `.devcontainer/sgw/` を合わせる (合うまで `tests/test_sample_sgw.sh`
が失敗する)。base はバイナリをゲートウェイイメージから取り込むため、どの手順も省略できない。
ビルドには `ghcr.io` と `pkg-containers.githubusercontent.com` への接続が必要である。

## ローカルビルド

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t sgw-devcontainer-base:dev \
  .
```

ローカルでテストするための単一プラットフォームのビルド:

```sh
docker build -t sgw-devcontainer-base:dev .
docker run --rm -it sgw-devcontainer-base:dev zsh
# ローカルでビルドした sekimore-gw イメージから関所を取り込む場合
docker build -t sgw-devcontainer-base:dev --build-arg SEKIMORE_GW_IMAGE=sekimore-gw:relay-dev .
```

## ライセンス

MIT
