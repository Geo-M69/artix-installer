#!/usr/bin/env bash
set -euo pipefail

# namespace-install.sh — Install AHR command namespace into ~/.local/bin.
#
# Conflict safety: refuses to overwrite unrelated user paths.
# Ownership: only overwrites paths provably owned by AHR.
# Transactional: rolls back every changed entry on failure.
# Snapshot: writes a versioned manifest for restore-component.
#
# Exit codes:
#   0  Success
#   1  Prevalidation or installation failure

quiet=false

if (( $# > 0 )); then
  case "$1" in
    --quiet) quiet=true ;;
    *)
      echo "Usage: namespace-install.sh [--quiet]" >&2
      exit 1
      ;;
  esac
  shift
fi

source_dir="${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/bin"
target_dir="${AHR_LOCAL_BIN:-$HOME/.local/bin}"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"
LIB_PATH="${AHR_LIB_PATH:-$source_dir/ahr-lib.sh}"
source "$LIB_PATH"

# ── Command and alias inventory ─────────────────────────────────────

declare -a commands=("${AHR_NAMESPACE_COMMANDS[@]}")
declare -a aliases=("${AHR_NAMESPACE_ALIASES[@]}")

# ── Output helpers ─────────────────────────────────────────────────

log() {
  if [[ "$quiet" == "false" ]]; then
    printf '%s\n' "$1"
  fi
}

# ── Ownership test ─────────────────────────────────────────────────

# A destination is AHR-owned only when:
#   1. It is a symlink pointing inside source_dir (canonical framework root)
#   2. It is a symlink pointing to a known AHR command inside target_dir
#   3. It is a symlink matching a known AHR compatibility alias
# Filename alone (e.g. ahr-*) is NOT proof of ownership.
is_ahr_owned() {
  local target_path="$1"
  [[ -L "$target_path" ]] || return 1
  local link_target
  link_target="$(readlink "$target_path" 2>/dev/null)" || return 1
  case "$link_target" in
    "$source_dir/"*) return 0 ;;
  esac
  # Check if it points to an AHR command in target_dir
  case "$link_target" in
    "$target_dir/ahr-"*|"$target_dir/ahr"|"$target_dir/omarchy-"*|"$target_dir/omarchy")
      return 0 ;;
  esac
  # Check if it matches a known alias target
  local alias_spec alias_name alias_target
  for alias_spec in "${aliases[@]}"; do
    alias_name="${alias_spec%%:*}"
    alias_target="${alias_spec##*:}"
    if [[ "$(basename "$target_path")" == "$alias_name" ]]; then
      local expected_target="$target_dir/$alias_target"
      if [[ "$link_target" == "$expected_target" ]]; then
        return 0
      fi
    fi
  done
  return 1
}

# ── Destination classification ─────────────────────────────────────

# Classifies a destination path and sets:
#   CLASS_TYPE: missing|correct_ahr|stale_ahr|alias|unrelated_symlink|unrelated_file|directory|special|broken
#   CLASS_DETAIL: human-readable description
classify_destination() {
  local dest_path="$1"
  local expected_target="$2"
  local dest_type="$3"

  CLASS_TYPE=""
  CLASS_DETAIL=""

  if [[ ! -e "$dest_path" && ! -L "$dest_path" ]]; then
    CLASS_TYPE="missing"
    CLASS_DETAIL="path does not exist"
    return 0
  fi

  if [[ -L "$dest_path" ]]; then
    local link_target
    link_target="$(readlink "$dest_path" 2>/dev/null)" || true
    if [[ -z "$link_target" ]]; then
      CLASS_TYPE="broken"
      CLASS_DETAIL="symlink target cannot be read"
      return 0
    fi
    # Check if target is reachable (not broken)
    if [[ ! -e "$dest_path" ]]; then
      # Broken symlink — check if it was AHR-owned
      if is_ahr_owned "$dest_path" 2>/dev/null; then
        CLASS_TYPE="stale_ahr"
        CLASS_DETAIL="broken AHR-owned symlink: $link_target"
      else
        CLASS_TYPE="broken"
        CLASS_DETAIL="broken unrelated symlink: $link_target"
      fi
      return 0
    fi
    # Live symlink — check if correct
    if [[ "$link_target" == "$expected_target" ]]; then
      CLASS_TYPE="correct_ahr"
      CLASS_DETAIL="correct symlink: $link_target"
      return 0
    fi
    # Check AHR ownership
    if is_ahr_owned "$dest_path" 2>/dev/null; then
      CLASS_TYPE="stale_ahr"
      CLASS_DETAIL="stale AHR symlink: $link_target -> $expected_target"
      return 0
    fi
    # Unrelated symlink
    CLASS_TYPE="unrelated_symlink"
    CLASS_DETAIL="unrelated symlink: $link_target"
    return 0
  fi

  # Not a symlink
  if [[ -d "$dest_path" ]]; then
    CLASS_TYPE="directory"
    CLASS_DETAIL="directory exists at destination"
    return 0
  fi

  if [[ -f "$dest_path" ]]; then
    CLASS_TYPE="unrelated_file"
    CLASS_DETAIL="regular file exists at destination"
    return 0
  fi

  # Special file (fifo, socket, device, etc.)
  CLASS_TYPE="special"
  CLASS_DETAIL="special file at destination"
  return 0
}

