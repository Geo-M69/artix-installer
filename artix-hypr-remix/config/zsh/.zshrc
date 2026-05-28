# Artix Hypr Remix zsh baseline
export ZDOTDIR="$HOME/.config/zsh"

export EDITOR="hx"
export TERMINAL="ghostty"

alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto'
alias cat='bat --style=plain'

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
