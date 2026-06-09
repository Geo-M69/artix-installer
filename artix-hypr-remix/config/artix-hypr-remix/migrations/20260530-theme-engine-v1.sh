#!/usr/bin/env bash
set -euo pipefail

installer="$HOME/.config/artix-hypr-remix/bin/namespace-install.sh"
theme_setter="$HOME/.config/artix-hypr-remix/bin/ahr-theme-set"
theme_refresher="$HOME/.config/artix-hypr-remix/bin/ahr-theme-refresh"
theme_state="$HOME/.config/artix-hypr-remix/current/theme.name"

default_theme="${AHR_DEFAULT_THEME:-nord}"

if [[ -f "$installer" ]]; then
  bash "$installer" --quiet
fi

if [[ ! -x "$theme_setter" || ! -x "$theme_refresher" ]]; then
  echo "Skipping theme engine migration: theme commands not found"
  exit 0
fi

list_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-list"

if [[ -s "$theme_state" ]]; then
  current_theme="$(cat "$theme_state")"
  # Only refresh if the current theme still exists (avoids failing on
  # stale artix-* names after the built-in themes were removed).
  if "$list_cmd" --raw 2>/dev/null | grep -qxF "$current_theme"; then
    "$theme_refresher" --quiet
    echo "Theme engine migration complete: refreshed current theme"
    exit 0
  fi
  echo "Migration: current theme '$current_theme' no longer available; applying default."
fi

# Try the configured default; if unavailable, fall back to the
# bundled fallback theme that is always present.
if "$list_cmd" --raw 2>/dev/null | grep -qxF "$default_theme"; then
  "$theme_setter" --quiet "$default_theme"
  echo "Theme engine migration complete: applied $default_theme"
elif "$list_cmd" --raw 2>/dev/null | grep -qxF 'fallback'; then
  "$theme_setter" --quiet fallback
  echo "Theme engine migration complete: applied fallback theme (${default_theme} unavailable)"
else
  echo "WARNING: No theme available for migration."
fi
