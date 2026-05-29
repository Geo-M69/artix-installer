#!/usr/bin/env bash
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
  echo "Skipping swayosd setup: systemctl not found"
  exit 0
fi

if ! systemctl --user list-unit-files 2>/dev/null | grep -q '^swayosd-server.service'; then
  echo "Skipping swayosd setup: swayosd-server.service not found"
  exit 0
fi

systemctl --user daemon-reload || true
systemctl --user enable --now swayosd-server.service || true
