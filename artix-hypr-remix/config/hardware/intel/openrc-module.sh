#!/usr/bin/env bash
set -euo pipefail

dry_run="${1:-false}"
modules_load_file="/etc/modules-load.d/i915.conf"
modules_load_dir="$(dirname "$modules_load_file")"
modules_load_content='i915'

module_info() {
  printf '[hardware:intel] %s\n' "$*"
}

write_file_if_changed() {
  local path="$1"
  local content="$2"
  local current

  if [[ -f "$path" ]]; then
    current="$(cat "$path")"
    if [[ "$current" == "$content" ]]; then
      module_info "No change needed for $path"
      return 0
    fi
  fi

  if [[ "$dry_run" == "true" ]]; then
    module_info "Dry-run: would write $path"
    return 0
  fi

  printf '%s\n' "$content" > "$path"
  module_info "Updated $path"
}

if [[ "$dry_run" == "true" ]]; then
  module_info "Dry-run: evaluating Intel OpenRC module"
fi

if [[ "$dry_run" != "true" ]]; then
  mkdir -p "$modules_load_dir"
fi

write_file_if_changed "$modules_load_file" "$modules_load_content"
