#!/usr/bin/env bash
# ahr-backup-helper.sh — Shared backup-before-edit helper.
#
# Provides one consistent implementation of backup-before-edit for
# migrations, hooks, theme refresh, and repair commands.
#
# Source this file; do not execute directly.

# Create a timestamped backup of a file before modification.
# Arguments:
#   $1 — path to back up
#   $2 — backup directory (optional, defaults to STATE_ROOT/backups)
# Returns 0 on success, 1 on failure.
# Sets AHR_BACKUP_PATH to the created backup path.
ahr_backup_before_edit() {
  local src_path="$1"
  local backup_root="${2:-${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/backups}"
  AHR_BACKUP_PATH=""

  # Nothing to back up if source doesn't exist
  [[ -e "$src_path" ]] || return 0

  # Resolve the real path to prevent symlink traversal
  local real_src
  real_src="$(realpath "$src_path" 2>/dev/null)" || return 1

  # Determine the relative path for the backup
  local rel_path="${real_src#/}"
  local dest_dir="$backup_root/$(dirname "$rel_path")"
  mkdir -p "$dest_dir" || return 1

  local ts
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo 0)"
  local basename
  basename="$(basename "$src_path")"

  local backup_path
  if [[ -L "$src_path" ]]; then
    local link_target
    link_target="$(readlink "$src_path")" || return 1
    local link_parent
    link_parent="$(mktemp -d --tmpdir="$dest_dir" ".${basename}.ahr-backup.${ts}.XXXXXX")" || return 1
    chmod 700 "$link_parent" 2>/dev/null || true
    backup_path="$link_parent/$basename"
    ln -s "$link_target" "$backup_path"
  elif [[ -f "$src_path" ]]; then
    backup_path="$(mktemp --tmpdir="$dest_dir" "${basename}.ahr-backup.${ts}.XXXXXX")" || return 1
    chmod 600 "$backup_path" 2>/dev/null || true
    cp -a "$src_path" "$backup_path" || return 1
  elif [[ -d "$src_path" ]]; then
    backup_path="$(mktemp -d --tmpdir="$dest_dir" "${basename}.ahr-backup.${ts}.XXXXXX")" || return 1
    chmod 700 "$backup_path" 2>/dev/null || true
    cp -aT "$src_path" "$backup_path" || return 1
  else
    return 1
  fi

  AHR_BACKUP_PATH="$backup_path"
  return 0
}

# Create a timestamped backup of a directory tree before modification.
# Arguments:
#   $1 — directory to back up
#   $2 — backup root directory
# Returns 0 on success, 1 on failure.
# Sets AHR_BACKUP_DIR to the created backup directory.
ahr_backup_dir_before_edit() {
  local src_dir="$1"
  local backup_root="${2:-${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/backups}"
  AHR_BACKUP_DIR=""

  [[ -d "$src_dir" ]] || return 0

  local real_src
  real_src="$(realpath "$src_dir" 2>/dev/null)" || return 1

  local rel_path="${real_src#/}"
  local dest_dir="$backup_root/$(dirname "$rel_path")"
  mkdir -p "$dest_dir" || return 1

  local ts
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo 0)"
  local basename
  basename="$(basename "$src_dir")"
  local backup_path
  backup_path="$(mktemp -d --tmpdir="$dest_dir" "${basename}.ahr-backup.${ts}.XXXXXX")" || return 1
  chmod 700 "$backup_path" 2>/dev/null || true

  cp -aT "$src_dir" "$backup_path" || return 1

  AHR_BACKUP_DIR="$backup_path"
  return 0
}

