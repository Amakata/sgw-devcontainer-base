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

echo "✅ post-create done. Open a new terminal to pick up zsh settings."
