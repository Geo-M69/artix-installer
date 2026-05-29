#!/usr/bin/env bash
set -euo pipefail

resolver_stub="/run/systemd/resolve/stub-resolv.conf"

if [[ ! -e "$resolver_stub" ]]; then
  echo "Skipping DNS resolver setup: $resolver_stub not found"
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Skipping DNS resolver setup: sudo not found"
  exit 0
fi

sudo ln -sf "$resolver_stub" /etc/resolv.conf
