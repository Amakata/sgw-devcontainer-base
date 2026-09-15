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
# sekimore-relay guardrail: 操作者 (人間) の SSH 鍵 = ssh-agent は、この AI 用コンテナから使えてはいけない。
# relay 構成では GitHub への認証は sekimore-gw の中で行う。ここで ssh-agent が見えるなら鍵伝搬の反転が
# 成立していないので、エラーで止めて Mac 側の手順を案内する (design D-6)。
# VS Code Dev Containers 拡張は、VS Code 本体が ssh-agent を使える状態だと必ずコンテナへ転送する
# (止める設定なし: microsoft/vscode-remote-release#11413)。
# ---------------------------------------------------------------------------
if ssh-add -l >/dev/null 2>&1; then
  if [ "${SEKIMORE_ALLOW_AGENT_FORWARD:-0}" = "1" ]; then
    echo "⚠️  あなたの Mac の SSH 鍵 (ssh-agent) がこのコンテナから使える状態です。SEKIMORE_ALLOW_AGENT_FORWARD=1 のため続行しますが、AI があなたの鍵を使えます。"
  else
    {
      echo ""
      echo "❌ 起動を中止しました: あなたの Mac の SSH 鍵 (ssh-agent) が、この開発コンテナから使える状態になっています。"
      echo "   この構成では、コンテナ内の AI にあなたの鍵を使わせません。GitHub への認証は sekimore-gw が代わりに行います。"
      echo ""
      echo "   直し方 (Mac 側で、この順に):"
      echo "     1. VS Code を Cmd+Q で完全に終了する"
      echo "     2. Terminal.app で実行する (VS Code の中のターミナルは不可):"
      echo "          cd <このプロジェクトのフォルダ> && mise run vscode"
      echo "        → VS Code が「SSH 鍵を使えない状態」で起動します"
      echo "     3. その VS Code で「Dev Containers: Reopen in Container」を実行する"
      echo "     4. 確認: コンテナ内で ssh-add -l が失敗 (Could not open a connection to your authentication agent) すれば OK"
      echo ""
      echo "   なぜ: VS Code の Dev Containers 拡張は、VS Code 自身が SSH 鍵を使える状態だとコンテナへ必ず転送します (止める設定なし)。"
      echo "        mise run vscode は VS Code だけに SSH 鍵を見せずに起動します。Docker Desktop (sekimore-gw に鍵を渡す側) には影響しません。"
      echo "   一時的に無視して起動したい場合: .devcontainer/.env に SEKIMORE_ALLOW_AGENT_FORWARD=1 を書いて Rebuild (非推奨)"
      echo ""
    } >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# sekimore-relay guardrail (その 2): HTTPS git が依頼者の GitHub 認証を借りる経路を塞ぐ。
# VS Code Dev Containers 拡張は 2 つの経路を仕込む:
#   (a) git の credential.helper を /etc/gitconfig と ~/.gitconfig に書く
#   (b) GIT_ASKPASS + VSCODE_GIT_IPC_HANDLE を各シェルの環境に注入する (git の HTTP Basic 認証で使う)
# どちらも https://github.com/... の clone/push を関所を迂回して依頼者の権限で通してしまう。
# relay 構成では git は関所の SSH 経由に限りたいので両方を無効化する。git@github.com (SSH) は影響なし。
#   - (a) はここで消す (devcontainer.json では無効化できない。拡張が毎回書くので起動ごとに打ち消す)
#   - (b) は rc.d/70-sekimore.zsh が GIT_ASKPASS='' にして無力化する (対話シェル)。
#         非対話の tool 呼び出し向けに、ここで git の core.askpass は空にできないため
#         (env が勝つ)、helper を消すことと SSH 経路への一本化で守る。
# 一時的に元へ戻すなら SEKIMORE_ALLOW_CREDENTIAL_HELPER=1。
# ---------------------------------------------------------------------------
disable_vscode_credential_helper() {
  local scope changed=0 cur sudo_cmd
  for scope in system global; do
    cur=$(git config --"$scope" --get-all credential.helper 2>/dev/null || true)
    case "$cur" in
      *vscode-remote-containers*|*vscode-server*)
        # system スコープ (/etc/gitconfig) は root 所有なので sudo が要る。無ければ諦めるが、
        # GIT_ASKPASS の無力化 (rc.d) で HTTPS 認証自体は塞がっているので致命的ではない
        sudo_cmd=""
        if [ "$scope" = system ] && [ ! -w /etc/gitconfig ]; then
          command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null && sudo_cmd="sudo"
        fi
        $sudo_cmd git config --"$scope" --unset-all credential.helper 2>/dev/null || true
        $sudo_cmd git config --"$scope" credential.helper "" 2>/dev/null || true
        changed=1 ;;
    esac
  done
  [ "$changed" = 1 ] && echo "[agent] relay: disabled the VS Code HTTPS git credential helper (git は関所の SSH 経由に。SEKIMORE_ALLOW_CREDENTIAL_HELPER=1 で残せる)"
}
if [ "${SEKIMORE_ALLOW_CREDENTIAL_HELPER:-0}" != "1" ]; then
  disable_vscode_credential_helper
fi

echo "✅ post-create done. Open a new terminal to pick up zsh settings."
