#!/usr/bin/env bash
set -euo pipefail

if ! command -v swayosd-server >/dev/null 2>&1; then
  echo "Skipping swayosd setup: swayosd-server not found"
  exit 0
fi

if pgrep -x swayosd-server >/dev/null 2>&1; then
  echo "swayosd-server already running"
  exit 0
fi

setsid swayosd-server >/dev/null 2>&1 &
