# dotfiles

Shell, Ghostty, VS Code, and Claude Code config — apps installed, files
symlinked into place.

## New machine

```bash
bash -c "$(curl -fsSL https://bootstrap.avand.dev)"
```

That installs the Xcode command line tools and Homebrew, clones this repo to
`~/dotfiles`, and runs `install.sh`. Nothing needs to be set up first.

Use that form rather than `curl … | bash`. Piping puts the script itself on
stdin, which leaves the Homebrew installer and its sudo prompt with no terminal
to read from, and it hangs.

If Homebrew and git are already there, skip straight to:

```bash
git clone https://github.com/avand/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Both are safe to re-run. Anything already installed is left alone, and an app
you put there by hand still counts as installed.

## What gets installed

| package               | kind    | skipped when                              |
| --------------------- | ------- | ----------------------------------------- |
| `ghostty`             | cask    | `/Applications/Ghostty.app` exists        |
| `visual-studio-code`  | cask    | `/Applications/Visual Studio Code.app` exists |
| `1password`           | cask    | `/Applications/1Password.app` exists      |
| `font-jetbrains-mono` | cask    | JetBrains Mono Medium is installed        |
| `gh`                  | formula | `gh` is on PATH                           |
| `mise`                | formula | `mise` is on PATH or in `~/.local/bin`    |
| Claude Code           | own installer | `claude` is on PATH or in `~/.local/bin` |

Claude Code isn't a Homebrew package — it ships its own installer, which puts
it in `~/.local`. `zshrc` already has that on PATH, which is what makes the
`claudew` and `claudep` aliases work.

VS Code extensions listed in `vscode-extensions.txt` are installed too. To add
one, install it normally and then:

```bash
code --list-extensions > ~/dotfiles/vscode-extensions.txt
```

## What gets linked

| repo file                 | links to                                  |
| ------------------------- | ----------------------------------------- |
| `zshrc`                   | `~/.zshrc`                                |
| `claude-statusline.sh`    | `~/.claude/statusline.sh`                 |
| `claude-settings.json`    | `~/.claude/settings.json`                 |
| `ghostty-config`          | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| `vscode-settings.json`    | `~/Library/Application Support/Code/User/settings.json` |
| `mise-config.toml`        | `~/.config/mise/config.toml`              |
| `gh-config.yml`           | `~/.config/gh/config.yml`                 |

An existing real file at any of those paths is moved aside to `*.backup` rather
than overwritten.

## Left to do by hand

Three things need credentials, so they can't be scripted. `install.sh` prints
this list when it finishes:

1. `gh auth login`
2. Sign in to 1Password
3. Run `claude` once and log in — then `claudep` for the personal account
4. Fill in `~/.zshrc.local`

## Ghostty

All of Ghostty's settings live in that one config file — there's no separate
preferences pane holding anything back. The font is the exception: Ghostty
bundles a copy of JetBrains Mono, but not the Medium weight the config asks
for, so the real family gets installed.

After editing the config, reload with `cmd+shift+,` or restart Ghostty.

## What isn't synced

**1Password settings.** They live in an encrypted local database tied to your
account, not a config file. Signing in restores them.

**gh credentials.** `gh` keeps its token in the macOS keychain, and would
otherwise keep it in `~/.config/gh/hosts.yml`. Only `config.yml` — aliases and
preferences — is in this repo. `hosts.yml` is gitignored as a backstop.

**Ruby.** `mise-config.toml` currently pins only `node = "latest"`. Add a
`ruby` line there if you want it managed the same way.

## bootstrap.avand.dev

`bootstrap-worker/` is a Cloudflare Worker that serves `bootstrap.sh` as plain
text. It proxies the file from GitHub rather than embedding it, so editing
`bootstrap.sh` here is enough — no redeploy needed.

```bash
cd bootstrap-worker
npx wrangler login    # once, opens a browser
npx wrangler deploy
```

`custom_domain = true` in `wrangler.toml` makes Cloudflare create the DNS
record for `bootstrap.avand.dev`, so there's nothing to add in the dashboard.

## Secrets

**This repo is public — never commit a credential to it.**

Secrets and per-machine settings live in `~/.zshrc.local`, which is not in this
repo and must be re-created by hand on each machine. `zshrc` sources it if it
exists; `install.sh` writes a template listing the variables to fill in.
