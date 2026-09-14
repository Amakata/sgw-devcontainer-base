#!/usr/bin/env bash
# sgw.sh — この devcontainer の compose スタック (Dev Containers 拡張が起動したもの) を Mac 側から操作する。
# mise.toml の task から呼ぶ。直接使うなら:
#
#   sgw.sh gw   [cmd...]   sekimore-gw コンテナで cmd を実行 (省略時: sekimore-relay check)
#   sgw.sh dev  [cmd...]   dev コンテナで cmd を実行 (vscode ユーザー。省略時: zsh)
#   sgw.sh id   <service>  コンテナ ID を表示
#   sgw.sh project         compose プロジェクト名を表示 (Dev Containers は "<フォルダ名>_devcontainer")
#   sgw.sh ps              スタックのコンテナ一覧
#
# 探し方: compose のラベル (service 名 + project の working_dir = この .devcontainer)。
# プロジェクト名はフォルダ名に依存するので名前ではなくラベルで引く。
set -euo pipefail

ROOT=${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
COMPOSE_DIR=${SGW_COMPOSE_DIR:-$ROOT/.devcontainer}

if [ "${DEVCONTAINER:-}" = "true" ] && [ -z "${SGW_FORCE:-}" ]; then
  echo "sgw: this is the inside of the dev container; run it on the host (Mac) where Docker Desktop runs the stack." >&2
  exit 2
fi

by_label() { docker ps -q --filter "label=com.docker.compose.project.working_dir=$COMPOSE_DIR" "$@"; }

find_container() {
  local svc=$1 ids n
  ids=$(by_label --filter "label=com.docker.compose.service=$svc")
  if [ -z "$ids" ]; then
    # working_dir ラベルが一致しない環境 (パスの正規化違い等) 向けフォールバック: service 名だけで一意なら採用
    ids=$(docker ps -q --filter "label=com.docker.compose.service=$svc")
  fi
  n=$(printf '%s\n' "$ids" | grep -c . || true)
  if [ "$n" -eq 0 ]; then
    echo "sgw: no running container for service '$svc' (is the devcontainer open? working_dir=$COMPOSE_DIR)" >&2
    docker ps -a --format '  {{.Names}}  {{.Status}}  ({{.Image}})' --filter "label=com.docker.compose.service=$svc" >&2 || true
    exit 1
  fi
  if [ "$n" -gt 1 ]; then
    echo "sgw: several '$svc' containers are running; stop the others or set MISE_PROJECT_ROOT / SGW_COMPOSE_DIR:" >&2
    docker ps --format '  {{.Names}}  {{.Label "com.docker.compose.project.working_dir"}}' --filter "label=com.docker.compose.service=$svc" >&2
    exit 1
  fi
  printf '%s' "$ids"
}

tty_flag() { if [ -t 0 ] && [ -t 1 ]; then echo "-it"; else echo "-i"; fi; }

case "${1:-}" in
  gw)
    shift; cid=$(find_container sekimore-gw)
    if [ $# -eq 0 ]; then set -- sekimore-relay check; fi
    exec docker exec "$(tty_flag)" "$cid" "$@" ;;
  dev)
    shift; cid=$(find_container dev)
    if [ $# -eq 0 ]; then set -- zsh; fi
    exec docker exec "$(tty_flag)" -u vscode "$cid" "$@" ;;
  id)
    find_container "${2:?usage: sgw.sh id <service>}"; echo ;;
  project)
    cid=$(find_container sekimore-gw)
    docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$cid" ;;
  ps)
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' --filter "label=com.docker.compose.project.working_dir=$COMPOSE_DIR" ;;
  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
