#!/usr/bin/env bash
# macOS system preferences that don't fit the symlink model in install.sh —
# these are `defaults write` settings, not files, so they're applied by
# running this script rather than linking it into place. Safe to re-run.
set -euo pipefail

# Key Repeat: fastest (rightmost stop on the System Settings slider is 2).
defaults write NSGlobalDomain KeyRepeat -int 2

# Delay Until Repeat: second-shortest stop on the slider (15, 25, 35, 45, 60,
# 90, 120 — shortest is 15).
defaults write NSGlobalDomain InitialKeyRepeat -int 25

echo "macOS defaults applied — log out/in (or restart affected apps) for key repeat changes to take effect everywhere."
