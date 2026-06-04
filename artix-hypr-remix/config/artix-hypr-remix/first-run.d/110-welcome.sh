#!/usr/bin/env bash
set -euo pipefail

if ! command -v notify-send >/dev/null 2>&1; then
  echo "Skipping welcome notification: notify-send not found"
  exit 0
fi

notify-send "Welcome to Artix Hypr Remix" "Super + Space opens the menu.\nSuper + K shows keybindings.\nSuper + Return opens a terminal." -u critical
