#!/usr/bin/env bash
# vscode.sh — VS Code を「SSH_AUTH_SOCK が届かない状態」で起動する (mise run vscode)。ホスト (Mac) 側で実行する。
#
# Dev Containers 拡張は VS Code 本体の環境に SSH_AUTH_SOCK があると依頼者の ssh-agent を無条件に dev へ転送する
# (無効化設定なし: vscode-remote-release#11413)。単純な `env -u SSH_AUTH_SOCK code …` は macOS では効かない:
#   1. `code` CLI は macOS (Big Sur 以降) では `open -n -a …` で本体を起動する。open は LaunchServices 経由なので
#      本体はシェルではなく launchd の環境 (SSH_AUTH_SOCK=/private/tmp/com.apple.launchd.*/Listeners) を継ぐ
#   2. 本体はさらにログインシェルを起動して環境を取り込む (shell env resolution)。~/.zshrc 等で
#      SSH_AUTH_SOCK を export していると (1Password など) そこから戻る。VSCODE_CLI=1 のときだけ省略される
#   3. VS Code が既に起動していると新しい `code` は既存インスタンス (SSH_AUTH_SOCK あり) に渡るだけ
# そこでこのスクリプトは (a) launchd の SSH_AUTH_SOCK を外し (b) 本体 (Electron) を open を通さず直接、
# SSH_AUTH_SOCK 無し + VSCODE_CLI=1 で起動し (c) 起動後に本体の環境を ps -Eww で確認する。
#
# Docker Desktop との順序: gateway に渡す /run/host-services/ssh-auth.sock は Docker Desktop が「自分の起動時の」
# SSH_AUTH_SOCK を転送している。Docker Desktop は先に (SSH_AUTH_SOCK ありで) 起動しておく。(a) の後に
# Docker Desktop を再起動する場合は `vscode.sh --restore-agent-env` で launchd の値を戻してから。
#
#   vscode.sh                      起動 (検査つき)
#   vscode.sh --check              状態確認のみ (launchd / Docker Desktop / 起動中の VS Code)
#   vscode.sh --restore-agent-env  launchd に SSH_AUTH_SOCK を戻す (Docker Desktop を再起動する前に)
set -euo pipefail

ROOT=${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
MODE=${1:-launch}
STATE_DIR=${SEKIMORE_HOST_STATE_DIR:-$HOME/.sekimore}
SAVED_SOCK_FILE=$STATE_DIR/launchd_ssh_auth_sock
os=$(uname -s)

# VS Code 本体 (メインプロセス) の "pid command" 行。Helper (renderer 等) は除く
vscode_procs() {
  case "$os" in
    Darwin) ps -axo pid=,command= | grep -F '/Contents/MacOS/' | grep -Ei 'visual studio code|/code( - insiders)?\.app' | grep -Ev 'Helper|--type=|Frameworks/' || true ;;
    *)      ps -axo pid=,command= | grep -E '^ *[0-9]+ +(/[^ ]*/)?code(-insiders)?( |$)' || true ;;
  esac
}
find_vscode_pids() { vscode_procs | awk '{print $1}'; }
# 指定 PID の環境に SSH_AUTH_SOCK があれば 0 (自分のプロセスのみ見える)
has_agent_env() {
  case "$os" in
    Darwin) ps -Eww -o command= -p "$1" 2>/dev/null | tr ' ' '\n' | grep -q '^SSH_AUTH_SOCK=' ;;
    *)      tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | grep -q '^SSH_AUTH_SOCK=' ;;
  esac
}
launchd_sock() { if [ "$os" = Darwin ]; then launchctl getenv SSH_AUTH_SOCK 2>/dev/null || true; fi; }
docker_backend_pid() { pgrep -f 'com.docker.backend' 2>/dev/null | head -1 || true; }

report() {  # 戻り値 0 = VS Code が起動中で SSH_AUTH_SOCK を持っている
  local pids found=0 dirty=0 ls dp
  if [ "$os" = Darwin ]; then
    ls=$(launchd_sock)
    echo "launchd SSH_AUTH_SOCK: ${ls:-<unset>}   (unset なら以後 GUI 経由で起動するアプリには渡らない)"
    dp=$(docker_backend_pid)
    if [ -z "$dp" ]; then
      echo "Docker Desktop:        not running (gateway の agent はこれが転送する。SSH_AUTH_SOCK ありで先に起動する)"
    elif has_agent_env "$dp"; then
      echo "Docker Desktop:        running with SSH_AUTH_SOCK (OK: gateway に agent が渡る)"
    else
      echo "Docker Desktop:        running WITHOUT SSH_AUTH_SOCK — gateway の agent は動かない (--restore-agent-env の後に Docker Desktop を再起動)"
    fi
  fi
  pids=$(find_vscode_pids)
  for p in $pids; do found=1; has_agent_env "$p" && dirty=1; done
  if [ "$found" -eq 0 ]; then
    echo "VS Code:               not running (no process matching */Contents/MacOS/* under *Visual Studio Code*.app)"
    return 1
  fi
  vscode_procs | cut -c1-160 | sed 's/^/  process: /'
  if [ "$dirty" -eq 1 ]; then
    echo "VS Code:               RUNNING WITH SSH_AUTH_SOCK — Dev Containers が依頼者の agent を dev に転送する"; return 0
  fi
  echo "VS Code:               running without SSH_AUTH_SOCK (OK)"; return 1
}

