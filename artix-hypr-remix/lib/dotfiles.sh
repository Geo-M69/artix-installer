#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

backup_path_if_exists() {
  local target_path="$1"
  local dry_run="${2:-false}"
  local backup_path

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    return 0
  fi

  backup_path="${target_path}.bak.$(date +%s)"
  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would back up $target_path -> $backup_path"
    return 0
  fi

  mv "$target_path" "$backup_path"
  info "Backed up $target_path -> $backup_path"
}

deploy_config_tree() {
  local source_config_dir="$1"
  local target_user="$2"
  local target_home="$3"
  local dry_run="${4:-false}"

  local target_config_dir="$target_home/.config"
  local entry entry_name destination

  if [[ ! -d "$source_config_dir" ]]; then
    warn "Config directory '$source_config_dir' does not exist"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would deploy $source_config_dir -> $target_config_dir"
  else
    install -d -m 0755 "$target_config_dir"
  fi

  shopt -s dotglob nullglob
  for entry in "$source_config_dir"/*; do
    entry_name="$(basename "$entry")"
    destination="$target_config_dir/$entry_name"

    backup_path_if_exists "$destination" "$dry_run"

    if [[ "$dry_run" == "true" ]]; then
      info "Dry-run: would copy $entry -> $destination"
      continue
    fi

    cp -a "$entry" "$destination"
    chown -R "$target_user:$target_user" "$destination"
    info "Installed config: $destination"
  done
  shopt -u dotglob nullglob

  if [[ "$dry_run" == "false" ]]; then
    chown "$target_user:$target_user" "$target_config_dir"
  fi
}
