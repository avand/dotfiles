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

have_brew() { command -v brew >/dev/null 2>&1; }

# Install something unless it's already present. The presence check is a path or
# a command rather than `brew list`, so a copy installed by hand still counts and
# doesn't get clobbered — which is how most of these landed on the first machine.
# A failed install warns and keeps going, so the symlinks below still happen.
install_pkg() {
  local kind="$1" name="$2"
  if ! have_brew; then
    echo "skipped $name — install Homebrew first: https://brew.sh"
    return
  fi
  echo "installing $name..."
  if [[ "$kind" == cask ]]; then
    brew install --cask "$name" || echo "WARNING: $name failed to install"
  else
    brew install "$name" || echo "WARNING: $name failed to install"
  fi
}

cask() {
  local name="$1" check="$2"
  if [[ -e "$check" ]]; then echo "$name already installed"; return; fi
  install_pkg cask "$name"
}

formula() {
  local name="$1" cmd="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then echo "$name already installed"; return; fi
  install_pkg formula "$name"
}

# --- apps -------------------------------------------------------------------

cask ghostty              /Applications/Ghostty.app
cask visual-studio-code   "/Applications/Visual Studio Code.app"
cask 1password            /Applications/1Password.app

# The Ghostty config asks for JetBrains Mono Medium. Ghostty bundles the family
# but not that weight, so the font has to be installed for real.
if [[ -e /Library/Fonts/JetBrainsMono-Medium.ttf ]]; then
  font_check=/Library/Fonts/JetBrainsMono-Medium.ttf
else
  font_check="$HOME/Library/Fonts/JetBrainsMono-Medium.ttf"
fi
cask font-jetbrains-mono "$font_check"

formula gh

# mise may have come from its own installer rather than brew, which puts it in
# ~/.local/bin — on PATH via zshrc, but not necessarily this script's PATH.
if command -v mise >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/mise" ]]; then
  echo "mise already installed"
else
  install_pkg formula mise
fi

# Claude Code has its own installer rather than a brew package — it installs
# into ~/.local, which zshrc already puts on PATH. Without it the claudew and
# claudep aliases point at a command that doesn't exist.
if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
  echo "claude already installed"
else
  echo "installing claude..."
  curl -fsSL https://claude.ai/install.sh | bash || echo "WARNING: claude failed to install"
fi

# --- config -----------------------------------------------------------------

link zshrc                "$HOME/.zshrc"
link claude-statusline.sh "$HOME/.claude/statusline.sh"
link claude-settings.json "$HOME/.claude/settings.json"
# claudep (personal account) uses an isolated CLAUDE_CONFIG_DIR — see zshrc —
# so it needs its own copies of the same links.
link claude-statusline.sh "$HOME/.claude-personal/statusline.sh"
link claude-settings.json "$HOME/.claude-personal/settings.json"
link ghostty-config       "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
link vscode-settings.json "$HOME/Library/Application Support/Code/User/settings.json"
link mise-config.toml     "$HOME/.config/mise/config.toml"
link gh-config.yml        "$HOME/.config/gh/config.yml"

# VS Code extensions. `code` lands on PATH via the cask, but a hand-installed
# copy may only have the binary inside the app bundle.
code_cli=""
if command -v code >/dev/null 2>&1; then
  code_cli=code
elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  code_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi

if [[ -n "$code_cli" ]]; then
  installed="$("$code_cli" --list-extensions 2>/dev/null || true)"
  while read -r ext; do
    [[ -z "$ext" ]] && continue
    if grep -qxF "$ext" <<<"$installed"; then
      echo "extension $ext already installed"
    else
      echo "installing extension $ext..."
      "$code_cli" --install-extension "$ext" >/dev/null || echo "WARNING: $ext failed to install"
    fi
  done < "$repo/vscode-extensions.txt"
else
  echo "skipped VS Code extensions — no code CLI found"
fi

"$repo/macos-defaults.sh"

if [[ ! -f "$HOME/.zshrc.local" ]]; then
  cat > "$HOME/.zshrc.local" <<'TEMPLATE'
# Secrets and per-machine settings. Not committed — fill these in.
# export PORTAL_API_TOKEN=
# export CLOUDFLARE_TUNNEL_NAME=
TEMPLATE
  chmod 600 "$HOME/.zshrc.local"
  echo "created ~/.zshrc.local template — fill in your secrets"
fi

cat <<'DONE'

Done. Left to do by hand — these need credentials, so they can't be scripted:
  1. gh auth login
  2. Sign in to 1Password
  3. Run `claude` once and log in (repeat with claudep for the personal account)
  4. Fill in ~/.zshrc.local
DONE