restore_agent_env() {
  [ "$os" = Darwin ] || { echo "vscode.sh: --restore-agent-env is for macOS" >&2; exit 2; }
  local v
  v=$(cat "$SAVED_SOCK_FILE" 2>/dev/null || true)
  if [ -z "$v" ]; then
    # 保存が無ければ launchd の ssh-agent socket を探す (com.openssh.ssh-agent の Listeners)
    v=$(ls /private/tmp/com.apple.launchd.*/Listeners 2>/dev/null | head -1 || true)
  fi
  [ -n "$v" ] || { echo "vscode.sh: no saved value and no launchd agent socket found; logging out/in restores it" >&2; exit 1; }
  launchctl setenv SSH_AUTH_SOCK "$v"
  echo "vscode.sh: launchd SSH_AUTH_SOCK restored to $v (Docker Desktop を再起動するならこの後)"
}

case "$MODE" in
  --check) if report; then exit 1; else exit 0; fi ;;
  --restore-agent-env) restore_agent_env; exit 0 ;;
  launch) ;;
  *) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac

if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
  echo "vscode.sh: run this from Terminal.app / iTerm, not from a VS Code integrated terminal." >&2; exit 2
fi
if [ "${DEVCONTAINER:-}" = "true" ]; then
  echo "vscode.sh: this is the inside of the dev container; run it on the host (Mac)." >&2; exit 2
fi

# 既に起動している VS Code があれば終了してもらう (新しい code は既存インスタンスに渡るだけ)
if report; then
  echo "  起動中の VS Code が SSH_AUTH_SOCK を持っています。完全終了 (Cmd+Q) が必要です。" >&2
  if [ -t 0 ] && [ "$os" = Darwin ]; then
    printf '  今終了しますか? (未保存があれば VS Code が確認します) [y/N] '
    read -r ans
    if [ "$ans" = y ] || [ "$ans" = Y ]; then
      osascript -e 'tell application "Visual Studio Code" to quit' || true
      for _ in $(seq 1 30); do [ -z "$(find_vscode_pids)" ] && break; sleep 1; done
    fi
  fi
  [ -z "$(find_vscode_pids)" ] || { echo "vscode.sh: VS Code is still running; quit it (Cmd+Q) and run 'mise run vscode' again." >&2; exit 1; }
fi

launched_pid=""
if [ "$os" = Darwin ]; then
  # (a) launchd の SSH_AUTH_SOCK を外す (以後に GUI 経由で起動するアプリに渡らない。再ログインで戻る)
  cur=$(launchd_sock)
  if [ -n "$cur" ]; then
    mkdir -p "$STATE_DIR"; printf '%s\n' "$cur" > "$SAVED_SOCK_FILE"
    launchctl unsetenv SSH_AUTH_SOCK
    echo "vscode.sh: launchd の SSH_AUTH_SOCK を外しました (保存: $SAVED_SOCK_FILE。戻すには: mise run vscode:restore-agent-env)"
  fi
  dp=$(docker_backend_pid)
  if [ -z "$dp" ]; then
    echo "vscode.sh: ⚠️  Docker Desktop が起動していません。gateway に agent を渡すには、vscode:restore-agent-env の後に Docker Desktop を起動してください" >&2
  elif ! has_agent_env "$dp"; then
    echo "vscode.sh: ⚠️  Docker Desktop が SSH_AUTH_SOCK 無しで動いています。gateway の agent は使えません (vscode:restore-agent-env → Docker Desktop 再起動)" >&2
  fi

  # (b) 本体を open を通さずに直接起動する (シェルの環境 = SSH_AUTH_SOCK 無し を継ぐ。VSCODE_CLI=1 で shell env resolution を省く)
  app=${SEKIMORE_VSCODE_APP:-}
  if [ -z "$app" ] && command -v code >/dev/null; then
    real=$(perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$(command -v code)")
    app=${real%/Contents/Resources/app/bin/code}
    case "$app" in *.app) ;; *) app="" ;; esac
  fi
  [ -n "$app" ] || app="/Applications/Visual Studio Code.app"
  electron="$app/Contents/MacOS/Electron"
  [ -x "$electron" ] || { echo "vscode.sh: VS Code app not found ($electron). Set SEKIMORE_VSCODE_APP=/path/to/Visual Studio Code.app" >&2; exit 2; }
  echo "vscode.sh: launching $app without SSH_AUTH_SOCK: $ROOT"
  cd /
  env -u SSH_AUTH_SOCK VSCODE_CLI=1 nohup "$electron" "$ROOT" >/dev/null 2>&1 &
  launched_pid=$!
  disown "$launched_pid" 2>/dev/null || true
  cd "$ROOT"
else
  command -v code >/dev/null || { echo "vscode.sh: 'code' CLI not found" >&2; exit 2; }
  echo "vscode.sh: launching VS Code without SSH_AUTH_SOCK: $ROOT"
  env -u SSH_AUTH_SOCK VSCODE_CLI=1 code "$ROOT"
fi

# (c) 起動を待って本体の環境を確認する
for _ in $(seq 1 30); do [ -n "$(find_vscode_pids)" ] && break; sleep 1; done
sleep 3
if [ -n "$launched_pid" ] && kill -0 "$launched_pid" 2>/dev/null; then
  if has_agent_env "$launched_pid"; then
    echo "vscode.sh: ❌ 直接起動した本体 (pid $launched_pid) の環境に SSH_AUTH_SOCK があります。この出力を添えて報告してください" >&2; exit 1
  fi
  echo "vscode.sh: 本体 pid $launched_pid の環境に SSH_AUTH_SOCK は無い"
fi
if report; then
  echo "vscode.sh: ❌ 起動中の VS Code の環境に SSH_AUTH_SOCK があります。この出力を添えて報告してください (mise run vscode:check でも再確認できます)" >&2
  exit 1
fi
echo "vscode.sh: OK — 'Dev Containers: Reopen in Container' で開き、dev 内で 'ssh-add -l' が失敗することを確認 (mise run relay:verify)。"
