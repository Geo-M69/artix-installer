# Artix Hypr Remix zsh baseline
export ZDOTDIR="$HOME/.config/zsh"

# AHR namespace commands (ahr, ahr-theme, ahr-menu, etc.) are in ~/.local/bin
# Individual ahr-* commands are directly accessible from the framework bin dir
export PATH="$HOME/.config/artix-hypr-remix/bin:$HOME/.local/bin:$PATH"

export EDITOR="hx"
export TERMINAL="ghostty"

# User override via ahr-default-editor (writes ~/.config/artix-hypr-remix/env)
[[ -f "$HOME/.config/artix-hypr-remix/env" ]] && source "$HOME/.config/artix-hypr-remix/env"

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
