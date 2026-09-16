#!/usr/bin/env bash
# sgw.sh — この devcontainer の compose スタック (Dev Containers 拡張が起動したもの) を Mac 側から操作する。
# mise.toml の task から呼ぶ。直接使うなら:
#
#   sgw.sh gw   [cmd...]   sekimore-gw コンテナで cmd を実行 (省略時: sekimore-relay check)
#   sgw.sh dev  [cmd...]   dev コンテナで cmd を実行 (vscode ユーザー。省略時: zsh)
#   sgw.sh id   <service>  コンテナ ID を表示
#   sgw.sh project         compose プロジェクト名を表示 (Dev Containers は "<フォルダ名>_devcontainer")
#   sgw.sh ps              スタックのコンテナ一覧
#   sgw.sh recreate        gateway を最新イメージで pull して作り直す (docker restart では入れ替わらない)
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

# compose の -f / --env-file 引数を配列 FARGS に組む。$1 = project working_dir、$2 = config_files ラベル ("," 区切り)、$3 = env file。
# パスに空白が入り得る (Dev Containers 生成ファイルは "~/Library/Application Support/…") ので、文字列連結ではなく配列で持つ。
# config_files ラベルがあればそれを使うが、過去に overlay 抜きで作り直されたコンテナはラベルにも overlay が残っていない。
# relay 構成 (docker-compose.relay.yml が存在する) ならそのファイルを必ず含める。存在しないファイルと重複は飛ばす。
compose_args() {
  local wd=$1 cfgs=$2 envfile=$3 c
  FARGS=()
  add_f() {
    local f=$1 x
    [ -f "$f" ] || return 0
    for x in "${FARGS[@]}"; do [ "$x" = "$f" ] && return 0; done
    FARGS+=(-f "$f")
  }
  if [ -n "$cfgs" ]; then
    local OLDIFS=$IFS; IFS=","
    for c in $cfgs; do
      case "$c" in /*) add_f "$c" ;; *) add_f "$wd/$c" ;; esac
    done
    IFS=$OLDIFS
  fi
  [ ${#FARGS[@]} -eq 0 ] && add_f "$wd/docker-compose.yml"
  add_f "$wd/docker-compose.relay.yml"
  [ -n "$envfile" ] && [ -f "$envfile" ] && FARGS+=(--env-file "$envfile")
  return 0
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
  recreate)
    # gateway を最新イメージで作り直す。docker restart は既存イメージのまま再開するので入れ替わらない。
    # compose の image タグを上げたあとに使う (Web UI の Relay タブが古い等)。
    # Dev Containers は複数の compose ファイル (docker-compose.yml + docker-compose.relay.yml + 生成ファイル) を重ねているので、
    # コンテナのラベル config_files からその全てを -f で渡す。1 つでも欠けると relay overlay (agent socket の
    # マウント等) が外れて gateway が壊れる。
    cid=$(find_container sekimore-gw)
    running=$(docker inspect -f "{{.Config.Image}}" "$cid")
    proj=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project\"}}" "$cid")
    wd=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project.working_dir\"}}" "$cid")
    cfgs=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project.config_files\"}}" "$cid")
    envfile=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project.environment_file\"}}" "$cid")
    compose_args "$wd" "$cfgs" "$envfile"
    # pull するのは compose が宣言している image (タグを上げた直後は実行中コンテナの image より新しい)。
    # compose up は既にあるタグを再 pull しないので、同じタグの更新 (latest 等) もここで取り込む。
    # compose config が使えない環境では実行中コンテナの image に戻る
    image=$(docker compose -p "$proj" --project-directory "$wd" "${FARGS[@]}" config --images sekimore-gw 2>/dev/null | head -1)
    image=${image:-$running}
    if [ "$image" != "$running" ]; then echo "gateway: $running → $image (project=$proj)"; else echo "gateway: $image (project=$proj)"; fi
    printf 'compose:'; printf ' %q' "${FARGS[@]}"; echo
    echo "before:  $(docker inspect -f "{{.Image}}" "$cid")"
    docker pull "$image"
    docker compose -p "$proj" --project-directory "$wd" "${FARGS[@]}" up -d --force-recreate sekimore-gw
    new=$(find_container sekimore-gw)
    echo "after:   $(docker inspect -f "{{.Image}}" "$new")"
    printf "waiting for the gateway"
    for _ in $(seq 1 30); do
      # gateway に curl は無いので python で叩く (必ず入っている)
      if docker exec "$new" python -c "import urllib.request,sys; urllib.request.urlopen(\"http://127.0.0.1:8080/api/config\",timeout=3)" 2>/dev/null; then echo " ok"; break; fi
      printf "."; sleep 1
    done
    echo "done. reload the Web UI Relay tab (or run: mise run gw:check)" ;;
  project)
    cid=$(find_container sekimore-gw)
    docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$cid" ;;
  ps)
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' --filter "label=com.docker.compose.project.working_dir=$COMPOSE_DIR" ;;
  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
