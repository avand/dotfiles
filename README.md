# dotfiles

Shell and Claude Code config, symlinked into place.

```bash
gh repo clone avand/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

| repo file                 | links to                     |
| ------------------------- | ---------------------------- |
| `zshrc`                   | `~/.zshrc`                   |
| `claude-statusline.sh`    | `~/.claude/statusline.sh`    |
| `claude-settings.json`    | `~/.claude/settings.json`    |
| `ghostty-config`          | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |

## Ghostty

All of Ghostty's settings live in that one config file — there's no separate
preferences pane holding anything back. The one piece it can't carry is the
font itself:

```bash
brew install --cask font-jetbrains-mono
```

Ghostty bundles a copy of JetBrains Mono, but not the Medium weight the config
asks for, so install it for real. Reload with `cmd+shift+,` or restart Ghostty.

## Secrets

**This repo is public — never commit a credential to it.**

Secrets and per-machine settings live in `~/.zshrc.local`, which is not in this
repo and must be re-created by hand on each machine. `zshrc` sources it if it
exists; `install.sh` writes a template listing the variables to fill in.
