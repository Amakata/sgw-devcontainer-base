#!/usr/bin/env bash
# vscode.sh — start VS Code so that SSH_AUTH_SOCK never reaches it (mise run vscode). Run it on the host (Mac).
#
# With SSH_AUTH_SOCK in VS Code's own environment, the Dev Containers extension forwards the operator's (your) SSH key (ssh-agent)
# into the container unconditionally (no setting disables it: vscode-remote-release#11413). A plain `env -u SSH_AUTH_SOCK code …` fails on macOS:
#   1. the `code` CLI on macOS (Big Sur and later) starts the app with `open -n -a …`. open goes through LaunchServices,
#      so the app inherits launchd's environment (SSH_AUTH_SOCK=/private/tmp/com.apple.launchd.*/Listeners), not the shell's
#   2. the app then starts a login shell and takes its environment in (shell env resolution). Exporting SSH_AUTH_SOCK
#      from ~/.zshrc and the like (1Password, say) brings it back. Only VSCODE_CLI=1 leaves that step out
#   3. when VS Code is already running, a new `code` only hands the folder to the existing instance (which has the socket)
# So this script (a) unsets launchd's SSH_AUTH_SOCK, (b) starts the app directly rather than through open, with no
# SSH_AUTH_SOCK and VSCODE_CLI=1, and (c) checks the app's environment with ps -Eww once it is up.
#
# Order with Docker Desktop: the /run/host-services/ssh-auth.sock handed to the gateway is Docker Desktop forwarding the
# SSH_AUTH_SOCK it had "at its own start-up". Start Docker Desktop first (with SSH_AUTH_SOCK). To restart Docker Desktop
# after (a), put launchd's value back with `vscode.sh --restore-agent-env` first.
#
#   vscode.sh                      launch (with the checks)
#   vscode.sh --check              report only (launchd / shell / rc files / Docker Desktop / a running VS Code)
#   vscode.sh --restore-agent-env  put SSH_AUTH_SOCK back into launchd (before restarting Docker Desktop)
#   SEKIMORE_VSCODE_APP=/path/to/Visual Studio Code.app   name the app location (when it cannot be found automatically)
set -euo pipefail

