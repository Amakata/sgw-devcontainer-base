# sgw-devcontainer-base 変更履歴

*[English](CHANGELOG.md)*

DevContainer のベースイメージ — Dockerfile と焼き込む道具、同梱する zsh 設定と
スクリプト、`examples/` のサンプル devcontainer。

**Security** / **Fix** / **Enhancement** に分け、重いものから並べる。
各行は何が変わったかと、変えた PR だけを書く。理由は PR にある。

各リリースは取り込んだ sekimore-gw の版 (Dockerfile の `ARG SEKIMORE_GW_IMAGE`) を書く。
両者の組合せの記録はこのファイル。

0.2.18 から始める。それ以前のリリースはここに書かない。各 PR とタグが記録。
取り込んだ gateway の版だけは末尾にある。

## 0.2.25（2026-09-23）

### Fix

- `sgw.sh` が、人が端末にいるときは `docker exec` に端末を渡す。`mise run dev:shell` が固まらずにシェルを開く。以前は `$(...)` の中で判定していて、そこでは標準出力が常にパイプだった (#55)

## 0.2.24（2026-09-23）

### Fix

- apply / sync が `upgrade.sh` 自身を入れ替えたら、最後に新しいものを `--owned` で実行する。新しいリリースがあなたのファイルに求める変更が、次の実行を待たずに、そのリリースを入れた apply で出る (#54)

## 0.2.23（2026-09-23）

### Fix

- `dev:shell` に `raw = true` を付けた。mise の prefix 出力モードでは標準出力がパイプになり、シェルが端末なしで起動してプロンプトが出なかった。シェルを起動するタスクや `gw-tty` を通るタスクに `raw = true` が無ければ CI が落ちる (#51)
- `relay:verify` が、`user.signingkey` が gateway の署名ソケットの出す鍵かを確かめ、`key::` で鍵を直接書いている、またはソケットが出さない鍵ファイルを指しているときに知らせる (#51)

### Enhancement

- gateway 0.2.31 を取り込む (#51)

## 0.2.22（2026-09-23）

### Fix

- `postStartCommand` が配布物の `.devcontainer/sgw/post-start.sh` を実行する。コンテナにある `SEKIMORE_*` 変数をすべて `sudo` 越しに agent-setup に渡す。手で持っていた `--preserve-env=` の一覧から漏れた変数は黙って無視され、サンプルには一覧自体が無かった。`mise run upgrade` が 1 行の書き換えを案内し、調べるだけのときもあなたのファイルに要る変更を表示する (#49)

## 0.2.21（2026-09-23）

### Enhancement

- gateway 0.2.30 を取り込む。sample も gateway 0.2.30 とそのタスクファイルで動く (#47)

## 0.2.20（2026-09-23）

### Enhancement

- `mise run upgrade` が、固定している gateway と base を GHCR の最新と比べ、何が変わるかを表示する。`upgrade:apply` は 2 つのタグを書き換え、`.devcontainer/sgw/` を入れ替え、確認のうえ gateway を作り直して解錠し、人がやることだけを最後に並べる。配布物が手で書き換えられていれば、何も書かずに差分を出して止まる。`upgrade:sync` が `gw:sync-tasks` を置き換え、`upgrade:notes` は間にある UPGRADING の節を表示する (#45)
- ホスト側のスクリプトとタスクを `.devcontainer/sgw/` に移した。ここは `upgrade` のもので、`mise.toml` には include と自分のタスクだけが残る。`mise.toml` のタスクは同じ名前の配布タスクより優先される。サンプルもこの配置にし、`FROM` を版で固定した (#45)
- `upgrade.sh` / `sgw.sh` / `vscode.sh` の表示とタスクの説明が、relay と同じ規則で言語を決める: `SEKIMORE_LANG`、`LC_ALL`、`LC_MESSAGES`、`LANG` (#45)

## 0.2.19（2026-09-22）

### Fix

- サンプルの devcontainer が取り込む gateway を、固定されていた 0.2.19 から、このイメージが取り込む 0.2.29 に上げた。コメントは 0.2.18 以降のサンプルと同じく全て英語にし、`gw:sync-tasks` は英語版のタスクファイルをイメージから取り出すようにした。隣に置いてある `gateway.mise.toml` も 0.2.29 のものになり、`gw:unlock-auto` が入る (#41)
- `mise run web` が、task に書かれた数字ではなく、gateway が実際に公開しているポートを開くようにした。動いているコンテナから引く (`sgw.sh port <service> [container-port]` を追加)。サンプルは `8080:8080` なので直書きの数字がたまたま合っており、それがこの問題を隠していた。8090 が埋まっていてポートをずらしたときに壊れるが、それはサンプルをコピーして行うことそのものである (#42)

## 0.2.18（2026-09-21）

### Fix

- ラッパー `sekimore` が期限切れの案件トークンを取り直せるようになった。`POST /bootstrap` を呼ぶ (`sekimore-relay agent bootstrap` は元から無い)。env ファイルは置き場が root のものなので上書きで書く (#38)

### Enhancement

- gateway 0.2.29 を取り込む (#40)
- README.md を英語、README.ja.md を日本語にした。他のリポジトリと同じ形。サンプルの `config.yml` はコメントを英語にし、gateway が読むキーを全部 (権限キー 28 個を含む) 載せた (#39)
- この変更履歴を英語と日本語で追加した。gateway と relay が既に使っている形に合わせた (#26)

## 0.2.18 より前

内容は書かない。各 PR とタグが記録。ここに残すのは、取り込んだ gateway の版だけ。

- 0.2.17 は gateway 0.2.15 を取り込んだ
- 0.2.16 は gateway 0.2.15 を取り込んだ
- 0.2.15 は gateway 0.2.14 を取り込んだ
- 0.2.14 は gateway 0.2.13 を取り込んだ
- 0.2.13 は gateway 0.2.13 を取り込んだ
- 0.2.12 は gateway 0.2.11 を取り込んだ
