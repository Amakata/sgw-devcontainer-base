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

1. このディレクトリを VS Code で開いて "Reopen in Container"
2. `.devcontainer/.env.sample` を `.devcontainer/.env` にコピーして値を埋める
   (`SEKIMORE_AGENT_SOCK` は依頼者の ssh-agent socket。Docker Desktop なら既定値のままでよい)
3. `config/config.yml` の `relay.project.repos` / `permissions` をこのプロジェクトのものに書き換える
4. 起動後、post-create の出力に **"an ssh-agent ... is reachable inside the dev container"** の警告が出たら、
   Dev Containers の暗黙の agent 転送が生きている。Remote-SSH の `remote.SSH.enableAgentForwarding` を
   false にして "Kill VS Code Server on Host" → 再接続で止める (dev 内で `ssh-add -l` が失敗すれば OK)
5. agent-setup の出力に表示される **署名用公開鍵** を GitHub の Settings → SSH and GPG keys に
   "Signing Key" として登録する (AI のコミットが依頼者の鍵ではなくこの鍵で署名される)
6. gateway 側の初回だけ `docker compose exec sekimore-gw sekimore-relay login` (device flow) を実行する

relay を使わない場合は `devcontainer.json` の `dockerComposeFile` から `docker-compose.relay.yml` を外し、
`config/config.yml` の `domain_handlers:` / `relay:` を消す。

新しいプロジェクトに使う場合は `.devcontainer/` ごとコピーする。

## ファイル構成

```
sgw-sample/
├── README.md
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
    │   └── post-create.sh          # zsh rc.d の展開など
    └── zsh-config/
        └── rc.d/                   # プロジェクト固有 zsh 設定
```
