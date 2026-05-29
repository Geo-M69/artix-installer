#!/usr/bin/env bash
set -euo pipefail

hypr_conf="$HOME/.config/hypr/hyprland.conf"

if [[ ! -f "$hypr_conf" ]]; then
  echo "Skipping GDK scale setup: $hypr_conf not found"
  exit 0
fi

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "Skipping GDK scale setup: hyprctl or jq not found"
  exit 0
fi

scale="$({ hyprctl monitors -j 2>/dev/null || true; } | jq -r 'if type == "array" and length > 0 then ((map(select(.focused == true))[0].scale) // .[0].scale // empty) else empty end' 2>/dev/null || true)"
if [[ -z "$scale" ]]; then
  echo "Skipping GDK scale setup: could not determine monitor scale"
  exit 0
fi

gdk_scale="$(awk -v s="$scale" 'BEGIN { if ((s + 0) >= 1.5) print 2; else print 1 }')"

if grep -q '^env = GDK_SCALE,' "$hypr_conf"; then
  sed -i -E "s/^env = GDK_SCALE,.*/env = GDK_SCALE,$gdk_scale/" "$hypr_conf"
else
  printf '\nenv = GDK_SCALE,%s\n' "$gdk_scale" >> "$hypr_conf"
fi
