#!/usr/bin/env bash
set -euo pipefail

theme_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-set"
default_theme="${AHR_DEFAULT_THEME:-artix-dark}"

if [[ ! -x "$theme_cmd" ]]; then
  echo "Skipping default theme setup: command not found: $theme_cmd"
  exit 0
fi

if ! "$theme_cmd" --quiet "$default_theme"; then
  echo "Skipping default theme setup: failed to apply $default_theme"
fi
