#!/usr/bin/env bash
set -euo pipefail

# Source user env for AHR_THEME_OMARCHY_SEED, AHR_DEFAULT_THEME overrides.
env_file="${XDG_CONFIG_HOME:-$HOME/.config}/artix-hypr-remix/env"
[[ -f "$env_file" ]] && source "$env_file"

theme_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-set"
list_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-list"
seed_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-install-omarchy"
default_theme="${AHR_DEFAULT_THEME:-nord}"
fallback_theme="fallback"

if [[ ! -x "$theme_cmd" ]]; then
  echo "Skipping default theme setup: command not found: $theme_cmd"
  exit 0
fi

# If the preferred theme is already available, apply it directly.
if "$list_cmd" --raw 2>/dev/null | grep -qxF "$default_theme"; then
  if "$theme_cmd" --quiet "$default_theme"; then
    exit 0
  fi
fi

# Preferred theme not available — try to seed it from Omarchy.
# Only seed when the Omarchy seed is not explicitly disabled.
AHR_THEME_OMARCHY_SEED="${AHR_THEME_OMARCHY_SEED:-true}"
if [[ "$AHR_THEME_OMARCHY_SEED" == "true" && -x "$seed_cmd" ]]; then
  echo "Default theme $default_theme not found locally; seeding from Omarchy…"
  if "$seed_cmd" "$default_theme" >/dev/null 2>&1 && "$theme_cmd" --quiet "$default_theme"; then
    echo "Default theme $default_theme seeded and applied."
    exit 0
  fi
  echo "Seeding $default_theme failed; will use fallback theme."
fi

# Fall back to the bundled fallback theme (always available).
if "$list_cmd" --raw 2>/dev/null | grep -qxF "$fallback_theme"; then
  "$theme_cmd" --quiet "$fallback_theme"
  echo "Applied fallback theme: $fallback_theme"
else
  echo "WARNING: No theme available — even fallback theme is missing."
fi
