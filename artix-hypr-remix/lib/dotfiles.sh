#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

backup_path_if_exists() {
  local target_path="$1"
  local dry_run="${2:-false}"
  local backup_path counter timestamp

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    return 0
  fi

  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="${target_path}.bak.$timestamp"
  counter=1
  while [[ -e "$backup_path" || -L "$backup_path" ]]; do
    backup_path="${target_path}.bak.$timestamp.$counter"
    counter=$((counter + 1))
  done

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would back up $target_path -> $backup_path"
    return 0
  fi

  mv "$target_path" "$backup_path"
  if declare -p AHR_CREATED_BACKUPS >/dev/null 2>&1; then
    AHR_CREATED_BACKUPS+=("$backup_path")
  fi
  info "Backed up $target_path -> $backup_path"
}

collect_existing_config_destinations() {
  local source_config_dir="$1"
  local target_home="$2"
  local target_config_dir="$target_home/.config"
  local entry entry_name destination

  if [[ ! -d "$source_config_dir" ]]; then
    return 0
  fi

  shopt -s dotglob nullglob
  for entry in "$source_config_dir"/*; do
    entry_name="$(basename "$entry")"
    destination="$target_config_dir/$entry_name"

    if [[ -e "$destination" || -L "$destination" ]]; then
      printf '%s\n' "$destination"
    fi
  done
  shopt -u dotglob nullglob
}

normalize_framework_bin_permissions() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local framework_bin_dir="$target_home/.config/artix-hypr-remix/bin"
  local file_path

  [[ -d "$framework_bin_dir" ]] || return 0

  shopt -s nullglob
  for file_path in "$framework_bin_dir"/*; do
    [[ -f "$file_path" ]] || continue

    if [[ "$dry_run" == "true" ]]; then
      info "Dry-run: would ensure executable bit on $file_path"
      continue
    fi

    chmod 0755 "$file_path"
    chown "$target_user:$target_user" "$file_path"
  done
  shopt -u nullglob
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

  normalize_framework_bin_permissions "$target_user" "$target_home" "$dry_run"
}

run_as_user() {
  local target_user="$1"
  shift

  if command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$target_user" "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- "$@"
    return
  fi

  error "Neither sudo nor runuser is available to run commands as '$target_user'"
}

initialize_xdg_user_dirs() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  if ! command -v xdg-user-dirs-update >/dev/null 2>&1; then
    warn "xdg-user-dirs-update is not available; skipping user directory initialization"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would initialize XDG user directories for '$target_user'"
    return 0
  fi

  info "Initializing XDG user directories for '$target_user'"
  run_as_user "$target_user" env HOME="$target_home" xdg-user-dirs-update
}
