#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "Skipping internal monitor recovery: hyprctl not found"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Skipping internal monitor recovery: jq not found"
  exit 0
fi

all_monitors_json="$(hyprctl monitors all -j 2>/dev/null || true)"
if [[ -z "$all_monitors_json" ]]; then
  all_monitors_json="$(hyprctl monitors -j 2>/dev/null || true)"
fi

internal_monitor_name="$({
  printf '%s\n' "$all_monitors_json"
} | jq -r 'if type == "array" then (map(select(.name | test("^(eDP|LVDS|DSI)")))[0].name // empty) else empty end')"

if [[ -z "$internal_monitor_name" ]]; then
  echo "Skipping internal monitor recovery: no internal display connector detected"
  exit 0
fi

if hyprctl monitors -j 2>/dev/null | jq -e --arg name "$internal_monitor_name" 'if type == "array" then any(.[]; .name == $name) else false end' >/dev/null; then
  echo "Internal monitor already active: $internal_monitor_name"
  exit 0
fi

if hyprctl keyword monitor "$internal_monitor_name,preferred,auto,1" >/dev/null 2>&1; then
  echo "Recovered internal monitor: $internal_monitor_name"
  exit 0
fi

echo "Unable to recover internal monitor: $internal_monitor_name"
exit 0
