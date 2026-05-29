#!/usr/bin/env bash
set -euo pipefail

has_battery=false
for supply in /sys/class/power_supply/BAT*; do
  if [[ -e "$supply" ]]; then
    has_battery=true
    break
  fi
done

if ! command -v powerprofilesctl >/dev/null 2>&1; then
  echo "Skipping battery profile setup: powerprofilesctl not found"
  exit 0
fi

if [[ "$has_battery" == true ]]; then
  powerprofilesctl set balanced || true
else
  powerprofilesctl set performance || true
fi
