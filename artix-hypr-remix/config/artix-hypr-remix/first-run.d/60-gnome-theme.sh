#!/usr/bin/env bash
set -euo pipefail

theme_refresh="$HOME/.config/artix-hypr-remix/bin/ahr-theme-refresh"

if [[ -x "$theme_refresh" ]]; then
  if "$theme_refresh" --quiet; then
    exit 0
  fi
fi

if ! command -v gsettings >/dev/null 2>&1; then
  echo "Skipping GNOME theme setup: gsettings not found"
  exit 0
fi

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface icon-theme "Yaru-blue"

if command -v sudo >/dev/null 2>&1 && [[ -d /usr/share/icons/Yaru ]]; then
  sudo gtk-update-icon-cache /usr/share/icons/Yaru || true
fi
