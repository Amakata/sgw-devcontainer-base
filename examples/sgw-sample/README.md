# sgw-sample

`sgw-devcontainer-base` を使った最小構成の devcontainer サンプル。

- `sekimore-gw` を経由するネットワーク分離構成
- `sekimore-relay` (git / GitHub API 中継関所) を使う構成 (`docker-compose.relay.yml`)。
  AI は `git@github.com:Org/Repo.git` をそのまま使えるが、鍵は使い捨て・上流の認証は
  gateway 内の依頼者の ssh-agent で行う。案件外リポジトリや許可外の操作は関所が拒否する
- base image を `FROM` するだけの薄い `Dockerfile`
- 特定バージョンの Python / Node.js / Ruby / Rust を `mise` でインストールする例
  (PHP は Dockerfile でコメントアウトしてあり、必要に応じて有効化可能)

## 使い方

ホスト (Mac + Docker Desktop) 側の操作は `mise.toml` の task にまとめてある (`mise tasks` で一覧)。

1. `.devcontainer/.env.sample` を `.devcontainer/.env` にコピーして値を埋める
   (`SEKIMORE_AGENT_SOCK` は依頼者の ssh-agent socket。Docker Desktop なら既定値のままでよい)
2. `config/config.yml` の `relay.project.repos` / `permissions` をこのプロジェクトのものに書き換える
3. Docker Desktop を (ssh-agent が使える状態で) 起動してから、**`mise run vscode`** で VS Code を開き "Reopen in Container"。
   `SSH_AUTH_SOCK` を渡さずに VS Code を起動するのは、Dev Containers 拡張が依頼者の ssh-agent を無条件に dev へ
   転送するため (無効化設定なし)。普通に開くと post-create が **ERROR で止まり**、この手順を案内する
4. gateway 側の初回だけ **`mise run gw:login`** (device flow。上流トークンと known_hosts を保存)
5. **`mise run dev:signing-key`** で表示される署名用公開鍵を GitHub の Settings → SSH and GPG keys に
   "Signing Key" として登録する (AI のコミットが依頼者の鍵ではなくこの鍵で署名される)
6. **`mise run relay:verify`** で一式を確認する (gateway の状態、dev に agent が届いていないこと、関所経由の git、案件外の拒否)

日常: `mise run gw:check` (状態) / `mise run gw:tokens` / `mise run gw:audit` (監査ログ) / `mise run gw:revoke-project` (案件終了) /
`mise run gw -- <sekimore-relay の任意のサブコマンド>`。

relay を使わない場合は `devcontainer.json` の `dockerComposeFile` から `docker-compose.relay.yml` を外し、
`config/config.yml` の `domain_handlers:` / `relay:` を消す (`mise.toml` の gw:* / relay:* も不要になる)。

新しいプロジェクトに使う場合は `.devcontainer/` と `mise.toml` をコピーする。

## ファイル構成

```
sgw-sample/
├── README.md
├── mise.toml                       # ホスト側の操作 (vscode / gw:login / gw:check / relay:verify …)
└── .devcontainer/
    ├── devcontainer.json
    ├── docker-compose.yml          # dev + sekimore-gw の 2 サービス
    ├── docker-compose.relay.yml    # sekimore-relay 用 overlay (agent socket のマウント、鍵 volume)
    ├── Dockerfile                  # FROM sgw-devcontainer-base + mise で特定バージョン install
    ├── .env.sample
    ├── .gitignore
    ├── config/
    │   ├── config.yml              # sekimore-gw 許可ドメインリスト + relay の案件ポリシー
    │   └── squid/
    │       └── squid.conf.template
    ├── scripts/
    │   ├── post-create.sh          # zsh rc.d の展開、agent 転送の検知 (ERROR で止める)
    │   └── sgw.sh                  # mise task が使う: compose ラベルで gateway / dev コンテナを見つけて docker exec
    └── zsh-config/
        └── rc.d/                   # プロジェクト固有 zsh 設定
```
