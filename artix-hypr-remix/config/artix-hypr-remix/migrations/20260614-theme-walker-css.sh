#!/usr/bin/env bash
set -euo pipefail

# Migration: generate current/theme/walker.css for existing installs.
#
# The new walker.css.tpl template (added in Phase 3 of Omarchy menu parity)
# must be rendered by the theme engine. Fresh first-run handles this during
# theme apply, but existing installs with a current theme will not have
# current/theme/walker.css until templates are re-rendered.
#
# This migration runs a quiet theme refresh to generate the missing file.

theme_state="$HOME/.config/artix-hypr-remix/current/theme.name"
theme_refresher="$HOME/.config/artix-hypr-remix/bin/ahr-theme-refresh"
walker_css="$HOME/.config/artix-hypr-remix/current/theme/walker.css"

# Skip if no current theme is set (file must be non-empty, matching
# the convention in 20260530-theme-engine-v1.sh)
if [[ ! -s "$theme_state" ]]; then
  echo "Skipping: no current theme set"
  exit 0
fi

# Skip if walker.css already exists (idempotent)
if [[ -f "$walker_css" ]]; then
  echo "Skipping: current/theme/walker.css already exists"
  exit 0
fi

if [[ ! -x "$theme_refresher" ]]; then
  echo "Skipping: theme refresher not found at $theme_refresher"
  exit 0
fi

echo "Regenerating theme templates for Walker CSS parity..."
"$theme_refresher" --quiet
echo "Migration complete: current/theme/walker.css generated"
