#!/usr/bin/env bash
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
  echo "Skipping internal monitor recovery: systemctl not found"
  exit 0
fi

if ! systemctl --user list-unit-files 2>/dev/null | grep -q '^artix-hypr-remix-recover-internal-monitor.service'; then
  echo "Skipping internal monitor recovery: artix-hypr-remix-recover-internal-monitor.service not found"
  exit 0
fi

systemctl --user enable artix-hypr-remix-recover-internal-monitor.service || true