# ── Prevalidation ──────────────────────────────────────────────────

declare -a CONFLICTS=()
declare -A SEEN_DESTS=()

prevalidate_plan() {
  local link_name link_target dest_path source_path alias_spec alias_name alias_target
  CONFLICTS=()
  SEEN_DESTS=()

  # Validate all command sources and destinations
  for link_name in "${commands[@]}"; do
    source_path="$source_dir/$link_name"
    dest_path="$target_dir/$link_name"
    link_target="$source_path"

    # Check source exists
    if [[ ! -f "$source_path" ]]; then
      CONFLICTS+=("MISSING_SOURCE:$link_name:$source_path")
      continue
    fi

    # Check for duplicate destination
    if [[ -n "${SEEN_DESTS[$link_name]+x}" ]]; then
      CONFLICTS+=("DUPLICATE:$link_name:$dest_path")
      continue
    fi
    SEEN_DESTS["$link_name"]=1

    # Classify destination
    classify_destination "$dest_path" "$link_target" "command"
    case "$CLASS_TYPE" in
      missing|correct_ahr|stale_ahr)
        # Safe to proceed
        ;;
      unrelated_symlink|unrelated_file|directory|special|broken)
        CONFLICTS+=("CONFLICT:$link_name:$CLASS_TYPE:$CLASS_DETAIL:$dest_path")
        ;;
    esac
  done

  # Validate all alias destinations
  for alias_spec in "${aliases[@]}"; do
    alias_name="${alias_spec%%:*}"
    alias_target="${alias_spec##*:}"
    dest_path="$target_dir/$alias_name"
    link_target="$target_dir/$alias_target"

    # Check for duplicate destination
    if [[ -n "${SEEN_DESTS[$alias_name]+x}" ]]; then
      CONFLICTS+=("DUPLICATE:$alias_name:$dest_path")
      continue
    fi
    SEEN_DESTS["$alias_name"]=1

    # Check alias target exists (in current dir or will be created by command plan)
    if [[ ! -e "$target_dir/$alias_target" ]]; then
      # Check if target is in the command list (will be installed)
      local _target_is_planned=false
      local _cmd
      for _cmd in "${commands[@]}"; do
        if [[ "$alias_target" == "$_cmd" ]]; then
          _target_is_planned=true
          break
        fi
      done
      if [[ "$_target_is_planned" == "false" ]]; then
        CONFLICTS+=("MISSING_ALIAS_TARGET:$alias_name:$target_dir/$alias_target")
        continue
      fi
    fi

    # Classify destination
    classify_destination "$dest_path" "$link_target" "alias"
    case "$CLASS_TYPE" in
      missing|correct_ahr|stale_ahr)
        # Safe to proceed
        ;;
      unrelated_symlink|unrelated_file|directory|special|broken)
        CONFLICTS+=("CONFLICT:$alias_name:$CLASS_TYPE:$CLASS_DETAIL:$dest_path")
        ;;
    esac
  done

  if (( ${#CONFLICTS[@]} > 0 )); then
    return 1
  fi
  return 0
}

# ── Transactional installation ─────────────────────────────────────

# Parallel arrays for names, states, targets, and types.
# Each entry is encoded as: name$'\t'prior_type[$'\t'extra_data]
# prior_type: "absent" | "symlink" | "file" | "directory" | "special"
# For "symlink", extra_data is the exact original symlink target.
declare -a PRIOR_NAMES=()
declare -a PRIOR_TYPES=()
declare -a PRIOR_DATA=()

record_prior_state() {
  local dest_path="$1" link_name="$2"
  PRIOR_NAMES+=("$link_name")
  if [[ ! -e "$dest_path" && ! -L "$dest_path" ]]; then
    PRIOR_TYPES+=("absent")
    PRIOR_DATA+=("")
  elif [[ -L "$dest_path" ]]; then
    local lt
    lt="$(readlink "$dest_path" 2>/dev/null)" || lt=""
    PRIOR_TYPES+=("symlink")
    PRIOR_DATA+=("$lt")
  elif [[ -d "$dest_path" ]]; then
    PRIOR_TYPES+=("directory")
    PRIOR_DATA+=("")
  elif [[ -f "$dest_path" ]]; then
    PRIOR_TYPES+=("file")
    PRIOR_DATA+=("")
  else
    PRIOR_TYPES+=("special")
    PRIOR_DATA+=("")
  fi
}

rollback_prior_state() {
  local i link_name prior_type prior_data dest_path
  local rollback_errors=0
  local rollback_length=${#PRIOR_NAMES[@]}
  # Process in reverse order
  for (( i=rollback_length-1; i>=0; i-- )); do
    link_name="${PRIOR_NAMES[$i]}"
    prior_type="${PRIOR_TYPES[$i]}"
    prior_data="${PRIOR_DATA[$i]}"
    dest_path="$target_dir/$link_name"
    rm -f "$dest_path" 2>/dev/null || true
    case "$prior_type" in
      absent)
        # Link was absent before — just remove
        ;;
      symlink)
        if [[ -n "$prior_data" ]]; then
          ln -s "$prior_data" "$dest_path" 2>/dev/null || rollback_errors=$((rollback_errors + 1))
        fi
        ;;
      file)
        # Cannot restore file contents without a snapshot; leave removed
        rollback_errors=$((rollback_errors + 1))
        echo "Warning: cannot restore file $link_name (no snapshot available)" >&2
        ;;
      directory)
        # Cannot restore directory contents without a snapshot; leave removed
        rollback_errors=$((rollback_errors + 1))
        echo "Warning: cannot restore directory $link_name (no snapshot available)" >&2
        ;;
      special)
        # Cannot restore special files; leave removed
        rollback_errors=$((rollback_errors + 1))
        echo "Warning: cannot restore special file $link_name" >&2
        ;;
    esac
  done
  return $rollback_errors
}

