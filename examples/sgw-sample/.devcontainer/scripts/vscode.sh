#!/usr/bin/env bash
# vscode.sh — VS Code を SSH_AUTH_SOCK 無しで起動する (mise run vscode)。ホスト (Mac) 側で実行する。
#
# Dev Containers 拡張は VS Code 本体の環境に SSH_AUTH_SOCK があると依頼者の ssh-agent を無条件に dev へ転送する
# (無効化設定なし: vscode-remote-release#11413)。`env -u SSH_AUTH_SOCK code …` で防げるが、次の場合は効かない:
#   - VS Code が既に起動している: 新しい `code` は既存インスタンスに「開いて」と頼むだけで、既存インスタンスの環境
#     (SSH_AUTH_SOCK あり) が使われる → 先に完全終了 (Cmd+Q) が必要
#   - VS Code の統合ターミナルから実行している: 上と同じ (その VS Code が処理する)
# このスクリプトはそれを検査し、起動後に VS Code 本体の環境に SSH_AUTH_SOCK が無いことを確認する。
#
#   vscode.sh            起動 (検査つき)
#   vscode.sh --check    起動中の VS Code の環境を確認するだけ
set -euo pipefail

ROOT=${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
MODE=${1:-launch}

os=$(uname -s)
find_vscode_pids() {
  case "$os" in
    Darwin) pgrep -f 'Visual Studio Code.*\.app/Contents/MacOS/Electron' || true ;;
    *)      pgrep -x code || pgrep -f '/code(-insiders)? ' || true ;;
  esac
}
# 指定 PID の環境に SSH_AUTH_SOCK があれば 0
has_agent_env() {
  case "$os" in
    Darwin) ps -Eww -o command= -p "$1" 2>/dev/null | tr ' ' '\n' | grep -q '^SSH_AUTH_SOCK=' ;;
    *)      tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | grep -q '^SSH_AUTH_SOCK=' ;;
  esac
}
report_running() {  # 0 = 起動中で SSH_AUTH_SOCK を持っている
  local pids found=0 dirty=0
  pids=$(find_vscode_pids)
  for p in $pids; do
    found=1
    if has_agent_env "$p"; then dirty=1; fi
  done
  if [ "$found" -eq 0 ]; then echo "vscode: not running"; return 1; fi
  if [ "$dirty" -eq 1 ]; then
    echo "vscode: RUNNING WITH SSH_AUTH_SOCK — the Dev Containers extension will forward the operator's ssh-agent into dev"
    return 0
  fi
  echo "vscode: running without SSH_AUTH_SOCK (OK)"; return 1
}

if [ "$MODE" = "--check" ]; then report_running && exit 1 || exit 0; fi

if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
  echo "vscode.sh: run this from Terminal.app / iTerm, not from a VS Code integrated terminal (that VS Code would open the folder with its own environment)." >&2
  exit 2
fi
if [ "${DEVCONTAINER:-}" = "true" ]; then
  echo "vscode.sh: this is the inside of the dev container; run it on the host (Mac)." >&2; exit 2
fi
command -v code >/dev/null || { echo "vscode.sh: 'code' CLI not found. VS Code: Command Palette → \"Shell Command: Install 'code' command in PATH\"" >&2; exit 2; }

if report_running; then
  echo "  A running VS Code handles 'code <folder>' itself, so 'env -u SSH_AUTH_SOCK' has no effect until it is fully quit." >&2
  if [ -t 0 ] && [ "$os" = "Darwin" ]; then
    printf '  Quit VS Code now (Cmd+Q equivalent, unsaved work is prompted by VS Code)? [y/N] '
    read -r ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      osascript -e 'tell application "Visual Studio Code" to quit' || true
      for _ in $(seq 1 30); do [ -z "$(find_vscode_pids)" ] && break; sleep 1; done
      [ -n "$(find_vscode_pids)" ] && { echo "vscode.sh: VS Code is still running; quit it and retry." >&2; exit 1; }
    else
      echo "vscode.sh: quit VS Code (Cmd+Q) and run 'mise run vscode' again." >&2; exit 1
    fi
  else
    echo "vscode.sh: quit VS Code (Cmd+Q) and run 'mise run vscode' again." >&2; exit 1
  fi
fi

echo "vscode.sh: launching VS Code without SSH_AUTH_SOCK: $ROOT"
env -u SSH_AUTH_SOCK code "$ROOT"

# 起動を待って本体の環境を確認する
for _ in $(seq 1 20); do [ -n "$(find_vscode_pids)" ] && break; sleep 1; done
sleep 2
if report_running; then
  echo "vscode.sh: ❌ the new VS Code still has SSH_AUTH_SOCK. Was another instance running? Check with: mise run vscode:check" >&2
  exit 1
fi
echo "vscode.sh: OK — now 'Dev Containers: Reopen in Container'. In dev, 'ssh-add -l' must fail (mise run relay:verify)."
