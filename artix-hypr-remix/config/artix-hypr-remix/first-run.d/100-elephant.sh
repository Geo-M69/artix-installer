#!/usr/bin/env bash
set -euo pipefail

if ! command -v elephant >/dev/null 2>&1; then
  echo "Skipping elephant setup: elephant command not found"
  exit 0
fi

elephant service enable || true
elephant service start || true
