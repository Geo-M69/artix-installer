#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 )); then
  echo "Usage: hook.sh <name> [args...]" >&2
  exit 1
fi

hook_name="$1"
shift

hook_path="$HOME/.config/artix-hypr-remix/hooks/$hook_name"
hook_dir="$hook_path.d"

if [[ -f "$hook_path" ]]; then
  bash "$hook_path" "$@" || echo "Hook failed: $hook_path" >&2
fi

if [[ -d "$hook_dir" ]]; then
  shopt -s nullglob
  for hook in "$hook_dir"/*; do
    [[ -f "$hook" ]] || continue
    [[ "$hook" == *.sample ]] && continue
    bash "$hook" "$@" || echo "Hook failed: $hook" >&2
  done
  shopt -u nullglob
fi
