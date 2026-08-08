# dotfiles

Shell, Ghostty, and Claude Code config — apps installed, files symlinked into
place.

## New machine

Install [Homebrew](https://brew.sh) and the Xcode command line tools
(`xcode-select --install`) first — those two can't bootstrap themselves. Then:

```bash
git clone https://github.com/avand/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

That installs Ghostty and JetBrains Mono, then links everything below. It's
safe to re-run: anything already installed is left alone, and an app you put
there by hand still counts as installed.

The only step left by hand is filling in `~/.zshrc.local` — see Secrets.

## What it installs

| cask                  | skipped when                       |
| --------------------- | ---------------------------------- |
| `ghostty`             | `/Applications/Ghostty.app` exists |
| `font-jetbrains-mono` | JetBrains Mono Medium is installed |

## What it links

| repo file                 | links to                     |
| ------------------------- | ---------------------------- |
| `zshrc`                   | `~/.zshrc`                   |
| `claude-statusline.sh`    | `~/.claude/statusline.sh`    |
| `claude-settings.json`    | `~/.claude/settings.json`    |
| `ghostty-config`          | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |

An existing real file at any of those paths is moved aside to `*.backup`
rather than overwritten.

## Ghostty

All of Ghostty's settings live in that one config file — there's no separate
preferences pane holding anything back. The font is the exception: Ghostty
bundles a copy of JetBrains Mono, but not the Medium weight the config asks
for, so `install.sh` installs the real family.

After editing the config, reload with `cmd+shift+,` or restart Ghostty.

## Secrets

**This repo is public — never commit a credential to it.**

Secrets and per-machine settings live in `~/.zshrc.local`, which is not in this
repo and must be re-created by hand on each machine. `zshrc` sources it if it
exists; `install.sh` writes a template listing the variables to fill in.
