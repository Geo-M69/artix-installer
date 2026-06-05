#!/usr/bin/env bash
set -euo pipefail

# Ensure AHR namespace commands (ahr, ahr-theme, ahr-menu, etc.) are in PATH
# for the entire Hyprland session, including Waybar and keybind-triggered scripts.
export PATH="$HOME/.local/bin:$PATH"

hypr_config="${HYPRLAND_CONFIG:-$HOME/.config/hypr/hyprland.conf}"

if [[ ! -f "$hypr_config" ]]; then
  echo "Hyprland config not found: $hypr_config" >&2
  exit 1
fi

if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session Hyprland --config "$hypr_config"
fi

exec Hyprland --config "$hypr_config"
