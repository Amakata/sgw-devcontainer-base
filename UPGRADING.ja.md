<!-- reviewed-up-to: 0.2.31 -->
# 更新のしかた (版ごとに必要な作業)

*[English](UPGRADING.md)*

**ここに載っているのは、あなたが持っているファイルを触る必要がある版だけです。**
載っていない版は、`mise run upgrade:apply` だけで済みます (base 0.2.20 より前は、イメージの
タグを上げて `mise run gw:recreate`)。
何が変わったかは changelog にあります —
[gateway](https://github.com/Amakata/sekimore-gw/blob/main/CHANGELOG.ja.md) /
[relay](https://github.com/Amakata/sekimore-gw/blob/main/relay/CHANGELOG.ja.md) /
[base](CHANGELOG.ja.md)。

「あなたが持っているファイル」とは、雛形から複製したもののことです。

| ファイル | 誰のものか |
|---|---|
| `.devcontainer/config/config.yml` | あなた。関所の設定はここ |
| `mise.toml` | あなた。ホスト側のタスクを include し、自分のタスクを置く |
| `.devcontainer/docker-compose.yml` | あなた。gateway の image タグはここ (`upgrade:apply` が書き換えるのはタグだけ) |
| `.devcontainer/sgw/` | base 0.2.20 から**あなたのものではない**。`upgrade:apply` が入れ替える。それより前は `.devcontainer/scripts/sgw.sh` があなたのものだった |

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
| 0.2.28 | [0.2.29](#0229-解錠を自動化できるようになった) — **解錠を自動化したい場合か、AI のコミットを Verified のままにしたい場合だけ** |

gateway とは別に、base 0.2.20 より前のプロジェクトは一度だけ手で `.devcontainer/sgw/` に移します —
[base 0.2.20](#base-0220-devcontainersgw-と-mise-run-upgrade)。以後は、ここの節をまたぐたびに
`mise run upgrade` が一覧に出します。

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

## 0.2.29 解錠を自動化できるようになった

**使いたくなければ何も要りません。** `mise run gw:unlock` は変わらず、何も保存していない
ホストの挙動もこれまでどおりです。

`mise run gw:sync-tasks` で新しいタスクを取り出し、ホストごとに一度だけ:

```bash
mise run gw:keychain-set     # パスフレーズを尋ね、このホストの keychain に入れる
```

以後は `mise run gw:recreate` が自分で解錠します。`docker restart` のあとなら
`mise run gw:unlock-auto` 単体でも解錠できます。

探す順番は次のとおりです。`<project>` は `MISE_PROJECT_ROOT` の指すディレクトリ名なので、
1 台のホストに 2 案件あっても別々の項目になります。

| | 置き場 | 機械に縛るもの |
|---|---|---|
| macOS | Keychain。service `sekimore-gw`、account `<project>` | ログイン。ログインするまで開かない |
| Linux デスクトップ | Secret Service (`secret-tool`)。`service=sekimore-gw project=<project>` | ログインセッション |
| サーバ | `/etc/sekimore/<project>.passphrase.cred` を `systemd-creds decrypt` で読む | TPM かホスト鍵。ディスクを複製しても持ち出せない |
| サーバ・最後の手段 | `/etc/sekimore/<project>.passphrase`（root 所有 0600） | **何も無い。** ファイルを読めた者がパスフレーズを持つ |

keychain の無いホストでは `gw:keychain-set` がサーバ向け 2 通りの手順をそのまま表示します。
`/etc/sekimore` 自体は 0755 のままにしてください。タスクはファイルが見えてから初めて
`sudo -n` を使い、sudo のパスワードは決して尋ねません（`gw:recreate` が止まってしまうため）。

ここでいう `/etc/sekimore` は**ホスト側**のものです。ゲートウェイの中にも同名のディレクトリが
あります（`config.yml` の置き場）が、ホスト側をそこに mount すると、この設計が
ゲートウェイから遠ざけているはずのパスフレーズを渡してしまいます。

変わらないことが 2 つあります。

- **ゲートウェイは何も知りません。** パスフレーズはホストが読み、
  `sekimore-relay unlock --stdin` に流し込みます。届く経路は今までどおり control socket で、
  dev コンテナはそれを mount していませんし、ゲートウェイの中から取りに行く手段もありません。
  export を守るのが相変わらずパスフレーズ 1 つだけである点も同じです。
- **最初のパスフレーズは手で打ちます。** 未初期化のストアに対して `unlock --stdin` は拒否します。
  最初の 1 つは思い出すものではなく決めるもので、確認のため 2 回尋ねるからです。

解錠させたくないときは:

```bash
SGW_NO_AUTO_UNLOCK=1 mise run gw:recreate
```

ファイルの置き場を `/etc/sekimore` 以外にするなら `SGW_PASSPHRASE_DIR` です。

## 0.2.29 署名鍵を人につき 1 本にする

**任意です。何もしなければ今までどおり**、dev コンテナが自分で署名鍵を生成します。

その鍵は使い捨てですが、署名鍵は使い捨てにできません。GitHub には人が手で登録し、
消すとその鍵が署名した全てのコミットから Verified が外れます。つまり鍵の volume を
消すと「作り直し」ではなく喪失で、以後のコミットは GitHub が知らない鍵で署名されます。
そうと分かる手段もありませんでした。`commit.gpgsign` は無条件に true で、
鍵が登録されているかを確かめる仕組みはどこにも無かったからです。

置き換える手順 — 人につき 1 本、登録は一度だけ:

1. 手元で鍵を作る（無ければ）。**自分自身の署名鍵とは別にします**。
   分けておくことが、履歴の中で AI のコミットを見分けられる根拠になります。

   ```bash
   ssh-keygen -t ed25519 -C "sekimore AI signing key" -f ~/.ssh/sekimore_signing
   ssh-add ~/.ssh/sekimore_signing          # Mac なら --apple-use-keychain
   ssh-keygen -lf ~/.ssh/sekimore_signing.pub   # SHA256:… の fingerprint
   ```

2. **公開鍵**を GitHub に一度だけ登録する。Settings → SSH and GPG keys →
   New SSH key → Key type: **Signing Key**。

3. fingerprint を `.devcontainer/config/config.yml` に書く:

   ```yaml
   relay:
     signing_key:
       fingerprint: "SHA256:…"     # 手順 1 のもの
   ```

   自分の他の鍵は同じ agent に入れたままで構いません。relay が dev に渡すのは
   この fingerprint 1 本だけに答え、git 署名以外を一切通さない**絞り込んだ**
   socket です。他の鍵は見えず、この socket では認証もできません。

4. socket の volume を `.devcontainer/docker-compose.relay.yml` の**両方の**
   サービスに足す（雛形には入っています）:

   ```yaml
   services:
     sekimore-gw:
       volumes:
         - sekimore-signing:/run/sekimore
     dev:
       volumes:
         - sekimore-signing:/run/sekimore

   volumes:
     sekimore-signing:
       name: sekimore-signing-${DEVCONTAINER_ID}
   ```

5. `mise run gw:recreate` のあと Rebuild Container。効いたか確認する:

   ```bash
   mise run gw:check     # 「署名鍵: ホストの agent にある」
   ```

   dev の中では `ssh-add -l` が**ちょうど 1 本**を出すようになります（絞り込んだ
   socket 越しの署名鍵）。`mise.toml` の `relay:verify` が「`ssh-add -l` が成功したら
   FAIL」のままなら、その部分を差し替えてください:

   ```bash
   echo "== dev: only the gateway's filtered signing key may be reachable"
   n=$(bash "$SGW" dev ssh-add -l 2>/dev/null | grep -c . || true)
   if [ "$n" = 1 ]; then
     echo "OK: exactly one key (the signing key, via the gateway's filtered agent)"
   elif [ "$n" = 0 ]; then
     echo "OK: no ssh-agent in dev"
   else
     echo "❌ FAIL: ssh-add -l lists $n keys inside dev — the operator's keys are exposed to the AI. Reopen with: mise run vscode"
     fail=1
   fi
   ```

古い `~/.ssh/sekimore/signing_ed25519` は消しません。履歴に残っているコミットを
署名した鍵であり、それらの Verified を保つには公開鍵を GitHub に登録したままに
しておく必要があります。

**`signing: required`** は別の話で、これも任意です。branch への push に署名の無い
コミットが含まれていたら関所が拒否します。今回の件を 20 コミット早く見つけられた
はずの検査です。既定は `optional` なので、既存の案件の挙動は変わりません。

```yaml
relay:
  project:
    signing: required     # 上流層や repos[] でも指定できる
```

有効にするのは手順 5 が通ってからにしてください。鍵が無い状態で有効にすると、
全ての push が拒否されます。

`required` は**上流 API も使います**。push の履歴が pack から出た地点で、そのコミットを
上流が既に持っているかを問い合わせるためです（そうしないと、delta に隠れたコミットと
上流の履歴が pack の中から区別できません）。解錠（`mise run gw:unlock`）と login が
できていないと push は拒否されます。拒否のメッセージがどちらかを言います。

## base 0.2.19 `mise run web` が自分でポートを引く

**base 0.2.20 に上げるなら飛ばしてください** — [その節](#base-0220-devcontainersgw-と-mise-run-upgrade)で
両方のファイルがまるごと入れ替わります。

**任意。** 飛ばしても壊れません。壊れるのは Web UI の公開ポートをずらしたときで、
古い `web` task はそこで違う場所を開きます。

task にポートが直書きされていた一方、実際に決めているのは compose です。8090 が
既に埋まっているプロジェクトは公開ポートをずらしますが、task は古い数字を開き続け、
`mise run web` は何も無い場所に行き着きます。他のプロジェクトの gateway に当たると、
そちらのほうが厄介です。

これは gateway の版に紐づきません。サンプル自身のファイルの話で、gateway は変わって
いません。

サンプルから両方を取ってください。`sgw.sh` に `port` の枝が増え、`mise.toml` の
`web` task がそれを呼びます。

```bash
diff -u <base>/examples/sgw-sample/.devcontainer/scripts/sgw.sh .devcontainer/scripts/sgw.sh
diff -u <base>/examples/sgw-sample/mise.toml mise.toml
```

以後 `mise run web` は開く URL を表示します。ポートが違っていれば黙って外れるのでは
なく、目に見えます。

## base 0.2.20 `.devcontainer/sgw/` と `mise run upgrade`

**一度だけ手で移します。以後の更新は `mise run upgrade:apply` です。**

ホスト側のスクリプトとタスクは `.devcontainer/sgw/` に移り、あなたのものではなくなります。
`mise run upgrade:apply` がまるごと入れ替え、中のファイルが手で書き換えられていれば、
上書きせずに止まります。`mise.toml` には include と自分のタスクだけが残ります。

1. `FROM` が `latest` なら、base を版で固定します。`upgrade` は 2 つのタグを読むので、
   `latest` は上げられません:

   ```dockerfile
   FROM ghcr.io/amakata/sgw-devcontainer-base:0.2.20
   ```

2. `upgrade.sh` を置き、残りを埋めさせます:

   ```bash
   mkdir -p .devcontainer/sgw
   curl -fsSL -o .devcontainer/sgw/upgrade.sh \
     https://raw.githubusercontent.com/Amakata/sgw-devcontainer-base/v0.2.20/share/sgw/upgrade.sh
   bash .devcontainer/sgw/upgrade.sh --sync
   ```

   `mise.toml` に何を書くか、どの古いファイルが使われなくなったかを表示します。

3. `mise.toml` をあなただけのものにします。**配布されるようになったタスクは消してください** —
   `vscode`、`vscode:check`、`vscode:restore-agent-env`、`web`、`ps`、`down`、`dev:*`、
   `relay:verify`、`gw:sync-tasks`。`mise.toml` に残したタスクは同じ名前の配布タスクより
   優先されるので、古い複製が残っていると、そのタスクへの以後の修正がすべて隠れます。
   自分のタスクは残します:

   ```toml
   [task_config]
   includes = [".devcontainer/sgw/tasks.mise.toml", ".devcontainer/sgw/gateway.mise.toml"]

   [env]
   SGW = "{{config_root}}/.devcontainer/sgw/sgw.sh"
   ```

4. 古い配置を消します:

   ```bash
   git rm .devcontainer/scripts/sgw.sh .devcontainer/scripts/vscode.sh .devcontainer/gateway.mise.toml
   ```

5. `mise run upgrade` が版を並べ、すべて最新と表示すれば完了です。

`gw:sync-tasks` は無くなりました。`mise run upgrade:sync` が gateway のタスクも含めて取り直します。
タスクの説明とスクリプトの表示は `LC_ALL` / `LC_MESSAGES` / `LANG` に従います。固定するなら
`[env]` に `SEKIMORE_LANG = "ja"` (または `"en"`) を書き、`mise run upgrade:sync` を実行します。

## base 0.2.22 `postStartCommand` が `.devcontainer/sgw/post-start.sh` を実行する

**`devcontainer.json` を 1 行、一度だけ書き換えます。** 済むまで `mise run upgrade` が案内します。

```json
"postStartCommand": "sh /workspace/.devcontainer/sgw/post-start.sh",
```

`agent-setup` は `sudo` で動くので環境がリセットされ、`.env` の変数は `--preserve-env=` に
書いたものしか届きませんでした。一覧から漏れた変数は、設定しても黙って無視されます。その一覧は
あなたのファイルであるここにあり、agent-setup が変数を増やすたびに遅れていました
(`SEKIMORE_GUIDE_LANG`)。`post-start.sh` はコンテナにある `SEKIMORE_*` 変数をすべて渡し、
続けて `docker-init.sh` とあなたの `.devcontainer/scripts/post-create.sh` を実行します。
以前の 1 行がしていたことと同じです。そこで他に実行していたものは `post-create.sh` に移してください。

`.env` にある「`--preserve-env=` に足すこと」というコメントも不要になります。

## base 0.2.26 credential helper の除去は `post-start.sh` が行う

**任意: あなたの `post-create.sh` にあれば、消す行があります。**

`.devcontainer/sgw/post-start.sh` が、VS Code 拡張が `/etc/gitconfig` と `~/.gitconfig` に書く
HTTPS の credential helper を、起動のたびに、あなたの `post-create.sh` より先に取り除きます。
`SEKIMORE_ALLOW_CREDENTIAL_HELPER=1` で残せるのは今までどおりです。

古いサンプルから始めたプロジェクトは、自分の `.devcontainer/scripts/post-create.sh` に
`disable_vscode_credential_helper` を持っています。関数と、それを呼ぶ箇所を消してください。
残しておくと重複するだけでは済みません。最後が `[ "$changed" = 1 ] && echo …` なので、
取り除くものが無いと 1 を返し、`set -e` の下で post-create.sh が止まり、コンテナの起動も
失敗します。サンプルの写しは `/etc/gitconfig` を sudo 無しで書き換えていたので、system 側の
helper も取り除けていませんでした。
