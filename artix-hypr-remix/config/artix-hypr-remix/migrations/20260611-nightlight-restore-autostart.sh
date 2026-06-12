#!/usr/bin/env bash
# Migration: add ahr-restore-nightlight exec-once to hyprland.conf.
# This ensures nightlight state is restored across reboots on existing installs.
set -euo pipefail

hyprland_conf="$HOME/.config/hypr/hyprland.conf"
timestamp="$(date +%Y%m%d-%H%M%S)"

if [[ ! -f "$hyprland_conf" ]]; then
  echo "Skipping: hyprland.conf not found at $hyprland_conf"
  exit 0
fi

NEW_LINE='exec-once = bash ~/.config/artix-hypr-remix/bin/ahr-restore-nightlight'

# Idempotency: only skip if an active uncommented exec-once line exists
if grep -qE '^[[:space:]]*exec-once[[:space:]]*=.*ahr-restore-nightlight' "$hyprland_conf" 2>/dev/null; then
  echo "ahr-restore-nightlight exec-once already present — skipping"
  exit 0
fi

echo "Adding ahr-restore-nightlight exec-once to $hyprland_conf"

# Timestamped backup
backup_file="${hyprland_conf}.bak.${timestamp}"
cp "$hyprland_conf" "$backup_file"
echo "Backup saved: $backup_file"

# Try to find a good insertion point, with fallbacks.
# The insertion line is appended immediately after the matched line.
inserted=false

# Anchor 1: hook.sh post-boot line (flexible whitespace, optional trailing comment)
if grep -qE '^[[:space:]]*exec-once[[:space:]]*=.*hook\.sh[[:space:]]+post-boot' "$hyprland_conf" 2>/dev/null; then
  sed -i '/^[[:space:]]*exec-once[[:space:]]*=.*hook\.sh[[:space:]]\+post-boot/a\'"$NEW_LINE" "$hyprland_conf"
  inserted=true
  echo "Inserted after hook.sh post-boot line"
fi

# Anchor 2: # Autostart section header
if [[ "$inserted" == "false" ]] && grep -qE '^[[:space:]]*#[[:space:]]*Autostart' "$hyprland_conf" 2>/dev/null; then
  sed -i '/^[[:space:]]*#[[:space:]]*Autostart/a\'"$NEW_LINE" "$hyprland_conf"
  inserted=true
  echo "Inserted after '# Autostart' section header"
fi

# Anchor 3: first exec-once line (any)
# Use line-number insertion, not a sed range with a (which duplicates).
if [[ "$inserted" == "false" ]] && grep -qE '^[[:space:]]*exec-once' "$hyprland_conf" 2>/dev/null; then
  first_exec_line="$(grep -nE '^[[:space:]]*exec-once[[:space:]]*=' "$hyprland_conf" | head -n1 | cut -d: -f1)"
  sed -i "${first_exec_line}a\\${NEW_LINE}" "$hyprland_conf"
  inserted=true
  echo "Inserted after first exec-once line (line $first_exec_line)"
fi

# Anchor 4: append before the last non-blank line (near end of file)
if [[ "$inserted" == "false" ]]; then
  # Count lines, insert before the last line (usually root closing brace or blank)
  total_lines=$(wc -l < "$hyprland_conf")
  insert_at=$((total_lines - 1))
  sed -i "${insert_at}a\\${NEW_LINE}" "$hyprland_conf"
  inserted=true
  echo "Appended near end of file (no suitable anchor found)"
fi

# Verify: check for an active uncommented line (same pattern as idempotency check)
if grep -qE '^[[:space:]]*exec-once[[:space:]]*=.*ahr-restore-nightlight' "$hyprland_conf" 2>/dev/null; then
  echo "Successfully added ahr-restore-nightlight exec-once"
else
  echo "ERROR: insertion failed — restoring backup" >&2
  cp "$backup_file" "$hyprland_conf"
  exit 1
fi
