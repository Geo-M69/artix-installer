#!/usr/bin/env bash
set -euo pipefail

# Deliver the portal picker placement rules to existing user configurations
# without replacing their Hyprland configuration.  Fresh installs receive the
# same rules from config/hypr/hyprland.conf; this migration is the upgrade path.
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
target_file="$config_root/hypr/hyprland.conf"
managed_begin='# >>> AHR managed: hyprland-share-picker'
managed_end='# <<< AHR managed: hyprland-share-picker'
float_rule='windowrule = match:class ^(hyprland-share-picker)$, float on'
center_rule='windowrule = match:class ^(hyprland-share-picker)$, center on'

if [[ ! -f "$target_file" ]]; then
  echo "Skipping Hyprland share-picker migration: file not found: $target_file"
  exit 0
fi

has_float=false
has_center=false
grep -Fqx -- "$float_rule" "$target_file" && has_float=true
grep -Fqx -- "$center_rule" "$target_file" && has_center=true

if [[ "$has_float" == "true" && "$has_center" == "true" ]]; then
  echo "Hyprland share-picker rules already present"
  exit 0
fi

backup_file="$(mktemp "${target_file}.bak.XXXXXXXX")"
temp_file="$(mktemp "${target_file}.ahr-share-picker.XXXXXXXX")"

cleanup() {
  rm -f "$temp_file"
}
trap cleanup EXIT

cp -p "$target_file" "$backup_file"
{
  cat "$target_file"
  printf '\n%s\n' "$managed_begin"
  [[ "$has_float" == "true" ]] || printf '%s\n' "$float_rule"
  [[ "$has_center" == "true" ]] || printf '%s\n' "$center_rule"
  printf '%s\n' "$managed_end"
} > "$temp_file"

if ! grep -Fqx -- "$float_rule" "$temp_file" || ! grep -Fqx -- "$center_rule" "$temp_file"; then
  echo "Failed to prepare Hyprland share-picker rules; original configuration is unchanged" >&2
  exit 1
fi

if ! mv -f "$temp_file" "$target_file"; then
  echo "Failed to update $target_file; backup retained at $backup_file" >&2
  exit 1
fi

if ! grep -Fqx -- "$float_rule" "$target_file" || ! grep -Fqx -- "$center_rule" "$target_file"; then
  cp -p "$backup_file" "$target_file"
  echo "Hyprland share-picker verification failed; restored $target_file from $backup_file" >&2
  exit 1
fi

echo "Added missing Hyprland share-picker rules to $target_file"
echo "Backup written to $backup_file"
