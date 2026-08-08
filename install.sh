#!/usr/bin/env bash
# Symlink the dotfiles in this repo into place. Safe to re-run.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$repo/$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.backup"
    echo "backed up existing $dest -> $dest.backup"
  fi
  ln -sfn "$src" "$dest"
  echo "linked $dest"
}

link zshrc                "$HOME/.zshrc"
link claude-statusline.sh "$HOME/.claude/statusline.sh"
link claude-settings.json "$HOME/.claude/settings.json"
link ghostty-config       "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

# The Ghostty config asks for JetBrains Mono Medium, which the app doesn't bundle.
if ! ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi jetbrainsmono; then
  echo "JetBrains Mono not installed — run: brew install --cask font-jetbrains-mono"
fi

if [[ ! -f "$HOME/.zshrc.local" ]]; then
  cat > "$HOME/.zshrc.local" <<'TEMPLATE'
# Secrets and per-machine settings. Not committed — fill these in.
# export PORTAL_API_TOKEN=
# export CLOUDFLARE_TUNNEL_NAME=
TEMPLATE
  chmod 600 "$HOME/.zshrc.local"
  echo "created ~/.zshrc.local template — fill in your secrets"
fi
