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
# sekimore-relay guardrail: 依頼者の ssh-agent はこのサンドボックスに届いてはいけない。
# relay 構成では上流 git の認証は sekimore-gw の中で行う。ここで agent が見えるなら鍵伝搬の反転が
# 成立していないので、エラーで止めてホスト側の対処を促す (design D-6)。
# VS Code Dev Containers 拡張は、VS Code プロセスに SSH_AUTH_SOCK があると無条件に転送する
# (無効化設定なし: microsoft/vscode-remote-release#11413)。
# ---------------------------------------------------------------------------
if ssh-add -l >/dev/null 2>&1; then
  if [ "${SEKIMORE_ALLOW_AGENT_FORWARD:-0}" = "1" ]; then
    echo "⚠️  ssh-agent is forwarded into the dev container (allowed by SEKIMORE_ALLOW_AGENT_FORWARD=1 — the AI can use the operator's keys)"
  else
    {
      echo ""
      echo "❌ ERROR: 依頼者の ssh-agent がこの dev コンテナに転送されています (SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset})"
      echo "   relay 構成では AI に依頼者の鍵を渡してはいけません。原因は VS Code Dev Containers 拡張で、"
      echo "   ホストの VS Code に SSH_AUTH_SOCK があると無条件に転送します (無効化設定なし: vscode-remote-release#11413)。"
      echo ""
      echo "   対処: VS Code に SSH_AUTH_SOCK を見せずに起動してください。"
      echo "     ターミナルから:       mise run vscode   (= env -u SSH_AUTH_SOCK code <このプロジェクトのパス>)"
      echo "     Dock/Spotlight から:  launchctl unsetenv SSH_AUTH_SOCK   (Docker Desktop は先に起動しておく。gateway の agent はそこから渡る)"
      echo "   その後 'Dev Containers: Reopen in Container' で開き直し、dev 内で 'ssh-add -l' が失敗することを確認してください。"
      echo "   一時的に許容する場合のみ SEKIMORE_ALLOW_AGENT_FORWARD=1 (非推奨)。"
      echo ""
    } >&2
    exit 1
  fi
fi

echo "✅ post-create done. Open a new terminal to pick up zsh settings."
