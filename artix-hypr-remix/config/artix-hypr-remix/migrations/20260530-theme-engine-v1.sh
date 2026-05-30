#!/usr/bin/env bash
set -euo pipefail

installer="$HOME/.config/artix-hypr-remix/bin/namespace-install.sh"
theme_setter="$HOME/.config/artix-hypr-remix/bin/ahr-theme-set"
theme_refresher="$HOME/.config/artix-hypr-remix/bin/ahr-theme-refresh"
theme_state="$HOME/.config/artix-hypr-remix/current/theme.name"

default_theme="${AHR_DEFAULT_THEME:-artix-dark}"

if [[ -f "$installer" ]]; then
  bash "$installer" --quiet
fi

if [[ ! -x "$theme_setter" || ! -x "$theme_refresher" ]]; then
  echo "Skipping theme engine migration: theme commands not found"
  exit 0
fi

if [[ -s "$theme_state" ]]; then
  "$theme_refresher" --quiet
  echo "Theme engine migration complete: refreshed current theme"
  exit 0
fi

"$theme_setter" --quiet --skip-background "$default_theme"
echo "Theme engine migration complete: applied $default_theme"
