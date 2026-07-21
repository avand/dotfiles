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

## Secrets

**This repo is public — never commit a credential to it.**

Secrets and per-machine settings live in `~/.zshrc.local`, which is not in this
repo and must be re-created by hand on each machine. `zshrc` sources it if it
exists; `install.sh` writes a template listing the variables to fill in.
