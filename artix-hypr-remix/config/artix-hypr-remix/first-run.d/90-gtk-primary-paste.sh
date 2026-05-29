#!/usr/bin/env bash
set -euo pipefail

if ! command -v gsettings >/dev/null 2>&1; then
  echo "Skipping GTK primary paste setup: gsettings not found"
  exit 0
fi

gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true
