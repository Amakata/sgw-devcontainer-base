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

## 0.2.19（未リリース）

### Fix

- サンプルの devcontainer が取り込む gateway を、固定されていた 0.2.19 から、このイメージが取り込む 0.2.29 に上げた。コメントは 0.2.18 以降のサンプルと同じく全て英語にし、`gw:sync-tasks` は英語版のタスクファイルをイメージから取り出すようにした。隣に置いてある `gateway.mise.toml` も 0.2.29 のものになり、`gw:unlock-auto` が入る (#41)

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
