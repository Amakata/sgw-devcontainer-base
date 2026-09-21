#!/bin/zsh
set -e

echo "=== sgw-sample devcontainer post-create ==="

# ---------------------------------------------------------------------------
# Restore mise installs from the image-staged copy.
#
# docker-compose mounts a named volume onto ~/.local/share/mise/installs,
# which shadows whatever was baked into the image. On first run the volume
# is empty, so we copy the staged installs-default back into place. On
# subsequent runs the volume already has content and rsync is a no-op.
#
# After restoring, regenerate shims so ~/.local/share/mise/shims points to
# the (possibly newly-restored) installs tree.
# ---------------------------------------------------------------------------
if [ -d "$HOME/.local/share/mise/installs-default" ]; then
  echo "Restoring mise installs from installs-default..."
  mkdir -p "$HOME/.local/share/mise/installs"
  rsync -a --ignore-existing \
    "$HOME/.local/share/mise/installs-default/" \
    "$HOME/.local/share/mise/installs/"
  if command -v mise >/dev/null 2>&1; then
    mise reshim
  fi
fi

# ---------------------------------------------------------------------------
# Deploy zsh rc.d snippets to ~/.config/zsh/rc.d/.
#
# Two-step copy:
#   1. Copy base image defaults from /etc/skel/zsh-rc.d/
#   2. Copy project-specific files from .devcontainer/zsh-config/rc.d/
#
# If both provide a file with the same name, the project one wins.
# Files only in the base remain untouched.
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.config/zsh/rc.d"

echo "Copying base zsh rc.d defaults..."
cp -r /etc/skel/zsh-rc.d/* "$HOME/.config/zsh/rc.d/"

if [ -d /workspace/.devcontainer/zsh-config/rc.d ]; then
  echo "Overriding with project-specific zsh rc.d..."
  cp -r /workspace/.devcontainer/zsh-config/rc.d/* "$HOME/.config/zsh/rc.d/"
fi

# ---------------------------------------------------------------------------
# .zshrc: source rc.d + enable plugins
# ---------------------------------------------------------------------------
if ! grep -q "Load XDG Base Directory configurations" "$HOME/.zshrc"; then
  cat >> "$HOME/.zshrc" <<'EOF'

# Load XDG Base Directory configurations
if [ -d "$HOME/.config/zsh/rc.d" ]; then
  for file in "$HOME/.config/zsh/rc.d"/*.zsh; do
    [ -r "$file" ] && source "$file"
  done
  unset file
fi
EOF
fi

sed -i 's/^plugins=(git)$/plugins=(git zsh-completions zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)/' "$HOME/.zshrc"


# ---------------------------------------------------------------------------
# sekimore-relay guardrail: the operator's (a human's) SSH key - the ssh-agent - must not be usable
# from this AI container. Under the relay setup, authentication to GitHub happens inside sekimore-gw.
# An ssh-agent visible here means the reversal of key propagation is not in place, so stop with an
# error and point at the steps to take on the Mac (design D-6).
# The VS Code Dev Containers extension always forwards the agent into the container whenever VS Code
# itself can use one (no setting turns it off: microsoft/vscode-remote-release#11413).
# ---------------------------------------------------------------------------
if ssh-add -l >/dev/null 2>&1; then
  if [ "${SEKIMORE_ALLOW_AGENT_FORWARD:-0}" = "1" ]; then
    echo "⚠️  Your Mac's SSH key (ssh-agent) is usable from this container. Continuing because SEKIMORE_ALLOW_AGENT_FORWARD=1, but the AI can use your key."
  else
    {
      echo ""
      echo "❌ Start-up aborted: your Mac's SSH key (ssh-agent) is usable from this dev container."
      echo "   This setup does not let the AI inside the container use your key. sekimore-gw authenticates to GitHub instead."
      echo ""
      echo "   How to fix it (on the Mac, in this order):"
      echo "     1. Quit VS Code completely with Cmd+Q"
      echo "     2. Run this in Terminal.app (a terminal inside VS Code will not do):"
      echo "          cd <this project's folder> && mise run vscode"
      echo "        -> VS Code starts with no access to the SSH key"
      echo "     3. In that VS Code, run \"Dev Containers: Reopen in Container\""
      echo "     4. Check: inside the container ssh-add -l should fail (Could not open a connection to your authentication agent)"
      echo ""
      echo "   Why: the VS Code Dev Containers extension always forwards the key into the container when VS Code itself can use it (no setting turns it off)."
      echo "        mise run vscode starts VS Code alone without showing it the SSH key. Docker Desktop (which hands the key to sekimore-gw) is unaffected."
      echo "   To ignore this and start anyway: put SEKIMORE_ALLOW_AGENT_FORWARD=1 in .devcontainer/.env and Rebuild (not recommended)"
      echo ""
    } >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# sekimore-relay guardrail (part 2): close the route by which HTTPS git borrows the requester's
# GitHub authentication. The VS Code Dev Containers extension plants two of them:
#   (a) it writes git's credential.helper into /etc/gitconfig and ~/.gitconfig
#   (b) it injects GIT_ASKPASS + VSCODE_GIT_IPC_HANDLE into every shell's environment (used by git's
#       HTTP Basic authentication)
# Either one lets a clone/push of https://github.com/... through with the requester's permissions,
# around the gateway. Under the relay setup git is meant to go only over the gateway's SSH, so both
# are disabled. git@github.com (SSH) is unaffected.
#   - (a) is removed here (it cannot be disabled in devcontainer.json. The extension writes it every
#     time, so it is undone on every start-up)
#   - (b) is defused by rc.d/70-sekimore.zsh setting GIT_ASKPASS='' (interactive shells).
#         For non-interactive tool invocations git's core.askpass cannot be emptied here
#         (the environment wins), so the protection is removing the helper and funnelling
#         everything through the SSH route.
# To put it back temporarily, SEKIMORE_ALLOW_CREDENTIAL_HELPER=1.
# ---------------------------------------------------------------------------
disable_vscode_credential_helper() {
  local scope changed=0 cur
  for scope in system global; do
    cur=$(git config --"$scope" --get-all credential.helper 2>/dev/null || true)
    case "$cur" in
      *vscode-remote-containers*|*vscode-server*)
        git config --"$scope" --unset-all credential.helper 2>/dev/null || true
        git config --"$scope" credential.helper "" 2>/dev/null || true
        changed=1 ;;
    esac
  done
  [ "$changed" = 1 ] && echo "[agent] relay: disabled the VS Code HTTPS git credential helper (git now goes over the gateway's SSH; keep it with SEKIMORE_ALLOW_CREDENTIAL_HELPER=1)"
}
if [ "${SEKIMORE_ALLOW_CREDENTIAL_HELPER:-0}" != "1" ]; then
  disable_vscode_credential_helper
fi

echo "✅ post-create done. Open a new terminal to pick up zsh settings."
