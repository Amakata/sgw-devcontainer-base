<!-- reviewed-up-to: 0.2.28 -->
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
| 0.2.19 〜 0.2.21 | [0.2.22](#0222-proxy-の認証情報がストアに移った) — **上流 proxy にパスワードが要る場合だけ** |
| 0.2.22 〜 0.2.26 | [0.2.27](#0227-タグは署名が必須になった) — **エージェントにタグを push させている場合だけ** |
| 0.2.27 | [0.2.28](#0228-dependabot-アラートは任意) — **エージェントに Dependabot アラートを読ませたい場合だけ** |

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

## 0.2.20 タスクが gateway から来るようになった

**任意。ただし一度やる価値がある。** イメージが `gw:*` タスクを持つようになったので、
プロジェクト側で複製を抱える必要がなくなりました:

雛形 (`examples/sgw-sample/`) はこの形になっているので、新規はそのまま始まります。
既存のプロジェクトは `gw:sync-tasks` を足してから一度走らせます:

```toml
# mise.toml — これだけは自分で持つ。イメージから配れない (取り出す側なので)
[tasks."gw:sync-tasks"]
description = "動いているゲートウェイから gw:* タスクを取り出す (gw:recreate のあとに実行する)"
run = "bash \"$SGW\" gw cat /usr/local/share/sekimore/gateway.mise.ja.toml > \"$MISE_PROJECT_ROOT/.devcontainer/gateway.mise.toml\" && echo wrote"
```

```bash
mise run gw:sync-tasks      # .en.toml でもよい。違うのは `mise tasks` の表示だけ
```

```toml
# mise.toml — gw:* のタスクは消して、自分のタスクだけ残す
[task_config]
includes = [".devcontainer/gateway.mise.toml"]

[env]
SGW = "{{config_root}}/.devcontainer/scripts/sgw.sh"
```

`mise run gw:recreate` のたびに取り直せば、タスクは常に動いている gateway のものになります。
上の 0.2.15 と 0.2.19 が罠になっていた原因は、これで消えます。

`sgw.sh` は引き続きあなたのもので、`gw-tty` が要ります。同梱ファイルの冒頭に、
どの原始的な口を使うか4つ書いてあります。

**取り出したファイルはコミットしてください。** `mise` は include 先が無くても
**エラーも警告も出さず黙って無視します**。gitignore すると、clone した人の環境で
`gw:*` が「静かに存在しない」状態になります。コミットしておけば、ゲートウェイを
更新したときの差分が `git diff` に出るという利点もあります。

## 0.2.22 proxy の認証情報がストアに移った

**パスワードを求める社内 proxy の背後にある gateway だけ。** それ以外はやることなし。

`config.yml` の `upstream_proxy_username` / `upstream_proxy_password` と、
環境変数 `SEKIMORE_UPSTREAM_PROXY_*` は dev コンテナから読めます。`config.yml` は
worktree の中にあり、`.devcontainer/.env` はエージェント自身の `env_file` だからです。
認証情報の置き場所はシークレットストアです:

```bash
mise run gw:proxy-credential -- set     # ユーザー名とパスワードは端末で聞かれる
```

そのあと `config.yml` から2つのキーを、置いていた場所から2つの環境変数を消して、
`mise run gw:recreate`。残しておいても**引き続き読まれる**ので破壊的変更ではありません。
穴を閉じるのは消すほうです。

ストアが起動時に封じられていることから、2つ従うことがあります:

- `mise run gw:unlock` までは Squid は上流認証**なし**で動き、ストアが開くと自分で
  認証情報を拾います。匿名を拒む proxy の背後でも gateway は起動します。unlock より前に
  proxy を通るものが無いからです
- `gw:proxy-credential` は gateway のタスクです。`mise run gw:sync-tasks` のあと
  include（[0.2.20](#0220-タスクが-gateway-から来るようになった)）経由で届きます

0.2.21 と 0.2.23 〜 0.2.26 は何も求めません。

## 0.2.27 タグは署名が必須になった

**`tags:` の glob でエージェントにタグの push を許している案件だけ。** それ以外はやることなし。

push されるタグは、署名を持つ注釈付き tag オブジェクトでなければ通りません。`git tag -s`
で、形式は git が知るどれでも（OpenPGP / SSH / X.509）。軽量タグ（`git tag v1`）と署名なしの
注釈付きタグ（`git tag -a`）は `[remote rejected]` と理由付きで拒否されます。relay が見るのは
署名が**ある**ことだけで、誰の署名かは見ません。

dev コンテナ側はもう署名しています。`agent-setup.sh` がエージェントの SSH 署名鍵で
`tag.gpgsign true` を入れるので、そこでは `git tag -s` も素の `git tag -a` も署名付きになります。
捕まえるのはそれを**回り込んだ**タグ — `-c tag.gpgsign=false` や、設定の無いシェルから打った
もの — で、gateway 自身の最初の `v0.2.18` はそうして上がりました。

この検査を外したければ、どの層でも 1 行です:

```yaml
# .devcontainer/config/config.yml
relay:
  project:
    signed_tags: false          # upstreams.<domain> の下でも、repos[] の 1 件にでも書ける
```

そのあと `mise run gw:recreate`。`mise run gw:check` が repo ごとの実効値
（`signed_tags=true|false`）を出します。

0.2.23 〜 0.2.26 は何も求めません。

## 0.2.28 Dependabot アラートは任意

**使いたいときだけ。** 権限キーが 2 つ増えました。`security:read`（リポジトリの Dependabot
アラートの一覧・詳細）と `security:dismiss`（理由を付けて脇に置く・戻す）。どちらも既存の
設定では付きません。

使うなら:

```yaml
# .devcontainer/config/config.yml
relay:
  project:
    permissions:
      - security:read
      # - security:dismiss      # 脆弱性を見えなくするのは別の権限。意図して付ける
```

そのあと `mise run gw:recreate`、**さらに `mise run gw:login` をもう一度**。alerts API には
`security_events` の OAuth scope が要り、0.2.28 より前の login は要求していません。無いと
`sekimore security alerts` は GitHub の 403 を受けます。
