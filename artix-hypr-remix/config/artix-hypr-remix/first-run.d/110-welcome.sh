#!/usr/bin/env bash
set -euo pipefail

if ! command -v notify-send >/dev/null 2>&1; then
  echo "Skipping welcome notification: notify-send not found"
  exit 0
fi

notify-send "Learn Keybindings" "Super + Space for application launcher.\nSuper + Return for terminal." -u critical
