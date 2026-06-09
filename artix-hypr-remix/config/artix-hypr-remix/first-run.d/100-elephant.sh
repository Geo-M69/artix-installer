#!/usr/bin/env bash
set -euo pipefail

if ! command -v elephant >/dev/null 2>&1; then
  echo "Skipping elephant setup: elephant command not found"
  exit 0
fi

# Deploy AHR elephant plugins
AHR_FRAMEWORK="${AHR_FRAMEWORK:-$HOME/.config/artix-hypr-remix}"
ELEPHANT_PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/elephant/plugins"

if [[ -d "$AHR_FRAMEWORK/default/walker" ]]; then
  install -d -m 0755 "$ELEPHANT_PLUGIN_DIR"
  for plugin in "$AHR_FRAMEWORK/default/walker"/*.lua; do
    [[ -f "$plugin" ]] || continue
    plugin_name="$(basename "$plugin")"
    if [[ ! -e "$ELEPHANT_PLUGIN_DIR/$plugin_name" ]]; then
      ln -sfn "$plugin" "$ELEPHANT_PLUGIN_DIR/$plugin_name"
      echo "  elephant plugin deployed: $plugin_name"
    fi
  done
fi

elephant service enable || true
elephant service start || true
