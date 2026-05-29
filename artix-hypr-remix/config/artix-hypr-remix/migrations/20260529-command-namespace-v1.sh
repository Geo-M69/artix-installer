#!/usr/bin/env bash
set -euo pipefail

installer="$HOME/.config/artix-hypr-remix/bin/namespace-install.sh"

if [[ ! -f "$installer" ]]; then
  echo "Skipping command namespace migration: installer not found"
  exit 0
fi

bash "$installer" --quiet
