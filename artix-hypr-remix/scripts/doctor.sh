#!/usr/bin/env bash
set -euo pipefail
echo "Running quick environment checks"
for cmd in pacman paru slurp grim hyprctl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK: $cmd"
  else
    echo "MISSING: $cmd"
  fi
done
