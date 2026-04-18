# sgw-sample

`sgw-devcontainer-base` を使った最小構成の devcontainer サンプル。

- `sekimore-gw` を経由するネットワーク分離構成
- base image を `FROM` するだけの薄い `Dockerfile`
- 特定バージョンの Python / Node.js / PHP を `phpenv` 等でインストールする例

## 使い方

1. このディレクトリを VS Code で開いて "Reopen in Container"
2. `.devcontainer/.env.sample` を `.devcontainer/.env` にコピーして値を埋める

新しいプロジェクトに使う場合は `.devcontainer/` ごとコピーする。

## ファイル構成

```
sgw-sample/
├── README.md
└── .devcontainer/
    ├── devcontainer.json
    ├── docker-compose.yml          # dev + sekimore-gw の 2 サービス
    ├── Dockerfile                  # FROM sgw-devcontainer-base + 特定バージョン install
    ├── .env.sample
    ├── .gitignore
    ├── config/
    │   ├── config.yml              # sekimore-gw 許可ドメインリスト
    │   └── squid/
    │       └── squid.conf.template
    ├── scripts/
    │   └── post-create.sh          # zsh rc.d の展開など
    └── zsh-config/
        └── rc.d/                   # プロジェクト固有 zsh 設定
```
