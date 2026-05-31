#!/usr/bin/env bash
set -euo pipefail

resolver_stub="/run/systemd/resolve/stub-resolv.conf"

if command -v resolvconf >/dev/null 2>&1; then
  echo "OpenRC resolver detected (resolvconf); leaving /etc/resolv.conf managed by resolvconf"
  exit 0
fi

if [[ ! -e "$resolver_stub" ]]; then
  echo "Skipping DNS resolver setup: systemd-resolved stub not present"
  exit 0
fi

if [[ -L /etc/resolv.conf ]] && [[ "$(readlink /etc/resolv.conf)" == "$resolver_stub" ]]; then
  echo "DNS resolver already points to systemd-resolved stub"
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Skipping DNS resolver setup: sudo not found"
  exit 0
fi

if ! sudo -n true >/dev/null 2>&1; then
  echo "Skipping DNS resolver setup: sudo requires a password in non-interactive first-run"
  exit 0
fi

sudo ln -sf "$resolver_stub" /etc/resolv.conf
