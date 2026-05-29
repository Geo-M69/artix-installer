#!/usr/bin/env bash
set -euo pipefail

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
