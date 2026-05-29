#!/usr/bin/env bash
set -euo pipefail

if ! command -v notify-send >/dev/null 2>&1; then
  echo "Skipping Wi-Fi/update notifications: notify-send not found"
  exit 0
fi

if ! ping -c3 -W1 1.1.1.1 >/dev/null 2>&1; then
  notify-send "Update System" "When you have internet, run updates." -u critical
  notify-send "Set Up Wi-Fi" "Use NetworkManager tray controls to connect." -u critical
else
  notify-send "Update System" "Internet is available. Run updates when ready." -u critical
fi