ROOT=${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
MODE=${1:-launch}
STATE_DIR=${SEKIMORE_HOST_STATE_DIR:-$HOME/.sekimore}
SAVED_SOCK_FILE=$STATE_DIR/launchd_ssh_auth_sock
os=$(uname -s)

# ---- macOS: where the VS Code app is, and the name of its executable ----
APP=""; EXE=""; APP_HOW=""
resolve_app() {
  [ "$os" = Darwin ] || return 0
  local real cand
  if [ -n "${SEKIMORE_VSCODE_APP:-}" ]; then APP=${SEKIMORE_VSCODE_APP%/}; APP_HOW="SEKIMORE_VSCODE_APP"; fi
  # 1. work back from what `code` actually resolves to (…/X.app/Contents/Resources/app/bin/code → X.app)
  if [ -z "$APP" ] && command -v code >/dev/null 2>&1; then
    real=$(perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$(command -v code)" 2>/dev/null || true)
    cand=$(printf '%s' "$real" | sed -E 's|(\.app)/.*$|\1|')
    if [ -n "$cand" ] && [ "$cand" != "$real" ] && [ -d "$cand" ]; then APP=$cand; APP_HOW="command -v code → $real"; fi
  fi
  # 2. ask LaunchServices (works with Spotlight disabled)
  if [ -z "$APP" ]; then
    for id in com.microsoft.VSCode com.microsoft.VSCodeInsiders; do
      cand=$(osascript -e "POSIX path of (path to application id \"$id\")" 2>/dev/null || true)
      cand=${cand%/}
      if [ -n "$cand" ] && [ -d "$cand" ]; then APP=$cand; APP_HOW="LaunchServices ($id)"; break; fi
    done
  fi
  # 3. the well-known locations
  if [ -z "$APP" ]; then
    for cand in "/Applications/Visual Studio Code.app" "$HOME/Applications/Visual Studio Code.app" \
                "/Applications/Visual Studio Code - Insiders.app" "$HOME/Applications/Visual Studio Code - Insiders.app"; do
      if [ -d "$cand" ]; then APP=$cand; APP_HOW="well-known path"; break; fi
    done
  fi
  [ -n "$APP" ] || return 0
  EXE=$(defaults read "$APP/Contents/Info" CFBundleExecutable 2>/dev/null || true)
  [ -n "$EXE" ] || EXE=Electron
}

# "pid command" lines for VS Code itself (the main process). Helpers (renderer and the rest) are excluded
vscode_procs() {
  case "$os" in
    Darwin)
      if [ -n "$APP" ]; then
        ps -axo pid=,command= | grep -F "$APP/Contents/MacOS/$EXE" | grep -Ev 'Helper|--type=|Frameworks/| grep ' || true
      else
        ps -axo pid=,command= | grep -F '/Contents/MacOS/' | grep -Ei 'visual studio code|/code( - insiders)?\.app' | grep -Ev 'Helper|--type=|Frameworks/| grep ' || true
      fi ;;
    *) ps -axo pid=,command= | grep -E '^ *[0-9]+ +(/[^ ]*/)?code(-insiders)?( |$)' || true ;;
  esac
}
find_vscode_pids() { vscode_procs | awk '{print $1}'; }
# 0 if the given PID's environment has SSH_AUTH_SOCK (only your own processes are visible)
has_agent_env() {
  case "$os" in
    Darwin) ps -Eww -o command= -p "$1" 2>/dev/null | tr ' ' '\n' | grep -q '^SSH_AUTH_SOCK=' ;;
    *)      tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | grep -q '^SSH_AUTH_SOCK=' ;;
  esac
}
launchd_sock() { if [ "$os" = Darwin ]; then launchctl getenv SSH_AUTH_SOCK 2>/dev/null || true; fi; }
docker_backend_pid() { pgrep -f 'com.docker.backend' 2>/dev/null | head -1 || true; }

report() {  # returns 0 = VS Code is running and has SSH_AUTH_SOCK
  local pids found=0 dirty=0 ls dp rc
  if [ "$os" = Darwin ]; then
    ls=$(launchd_sock)
    echo "launchd SSH_AUTH_SOCK: ${ls:-<unset>}   (unset: apps started through the GUI from now on do not get it)"
    echo "shell   SSH_AUTH_SOCK: ${SSH_AUTH_SOCK:-<unset>}"
    rc=$(grep -ln 'SSH_AUTH_SOCK' "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile" 2>/dev/null | tr '\n' ' ' || true)
    echo "rc files setting it:   ${rc:-<none>}   (if any, VS Code's shell env resolution brings it back → launch with VSCODE_CLI=1)"
    dp=$(docker_backend_pid)
    if [ -z "$dp" ]; then
      echo "Docker Desktop:        not running (this is what forwards the agent to the gateway; start it first, with SSH_AUTH_SOCK)"
    elif has_agent_env "$dp"; then
      echo "Docker Desktop:        running with SSH_AUTH_SOCK (OK: the agent reaches the gateway)"
    else
      echo "Docker Desktop:        running WITHOUT SSH_AUTH_SOCK — the gateway's agent will not work (restart Docker Desktop after --restore-agent-env)"
    fi
    if [ -n "$APP" ]; then echo "VS Code app:           $APP (exe: $EXE; via $APP_HOW)"; else echo "VS Code app:           NOT FOUND (set SEKIMORE_VSCODE_APP)"; fi
  fi
  pids=$(find_vscode_pids)
  for p in $pids; do found=1; has_agent_env "$p" && dirty=1; done
  if [ "$found" -eq 0 ]; then echo "VS Code:               not running"; return 1; fi
  vscode_procs | cut -c1-160 | sed 's/^/  process: /'
  if [ "$dirty" -eq 1 ]; then
    echo "VS Code:               RUNNING WITH SSH_AUTH_SOCK — as it stands, your SSH key is usable by the AI inside the container"; return 0
  fi
  echo "VS Code:               running without SSH_AUTH_SOCK (OK)"; return 1
}

