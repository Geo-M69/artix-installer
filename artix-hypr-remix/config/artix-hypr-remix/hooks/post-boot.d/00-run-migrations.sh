#!/usr/bin/env bash
set -euo pipefail

runner="$HOME/.config/artix-hypr-remix/bin/migrate.sh"

if [[ -f "$runner" ]]; then
  bash "$runner"
fi
