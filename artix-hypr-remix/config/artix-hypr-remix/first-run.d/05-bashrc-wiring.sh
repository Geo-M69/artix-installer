#!/usr/bin/env bash
set -euo pipefail

# Ensure ~/.bashrc sources the deployed config so ahr PATH and EDITOR
# overrides from config/bash/.bashrc are picked up by interactive shells.
# This runs as a standalone first-run task so it fires even on existing
# installs where 56-default-apps.sh.done already exists.

ensure_bashrc_sources_deployed_config() {
  local deployed="$HOME/.config/bash/.bashrc"
  local target="$HOME/.bashrc"

  [[ -f "$deployed" ]] || return 0

  if [[ ! -f "$target" ]]; then
    printf '%s\n' "# Artix Hypr Remix shell configuration" > "$target"
    printf '%s\n' "source \"$deployed\"" >> "$target"
    echo "Created $target sourcing AHR bash config"
    return 0
  fi

  if grep -qsF "source \"$deployed\"" "$target" 2>/dev/null; then
    return 0
  fi

  printf '\n%s\n' "# Artix Hypr Remix shell configuration" >> "$target"
  printf '%s\n' "source \"$deployed\"" >> "$target"
  echo "Added AHR bash config source to $target"
}

ensure_zshrc_sources_deployed_config() {
  local deployed="$HOME/.config/zsh/.zshrc"
  local target="$HOME/.zshrc"

  [[ -f "$deployed" ]] || return 0

  if [[ ! -f "$target" ]]; then
    printf '%s\n' "# Artix Hypr Remix shell configuration" > "$target"
    printf '%s\n' "source \"$deployed\"" >> "$target"
    echo "Created $target sourcing AHR zsh config"
    return 0
  fi

  if grep -qsF "source \"$deployed\"" "$target" 2>/dev/null; then
    return 0
  fi

  printf '\n%s\n' "# Artix Hypr Remix shell configuration" >> "$target"
  printf '%s\n' "source \"$deployed\"" >> "$target"
  echo "Added AHR zsh config source to $target"
}

ensure_bashrc_sources_deployed_config
ensure_zshrc_sources_deployed_config
