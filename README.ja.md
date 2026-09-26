# sgw-devcontainer-base — 移転しました

このリポジトリは archive されています。ゲートウェイ 0.2.46 から、dev コンテナの base イメージは
[sekimore-gw の `base/`](https://github.com/Amakata/sekimore-gw/tree/main/base) から作り、同じタグで、
ゲートウェイと同じ版番号で出しています。イメージ名は変わりません: `ghcr.io/amakata/sgw-devcontainer-base`。

ここにある `v0.2.46` タグの役目は 1 つだけです。0.2.43 以前の `upgrade.sh` は配布ファイルをこのリポジトリから
読むので、このタグに 0.2.46 のファイルを置いておくと `mise run upgrade:apply` が一度ここを経由して渡れます。
以後のファイルは sekimore-gw から取ります。

0.2.43 までの履歴はここにあります。issue と pull request は
[sekimore-gw](https://github.com/Amakata/sekimore-gw) へ。
