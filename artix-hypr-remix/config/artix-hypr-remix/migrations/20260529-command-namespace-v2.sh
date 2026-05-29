#!/usr/bin/env bash
set -euo pipefail

installer="$HOME/.config/artix-hypr-remix/bin/namespace-install.sh"
user_bin="$HOME/.local/bin"

if [[ ! -f "$installer" ]]; then
  echo "Skipping namespace v2 migration: installer not found: $installer"
  exit 0
fi

bash "$installer" --quiet

if [[ ! -e "$user_bin/ahr-migrate" ]]; then
  echo "Namespace v2 migration failed: missing $user_bin/ahr-migrate" >&2
  exit 1
fi

if [[ ! -e "$user_bin/omarchy-migrate" ]]; then
  echo "Namespace v2 migration failed: missing $user_bin/omarchy-migrate" >&2
  exit 1
fi

echo "Namespace v2 migration complete: migrate commands installed"
