# Minimal ~/.zshrc for the project
export ZDOTDIR="$HOME/.config/zsh"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
