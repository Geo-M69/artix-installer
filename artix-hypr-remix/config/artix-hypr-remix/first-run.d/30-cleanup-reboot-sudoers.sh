#!/usr/bin/env bash
set -euo pipefail

reboot_sudoers_file="/etc/sudoers.d/99-artix-hypr-remix-installer-reboot"

if ! command -v sudo >/dev/null 2>&1; then
  echo "Skipping reboot sudoers cleanup: sudo not found"
  exit 0
fi

sudo /bin/rm -f "$reboot_sudoers_file" || true
