export EDITOR="code --wait"
export VISUAL="$EDITOR"

setopt PROMPT_SUBST

autoload -Uz vcs_info

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' (%b)'

precmd() {
  vcs_info
}

PROMPT='%1~${vcs_info_msg_0_} → '

export PATH=/opt/homebrew/share/google-cloud-sdk/bin:"$PATH"
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate zsh)"

# Claude Code account separation (work = existing ~/.claude, personal = isolated)
alias claudew="CLAUDE_CONFIG_DIR=$HOME/.claude claude --permission-mode acceptEdits"
alias claudep="CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude --permission-mode acceptEdits"

# Secrets and per-machine settings — never committed. See README.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
