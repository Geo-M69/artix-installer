#!/usr/bin/env bash
set -euo pipefail

if ! command -v elephant >/dev/null 2>&1; then
  echo "Skipping elephant setup: elephant command not found"
  exit 0
fi

elephant service enable || true

if command -v systemctl >/dev/null 2>&1 && systemctl --user list-unit-files 2>/dev/null | grep -q '^elephant.service'; then
  systemctl --user start elephant.service || true
fi
