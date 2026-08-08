#!/usr/bin/env bash
# Bare-metal setup for a new Mac. Installs the two things that can't install
# themselves — Xcode command line tools and Homebrew — then clones the dotfiles
# and hands off to install.sh.
#
#   bash -c "$(curl -fsSL https://bootstrap.avand.dev)"
#
# Use that form rather than `curl ... | bash`: piping puts the script on stdin,
# which leaves the Homebrew installer and the sudo prompt with no terminal to
# read from. Safe to re-run.
set -euo pipefail

REPO_URL="https://github.com/avand/dotfiles.git"
REPO_DIR="$HOME/dotfiles"

step() { printf '\n==> %s\n' "$1"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap is macOS-only." >&2
  exit 1
fi

step "Xcode command line tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "already installed"
else
  # Opens a GUI installer and returns immediately, so wait it out.
  xcode-select --install >/dev/null 2>&1 || true
  echo "accept the installer window that just opened; waiting..."
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  echo "installed"
fi

step "Homebrew"
if command -v brew >/dev/null 2>&1; then
  echo "already installed"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Homebrew isn't on PATH in this shell until zshrc is in place and a new shell
# starts, so load it directly for the rest of this run.
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$candidate" ]]; then
    eval "$("$candidate" shellenv)"
    break
  fi
done

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew still isn't on PATH — stopping here." >&2
  exit 1
fi

step "dotfiles"
if [[ -d "$REPO_DIR/.git" ]]; then
  echo "already cloned, pulling"
  git -C "$REPO_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

step "install.sh"
exec bash "$REPO_DIR/install.sh"
