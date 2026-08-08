#!/usr/bin/env bash
# Install the apps this config assumes, then symlink the dotfiles in this repo
# into place. Safe to re-run.
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

# Install a cask unless it's already present. The check is a path rather than
# `brew list`, so a copy installed by hand counts and doesn't get clobbered.
# A failed install is a warning, not a hard stop — the symlinks below still run.
cask() {
  local name="$1" check="$2"
  if [[ -e "$check" ]]; then
    echo "$name already installed"
    return
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "skipped $name — install Homebrew first: https://brew.sh"
    return
  fi
  echo "installing $name..."
  brew install --cask "$name" || echo "WARNING: $name failed to install"
}

cask ghostty /Applications/Ghostty.app

# The Ghostty config asks for JetBrains Mono Medium. Ghostty bundles the family
# but not that weight, so the font has to be installed for real.
if [[ -e /Library/Fonts/JetBrainsMono-Medium.ttf ]]; then
  font_check=/Library/Fonts/JetBrainsMono-Medium.ttf
else
  font_check="$HOME/Library/Fonts/JetBrainsMono-Medium.ttf"
fi
cask font-jetbrains-mono "$font_check"

link zshrc                "$HOME/.zshrc"
link claude-statusline.sh "$HOME/.claude/statusline.sh"
link claude-settings.json "$HOME/.claude/settings.json"
link ghostty-config       "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

if [[ ! -f "$HOME/.zshrc.local" ]]; then
  cat > "$HOME/.zshrc.local" <<'TEMPLATE'
# Secrets and per-machine settings. Not committed — fill these in.
# export PORTAL_API_TOKEN=
# export CLOUDFLARE_TUNNEL_NAME=
TEMPLATE
  chmod 600 "$HOME/.zshrc.local"
  echo "created ~/.zshrc.local template — fill in your secrets"
fi

echo
echo "Done. Remaining by hand: fill in ~/.zshrc.local"