apply_plan() {
  local link_name link_target dest_path source_path alias_spec alias_name alias_target
  local changed_paths=()

  mkdir -p "$target_dir"

  # Install commands
  for link_name in "${commands[@]}"; do
    source_path="$source_dir/$link_name"
    dest_path="$target_dir/$link_name"
    link_target="$source_path"

    [[ ! -f "$source_path" ]] && continue

    record_prior_state "$dest_path" "$link_name"
    rm -f "$dest_path" 2>/dev/null || true
    ln -s "$link_target" "$dest_path" || {
      log "Error: failed to create link $dest_path" >&2
      rollback_prior_state
      return 1
    }
    changed_paths+=("$dest_path")
    log "Installed command: $dest_path"
  done

  # Install aliases
  for alias_spec in "${aliases[@]}"; do
    alias_name="${alias_spec%%:*}"
    alias_target="${alias_spec##*:}"
    dest_path="$target_dir/$alias_name"
    link_target="$target_dir/$alias_target"

    [[ ! -e "$target_dir/$alias_target" ]] && continue

    record_prior_state "$dest_path" "$alias_name"
    rm -f "$dest_path" 2>/dev/null || true
    ln -s "$link_target" "$dest_path" || {
      log "Error: failed to create alias $dest_path" >&2
      rollback_prior_state
      return 1
    }
    changed_paths+=("$dest_path")
    log "Installed compatibility alias: $dest_path -> $alias_target"
  done

  # Verify all created links
  local link_path
  for link_path in "${changed_paths[@]}"; do
    if [[ ! -L "$link_path" ]] || [[ ! -e "$link_path" ]]; then
      log "Error: verification failed for $link_path — rolling back" >&2
      rollback_prior_state
      return 1
    fi
  done

  return 0
}

# ── Snapshot/manifest ──────────────────────────────────────────────

write_snapshot() {
  local snapshot_dir="$1"
  mkdir -p "$snapshot_dir"

  local manifest="$snapshot_dir/namespace-manifest.txt"
  {
    echo "format_version=1"
    echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    echo "framework_root=$source_dir"
    echo "local_bin=$target_dir"
    local link_name link_target dest_path alias_spec alias_name alias_target
    for link_name in "${commands[@]}"; do
      dest_path="$target_dir/$link_name"
      if [[ -L "$dest_path" ]]; then
        link_target="$(readlink "$dest_path" 2>/dev/null)" || continue
        printf 'link_name=%s\nlink_target=%s\nownership=command\nalias_type=false\nexisted=true\n---\n' "$link_name" "$link_target" >> "$manifest"
      fi
    done
    for alias_spec in "${aliases[@]}"; do
      alias_name="${alias_spec%%:*}"
      alias_target="${alias_spec##*:}"
      dest_path="$target_dir/$alias_name"
      if [[ -L "$dest_path" ]]; then
        link_target="$(readlink "$dest_path" 2>/dev/null)" || continue
        printf 'link_name=%s\nlink_target=%s\nownership=alias\nalias_type=true\nexisted=true\n---\n' "$alias_name" "$link_target" >> "$manifest"
      fi
    done
  } > "$manifest"
}

# ── Main ───────────────────────────────────────────────────────────

if ! prevalidate_plan; then
  echo "Prevalidation failed. Conflicts found:" >&2
  _conflict=""
  for _conflict in "${CONFLICTS[@]}"; do
    echo "  $_conflict" >&2
  done
  echo "No changes made." >&2
  exit 1
fi

if ! apply_plan; then
  echo "Installation failed and was rolled back." >&2
  exit 1
fi

# Write snapshot after successful installation
snapshot_dir="$STATE_ROOT/namespace-snapshots/current"
write_snapshot "$snapshot_dir"

log "Command namespace install complete"
