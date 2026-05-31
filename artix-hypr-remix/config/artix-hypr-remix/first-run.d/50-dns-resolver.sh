#!/usr/bin/env bash
set -euo pipefail

if command -v resolvconf >/dev/null 2>&1; then
  echo "OpenRC resolver detected (resolvconf); leaving /etc/resolv.conf managed by resolvconf"
  exit 0
fi

if command -v nmcli >/dev/null 2>&1; then
  echo "NetworkManager detected; leaving /etc/resolv.conf managed by network stack"
  exit 0
fi

echo "Skipping DNS resolver setup: no OpenRC resolver manager detected; leaving /etc/resolv.conf unchanged"
