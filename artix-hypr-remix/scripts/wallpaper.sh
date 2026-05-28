#!/usr/bin/env bash
set -euo pipefail
# Simple wallpaper setter (Hyprland / sway compatible placeholder)
if [ $# -eq 0 ]; then
  echo "Usage: $0 /path/to/wallpaper.jpg"
  exit 1
fi
WALLPAPER="$1"
if command -v swaybg >/dev/null 2>&1; then
  swaybg -i "$WALLPAPER" -m fill &
  echo "Wallpaper set with swaybg"
else
  echo "No supported wallpaper setter found"
fi
