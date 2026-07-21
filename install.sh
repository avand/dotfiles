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

if [[ ! -f "$HOME/.zshrc.local" ]]; then
  cat > "$HOME/.zshrc.local" <<'TEMPLATE'
# Secrets and per-machine settings. Not committed — fill these in.
# export PORTAL_API_TOKEN=
# export CLOUDFLARE_TUNNEL_NAME=
TEMPLATE
  chmod 600 "$HOME/.zshrc.local"
  echo "created ~/.zshrc.local template — fill in your secrets"
fi