# Append one component snapshot result. Component names are unique per manifest.
_ahr_component_manifest_record() {
  local manifest="$1"
  local comp_name="$2"
  local source_path="$3"
  local snapshot_path="$4"
  local shape="$5"
  local required="$6"
  local ownership="$7"
  local restore_policy="$8"
  local snapshot_status="$9"
  local diagnostic="${10:-}"

  if [[ -f "$manifest" ]] && grep -qxF "component=$comp_name" "$manifest"; then
    return 1
  fi

  {
    printf 'component=%s\n' "$comp_name"
    printf 'source_path=%s\n' "$source_path"
    printf 'snapshot_path=%s\n' "$snapshot_path"
    printf 'shape=%s\n' "$shape"
    printf 'required=%s\n' "$required"
    printf 'ownership=%s\n' "$ownership"
    printf 'restore_policy=%s\n' "$restore_policy"
    printf 'snapshot_status=%s\n' "$snapshot_status"
    [[ -n "$diagnostic" ]] && printf 'diagnostic=%s\n' "$diagnostic"
    printf '%s\n' '---'
  } >> "$manifest"
}

# Snapshot a managed component into a framework backup directory.
# Arguments:
#   $1 — component name
#   $2 — source path (absolute)
#   $3 — backup directory (the framework backup dir)
#   $4 — shape (file|directory|symlink|structured-file|state|manifest)
#   $5 — required flag (optional, defaults false)
#   $6 — ownership classification (optional)
#   $7 — restore policy (optional)
# Returns 0 on success, 1 on required absence/failure or duplicate record.
# Appends a record to $3/component-manifest.txt.
ahr_snapshot_component() {
  local comp_name="$1"
  local src_path="$2"
  local backup_dir="$3"
  local shape="$4"
  local required="${5:-false}"
  local ownership="${6:-unknown}"
  local restore_policy="${7:-unsupported}"

  local manifest="$backup_dir/component-manifest.txt"
  local snap_dir="$backup_dir/snapshots"

  mkdir -p "$snap_dir"

  if [[ ! -e "$src_path" && ! -L "$src_path" ]]; then
    _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
      "$required" "$ownership" "$restore_policy" "absent" || return 1
    [[ "$required" == "true" ]] && return 1
    return 0
  fi

  case "$shape" in
    structured-file|state|manifest)
      _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
        "$required" "$ownership" "$restore_policy" "unsupported" || return 1
      [[ "$required" == "true" ]] && return 1
      return 0
      ;;
  esac

  local snap_path="$snap_dir/$comp_name"
  case "$shape" in
    file)
      if [[ -f "$src_path" ]]; then
        mkdir -p "$(dirname "$snap_path")"
        if ! cp -a "$src_path" "$snap_path"; then
          _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
            "$required" "$ownership" "$restore_policy" "failed" "copy_failed" || return 1
          return 1
        fi
      else
        _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
          "$required" "$ownership" "$restore_policy" "failed" "shape_mismatch" || return 1
        return 1
      fi
      ;;
    directory)
      if [[ -d "$src_path" ]]; then
        if ! cp -a "$src_path" "$snap_path"; then
          _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
            "$required" "$ownership" "$restore_policy" "failed" "copy_failed" || return 1
          return 1
        fi
      else
        _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
          "$required" "$ownership" "$restore_policy" "failed" "shape_mismatch" || return 1
        return 1
      fi
      ;;
    symlink)
      if [[ -L "$src_path" ]]; then
        local lt
        lt="$(readlink "$src_path")" || return 1
        mkdir -p "$(dirname "$snap_path")"
        if ! ln -s "$lt" "$snap_path"; then
          _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
            "$required" "$ownership" "$restore_policy" "failed" "copy_failed" || return 1
          return 1
        fi
      else
        _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
          "$required" "$ownership" "$restore_policy" "failed" "shape_mismatch" || return 1
        return 1
      fi
      ;;
    *)
      _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "" "$shape" \
        "$required" "$ownership" "$restore_policy" "unsupported" || return 1
      [[ "$required" == "true" ]] && return 1
      return 0
      ;;
  esac

  _ahr_component_manifest_record "$manifest" "$comp_name" "$src_path" "$snap_path" "$shape" \
    "$required" "$ownership" "$restore_policy" "present" || return 1
  return 0
}
