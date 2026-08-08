export EDITOR="code --wait"
export VISUAL="$EDITOR"

setopt PROMPT_SUBST

autoload -Uz vcs_info

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' (%b)'

precmd() {
  vcs_info
}

# Folder and branch muted so the orange arrow carries the eye to what you type.
# 245 and 208 are 256-colour codes rather than hex, so they stay put when
# Ghostty flips between its light and dark themes.
PROMPT='%F{245}%1~${vcs_info_msg_0_}%f %F{208}%B→%b%f '

export PATH=/opt/homebrew/share/google-cloud-sdk/bin:"$PATH"
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate zsh)"

# Claude Code account separation (work = existing ~/.claude, personal = isolated)
alias claudew="CLAUDE_CONFIG_DIR=$HOME/.claude claude --permission-mode acceptEdits"
alias claudep="CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude --permission-mode acceptEdits"

# Secrets and per-machine settings — never committed. See README.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