restore_agent_env() {
  [ "$os" = Darwin ] || { echo "vscode.sh: --restore-agent-env is for macOS" >&2; exit 2; }
  local v
  v=$(cat "$SAVED_SOCK_FILE" 2>/dev/null || true)
  if [ -z "$v" ]; then
    # with nothing saved, look for launchd's ssh-agent socket (com.openssh.ssh-agent's Listeners)
    v=$(ls /private/tmp/com.apple.launchd.*/Listeners 2>/dev/null | head -1 || true)
  fi
  [ -n "$v" ] || { echo "vscode.sh: no saved value and no launchd agent socket found; logging out/in restores it" >&2; exit 1; }
  launchctl setenv SSH_AUTH_SOCK "$v"
  echo "vscode.sh: launchd SSH_AUTH_SOCK restored to $v (restart Docker Desktop after this, if you are going to)"
}

resolve_app
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

# Have an already running VS Code quit (a new code only hands over to the existing instance)
if report; then
  echo "  The running VS Code has SSH_AUTH_SOCK. It has to be quit completely (Cmd+Q)." >&2
  if [ -t 0 ] && [ "$os" = Darwin ]; then
    printf '  Quit it now? (VS Code will ask about anything unsaved) [y/N] '
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
  [ -n "$APP" ] || { echo "vscode.sh: VS Code app not found. Run with SEKIMORE_VSCODE_APP=\"/path/to/Visual Studio Code.app\" (find it with: mdfind 'kMDItemCFBundleIdentifier == com.microsoft.VSCode')" >&2; exit 2; }
  electron="$APP/Contents/MacOS/$EXE"
  [ -x "$electron" ] || { echo "vscode.sh: executable not found: $electron" >&2; exit 2; }

  # (a) unset launchd's SSH_AUTH_SOCK (apps started through the GUI from now on do not get it; logging back in restores it)
  cur=$(launchd_sock)
  if [ -n "$cur" ]; then
    mkdir -p "$STATE_DIR"; printf '%s\n' "$cur" > "$SAVED_SOCK_FILE"
    launchctl unsetenv SSH_AUTH_SOCK
    echo "vscode.sh: unset launchd's SSH_AUTH_SOCK (saved in $SAVED_SOCK_FILE; to put it back: mise run vscode:restore-agent-env)"
  fi
  dp=$(docker_backend_pid)
  if [ -z "$dp" ]; then
    echo "vscode.sh: ⚠️  Docker Desktop is not running. To get the agent to the gateway, start Docker Desktop after vscode:restore-agent-env" >&2
  elif ! has_agent_env "$dp"; then
    echo "vscode.sh: ⚠️  Docker Desktop is running without SSH_AUTH_SOCK. The gateway's agent will not work (vscode:restore-agent-env → restart Docker Desktop)" >&2
  fi

  # (b) start the app directly instead of through open (it inherits the shell's environment = no SSH_AUTH_SOCK; VSCODE_CLI=1 leaves shell env resolution out)
  echo "vscode.sh: launching \"$electron\" without SSH_AUTH_SOCK: $ROOT"
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

# (c) wait for it to come up, then check the app's environment
for _ in $(seq 1 30); do [ -n "$(find_vscode_pids)" ] && break; sleep 1; done
sleep 3
if [ -n "$launched_pid" ] && kill -0 "$launched_pid" 2>/dev/null; then
  if has_agent_env "$launched_pid"; then
    echo "vscode.sh: ❌ the directly launched app (pid $launched_pid) has SSH_AUTH_SOCK in its environment. Report this with the output above" >&2; exit 1
  fi
  echo "vscode.sh: no SSH_AUTH_SOCK in the environment of app pid $launched_pid"
fi
if report; then
  echo "vscode.sh: ❌ the running VS Code has SSH_AUTH_SOCK in its environment. Report this with the output above (mise run vscode:check re-checks it)" >&2
  exit 1
fi
echo "vscode.sh: OK — open it with 'Dev Containers: Reopen in Container', then check that 'ssh-add -l' fails inside dev (mise run relay:verify)."
