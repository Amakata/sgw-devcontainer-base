# sgw-devcontainer-base

*[English](README.md)*

[sekimore-gw](https://github.com/Amakata/sekimore-gw) (略して sgw) の dev コンテナ側である。
単体では使わない。この構成がなぜ必要かは sekimore-gw の README で説明している。

配布先: `ghcr.io/amakata/sgw-devcontainer-base`
対応プラットフォーム: `linux/amd64`, `linux/arm64`

## プロジェクトを始める

プロジェクトは [`examples/sgw-sample/`](examples/sgw-sample/) (ゲートウェイと dev のコンテナ、ホスト側の mise タスク)
の複製から始める。次の手順をホストで順に実行する。各手順の詳細は [`examples/sgw-sample/README.ja.md`](examples/sgw-sample/README.ja.md) に書いてある。

1. このリポジトリを複製する: `git clone https://github.com/Amakata/sgw-devcontainer-base.git`。
2. `examples/sgw-sample/.devcontainer/` と `examples/sgw-sample/mise.toml` をプロジェクトにコピーする。
3. `.devcontainer/.env.sample` を `.devcontainer/.env` にコピーし、プロジェクト名、ユーザー名、メールアドレスを埋める。
4. `.devcontainer/config/config.yml` の `relay.project.repos` と `permissions` を設定する。このファイルにはゲートウェイが読むキーがすべて載っており、影響の大きい権限はコメントアウトしてある。
5. VS Code を完全に終了し、`mise run vscode` を実行して「Reopen in Container」を選ぶ。このタスクは `SSH_AUTH_SOCK` なしで VS Code を開くので、運用者の ssh-agent は dev コンテナに届かない。
6. `mise run gw:unlock` で秘密ストアを解錠する。初回の実行でパスフレーズを設定する。ゲートウェイを作り直すたびに解錠し直す必要がある。これを省くには `mise run gw:keychain-set` を一度実行する。パスフレーズがホスト (macOS のキーチェーン、Secret Service、root 所有のファイルのいずれか) に保存され、以後は `gw:recreate` がストアを自動で解錠する。
7. `mise run gw:login` を実行する (初回だけ)。デバイスフローで GitHub にログインし、上流のトークンと `known_hosts` を保存する。解錠済みのストアが必要である。
8. `mise run dev:signing-key` が表示する公開鍵を、GitHub に Signing Key として登録する。エージェントのコミットはこの鍵で署名される。
9. `mise run relay:verify` を実行する。構成全体を確認し、これが通れば設定は完了である。

## プロジェクトの Dockerfile

プロジェクトの `.devcontainer/Dockerfile` に必要なのは次の内容だけである。

```dockerfile
# latest ではなく版を書く。`mise run upgrade` がこれを読んで上げる
FROM ghcr.io/amakata/sgw-devcontainer-base:0.2.34

# プロジェクト固有の追加だけを書く
# 例: mise use -g python@3.13.0 && mise reshim
```

言語のバージョンをプリインストールし、mise のデータディレクトリに volume をマウントしても残す方法は、
サンプルの [Dockerfile](examples/sgw-sample/.devcontainer/Dockerfile) に示してある。

## イメージの内容

| | |
|---|---|
| ベース | `mcr.microsoft.com/devcontainers/base:bookworm` (`vscode` ユーザー、uid=1000) |
| シェル | zsh、oh-my-zsh とプラグイン、`fzf`, `jq`, `vim`, `nano`, `curl`, `wget`, `unzip`, `rsync`, `pv`, `gnupg`, `sudo` |
| ネットワーク | `iptables`, `iproute2`, `iputils-ping`, `dnsutils` |
| Git | `git-delta` |
| DB ヘッダ | `libpq-dev`, `default-libmysqlclient-dev` |
| 言語 | `mise`。Python、Node.js、Ruby、PHP、Rust、Go を管理する。言語のバージョンは含まない |
| AI | Claude Code CLI、OpenAI Codex CLI |
| クラウド | AWS CLI v2、Docker CE (buildx と compose を含む) |
| ゲートウェイ | `sekimore-agent-setup.sh`、`sekimore-relay` CLI、`sekimore` ラッパー |
| zsh の既定設定 | `/etc/skel/zsh-rc.d/`: XDG 設定、mise の activate、エイリアス、プラグイン。post-create が `~/.config/zsh/rc.d/` に複製する |

`sekimore-agent-setup.sh` と関所（sekimore-relay）の CLI `sekimore-relay` は同じ sekimore-gw イメージから取り込むので、
両者の版はずれない。このイメージにプロジェクト固有のものは含まれない。言語のビルド依存、設定、Docker デーモンに必要な権限は
サンプルと同様にプロジェクト側で用意する。

## 所有と最新への追従

サンプルから複製したものはすべてプロジェクトのものになるが、`.devcontainer/sgw/` だけは例外である。
ここにはホスト側のスクリプトとタスクが入っており、`mise run upgrade:apply` が入れ替える。手で編集しない。
配布タスクを変えるには、プロジェクトの `mise.toml` に同じ名前のタスクを定義する。そちらが優先される。
`.devcontainer/sgw/gateway.mise.toml` には `gw:*` タスクが入っている。ゲートウェイイメージが英語版と日本語版を
同梱しており、`mise run upgrade:sync` が現在の言語 (`SEKIMORE_LANG`、次に `LC_ALL`、`LC_MESSAGES`、`LANG`) のものを取得する。
保存したパスフレーズで `gw:recreate` がストアを解錠しないようにするには、`SGW_NO_AUTO_UNLOCK=1` を設定する。

```bash
mise run upgrade          # 何が新しいか、どのファイルが変わるか、UPGRADING が何を求めるか。何も変更しない
mise run upgrade:apply    # 更新する
```

`upgrade:apply` は、ゲートウェイの `image:` タグと `FROM` タグを GHCR の最新の版に上げ、`.devcontainer/sgw/` を入れ替え、
確認を求めたうえでゲートウェイを作り直し、パスフレーズが保存されていれば解錠する。最後に、運用者にしかできない作業を表示する。
base が変わった場合の Rebuild Container、更新でまたぐ [UPGRADING.ja.md](UPGRADING.ja.md) の節、コミットである。
`.devcontainer/sgw/` のファイルが手で書き換えられている場合は、何も書き込まずに止まる。

3 つの部分は互いに依存している。1 つのコマンドですべてを更新するのはそのためである。

```
sekimore-gw (ゲートウェイ)  ── このイメージが関所のバイナリを取り込む
        ↓
sgw-devcontainer-base  ── あなたの .devcontainer/Dockerfile が FROM する
        ↓
.devcontainer/sgw/     ── 両方に合わせたホスト側のスクリプトとタスク
```

sgw-devcontainer-base と sekimore-gw は別々の 0.2.x 系列で、互いに独立して版が進む。このイメージに入る
関所の CLI と agent-setup は、Dockerfile の `ARG SEKIMORE_GW_IMAGE` が指定するゲートウェイイメージ、
現在は `ghcr.io/amakata/sekimore-gw:0.2.36` から取り込む。プロジェクトが動かすゲートウェイは compose ファイルの
`image:` タグで決まり、タグを上げて `mise run gw:recreate` を実行すれば、このイメージの新しいリリースを待たずに反映できる。
現在は 2 つの版が揃っている (このイメージもゲートウェイも 0.2.36)。

## タグ

GitHub Actions (`.github/workflows/build-and-push.yml`) が次のタグを GHCR に push する。

| トリガー | タグ |
| --- | --- |
| `main` への push | `main`, `latest`, `sha-<short>` |
| `v1.2.3` タグの push | `1.2.3`, `1.2`, `1`, `sha-<short>` |
| プルリクエスト | (ビルドのみ。push しない) |

## リンク

- [UPGRADING.ja.md](UPGRADING.ja.md) — 各リリースがプロジェクトに求める変更。ゲートウェイ 0.0.x からの移行と、
  base 0.2.20 より前に作ったプロジェクトの `.devcontainer/sgw/` への一度きりの移行を含む
- [CHANGELOG.ja.md](CHANGELOG.ja.md) — このイメージの変更履歴。各リリースが使ったゲートウェイの版も記録している。
  [ゲートウェイの CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.ja.md)、
  [関所の CHANGELOG](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.ja.md)
- [RELEASING.md](RELEASING.md) — リリースの順序とローカルビルド (保守者向け、英語)
- ライセンス: MIT ([LICENSE](LICENSE))
