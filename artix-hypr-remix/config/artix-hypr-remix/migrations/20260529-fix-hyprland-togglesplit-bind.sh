#!/usr/bin/env bash
set -euo pipefail

# Migrate legacy togglesplit binds to the dispatcher form supported on target systems.
target_file="$HOME/.config/hypr/hyprland.conf"

if [[ ! -f "$target_file" ]]; then
  echo "Skipping togglesplit migration: file not found: $target_file"
  exit 0
fi

temp_file="$(mktemp)"
backup_file="$target_file.bak.$(date +%s)"

cleanup() {
  rm -f "$temp_file"
}
trap cleanup EXIT

sed -E \
  -e 's|^([[:space:]]*bind[[:space:]]*=[[:space:]]*\$mod,[[:space:]]*j,[[:space:]]*)togglesplit([[:space:]]*(#.*)?)$|\1layoutmsg, togglesplit\2|' \
  -e 's|^([[:space:]]*bind[[:space:]]*=[[:space:]]*\$mod,[[:space:]]*j,[[:space:]]*)exec,[[:space:]]*hyprctl[[:space:]]+dispatch[[:space:]]+togglesplit([[:space:]]*(#.*)?)$|\1layoutmsg, togglesplit\2|' \
  "$target_file" > "$temp_file"

if cmp -s "$target_file" "$temp_file"; then
  echo "No togglesplit migration changes needed"
  exit 0
fi

cp "$target_file" "$backup_file"
mv "$temp_file" "$target_file"

echo "Updated togglesplit bind in $target_file"
echo "Backup written to $backup_file"
