#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  echo "Usage: hook-install.sh <type> <file>" >&2
  exit 1
fi

hook_type="$1"
hook_file="$2"
hook_dir="$HOME/.config/artix-hypr-remix/hooks/$hook_type.d"
hook_name="$(basename "$hook_file")"
hook_path="$hook_dir/$hook_name"

if [[ ! -f "$hook_file" ]]; then
  echo "Hook file not found: $hook_file" >&2
  exit 1
fi

mkdir -p "$hook_dir"
cp "$hook_file" "$hook_path"
chmod 0755 "$hook_path"

echo "Installed $hook_type hook: $hook_path"
