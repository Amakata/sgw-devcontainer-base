# 更新のしかた (版ごとに必要な作業)

*[English](UPGRADING.md)*

**ここに載っているのは、あなたが持っているファイルを触る必要がある版だけです。**
載っていない版は、イメージのタグを上げて `mise run gw:recreate` するだけで済みます。
何が変わったかは changelog にあります —
[gateway](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.ja.md) /
[relay](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.ja.md) /
[base](CHANGELOG.ja.md)。

「あなたが持っているファイル」とは、雛形から複製したもののことです。

| ファイル | 誰のものか |
|---|---|
| `.devcontainer/config/config.yml` | あなた。関所の設定はここ |
| `mise.toml` | あなた。ホスト側の操作 |
| `.devcontainer/scripts/sgw.sh` | あなた。コンテナを見つけて exec する土台 |
| `.devcontainer/docker-compose.yml` | あなた。gateway の image タグはここ |

## いまの版から読む場所

| いまの gateway | 読む項目 |
|---|---|
| 0.0.x | [0.1.0](#010-関所-relay-が入った) から順に全部。ただし関所を使わないなら**何も要りません** |
| 0.1.0 〜 0.1.8 | [0.1.9](#019-権限の書き方が変わった) 以降 |
| 0.1.9 〜 0.2.6 | [0.2.7](#027-projects-のボードを宣言する-破壊的) 以降 |
| 0.2.7 〜 0.2.14 | [0.2.15](#0215-秘密ストアが増えた) 以降 |
| 0.2.15 〜 0.2.18 | [0.2.19](#0219-解錠が必須になった) |

---

## 0.1.0 関所 (relay) が入った

**opt-in です。** `config.yml` に `domain_handlers` と `relay` を書かなければ関所は起動せず、
0.0.x と同じ DNS フィルタ・ファイアウォール・Squid のままです。設定キーの削除も改名も
ありません (`allow_domains` / `block_domains` / `allow_ips` / `block_ips` / `proxy` /
`network` / `database_path` はそのまま通ります)。

関所を使うなら、README の
[「0.0.8 以前の gateway から上げる場合」](README.md#008-以前の-gateway-から上げる場合) を参照。

## 0.1.9 権限の書き方が変わった

`relay.allow_tags` / `relay.allow_delete` が非推奨になりました。**まだ読まれます** —
起動時に警告を出しつつ `relay.project` の既定に畳まれるので、放っておいても動きます。
移すなら:

```yaml
relay:
  project:
    tags: ["*"]        # 旧 relay.allow_tags: true
    delete: true       # 旧 relay.allow_delete: true
```

## 0.2.7 Projects のボードを宣言する (破壊的)

**Projects v2 を使っているなら作業が要ります。** 触ってよいボードを宣言しないと、
Projects の操作が**全て拒否**されます。ボードの node id は不透明で所有者を示さないため、
宣言が無いと上流トークンから見える任意のボードに届いてしまうからです。

```yaml
relay:
  project:
    boards:
      - { org: acme, number: 3 }       # github.com/orgs/acme/projects/3
      - { user: someone, number: 1 }   # github.com/users/someone/projects/1
```

Projects を使っていなければ何も要りません。

同じ版で `handler: git-relay` が `handler: github` に改名されましたが、
**別名として残っている**ので書き換えは不要です。

## 0.2.13 設定の反映に窓ができた

既定は `auto` で、それまでと同じ挙動です。ただし `config.yml` は dev から書けるので、
**AI に作業を渡すなら閉じておくべきです。**

```yaml
reload: manual        # または 30m のような時間
```

```bash
mise run gw:reload-freeze    # いま閉じる
mise run gw:reload-status    # いまどちらか
```

`mise.toml` に `gw:reload-*` の3タスクが要ります（雛形にあります）。

## 0.2.15 秘密ストアが増えた

`mise.toml` に解錠のタスクが要ります。`sgw.sh` には **`gw-tty`** が要ります —
パスフレーズのプロンプトに端末を渡す経路で、通常の `gw` は stdout も端末でないと
`-t` を付けないため、mise 経由だと端末が無くなります。

雛形から取り込んでください:

```bash
diff -u <base>/examples/sgw-sample/mise.toml mise.toml
diff -u <base>/examples/sgw-sample/.devcontainer/scripts/sgw.sh .devcontainer/scripts/sgw.sh
```

必要なタスク: `gw:unlock` `gw:lock` `gw:store-status` `gw:passphrase`

## 0.2.18 ストアの控えが取れるようになった

`gw:store-export` / `gw:store-import` を `mise.toml` に。施錠中でも控えを取れます
(鍵が要らないため)。封じてありますが、**守っているのはパスフレーズだけ**です。

## 0.2.19 解錠が必須になった

**上流 API トークンが秘密ストアに入りました。解錠しないと関所が GitHub API を使えません。**
git の push / pull は SSH なので影響しません。

- ゲートウェイを作り直したら、再起動したら、**毎回 `mise run gw:unlock`**。鍵はメモリにしかありません
- `whoami` / `check` / `logout` は関所が動いていないと使えません (制御ソケット経由になったため)
- 既存の `/data/relay/upstream_token` は最初の読み取りでストアへ移って消えます。**手作業は不要です**

0.2.15 の作業を飛ばしていると、ここで詰みます (`gw:unlock` が無く、足しても `gw-tty` が無い)。
先に 0.2.15 の項を済ませてください。

同じ版で、上流が既に広告しているタグを動かす push が拒否されるようになりました。
**新しいタグを切るのは今までどおり**なので、リリース手順は変わりません。
