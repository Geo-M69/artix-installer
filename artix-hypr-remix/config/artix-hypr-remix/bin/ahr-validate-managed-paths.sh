#!/usr/bin/env bash
# ahr-validate-managed-paths.sh — Validate the managed-path inventory.
#
# Checks for:
#   - duplicate component/path entries
#   - missing ownership classification
#   - missing shape
#   - supported restore without a restore_policy
#   - user-editable path without backup-before-edit policy
#   - required path without backup policy
#
# Exit codes:
#   0  All validations pass
#   1  One or more validations fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ahr-managed-paths.sh"

errors=0
warnings=0

# Check for duplicate component|path entries
declare -A seen_entries=()
for entry in "${MANAGED_PATHS[@]}"; do
  comp="$(echo "$entry" | cut -d'|' -f1)"
  path="$(echo "$entry" | cut -d'|' -f2)"
  key="$comp|$path"
  if [[ -n "${seen_entries[$key]+x}" ]]; then
    echo "ERROR: Duplicate entry: $comp -> $path" >&2
    errors=$((errors + 1))
  fi
  seen_entries["$key"]=1
done

# Validate each entry
for entry in "${MANAGED_PATHS[@]}"; do
  comp="$(echo "$entry" | cut -d'|' -f1)"
  path="$(echo "$entry" | cut -d'|' -f2)"
  shape="$(echo "$entry" | cut -d'|' -f3)"
  writer="$(echo "$entry" | cut -d'|' -f4)"
  ownership="$(echo "$entry" | cut -d'|' -f5)"
  user_editable="$(echo "$entry" | cut -d'|' -f6)"
  backup_policy="$(echo "$entry" | cut -d'|' -f7)"
  restore_policy="$(echo "$entry" | cut -d'|' -f8)"
  required="$(echo "$entry" | cut -d'|' -f9)"

  # Validate ownership
  case "$ownership" in
    framework-owned|managed-derived|user-editable|external|unsupported) ;;
    *)
      echo "ERROR: Invalid ownership '$ownership' for $comp -> $path" >&2
      errors=$((errors + 1))
      ;;
  esac

  # Validate shape
  case "$shape" in
    file|directory|symlink|fragment|structured-file) ;;
    *)
      echo "ERROR: Invalid shape '$shape' for $comp -> $path" >&2
      errors=$((errors + 1))
      ;;
  esac

  # Validate backup policy
  case "$backup_policy" in
    snapshot|backup-before-edit|none) ;;
    *)
      echo "ERROR: Invalid backup_policy '$backup_policy' for $comp -> $path" >&2
      errors=$((errors + 1))
      ;;
  esac

  # Validate restore policy
  case "$restore_policy" in
    full-replace|merge|manual|unsupported) ;;
    *)
      echo "ERROR: Invalid restore_policy '$restore_policy' for $comp -> $path" >&2
      errors=$((errors + 1))
      ;;
  esac

  # User-editable paths must have backup-before-edit policy
  if [[ "$user_editable" == "true" && "$backup_policy" != "backup-before-edit" ]]; then
    echo "ERROR: user-editable $comp -> $path must have backup-before-edit policy (has: $backup_policy)" >&2
    errors=$((errors + 1))
  fi

  # Required paths must have a backup policy (not none)
  if [[ "$required" == "true" && "$backup_policy" == "none" ]]; then
    echo "ERROR: required $comp -> $path must have a backup policy" >&2
    errors=$((errors + 1))
  fi

  # Supported restore must have a restore policy
  if [[ "$restore_policy" == "full-replace" || "$restore_policy" == "merge" ]]; then
    if [[ "$backup_policy" == "none" ]]; then
      echo "WARNING: $comp -> $path supports restore but has no backup policy" >&2
      warnings=$((warnings + 1))
    fi
  fi
done

if (( errors > 0 )); then
  echo "Inventory validation failed: $errors errors, $warnings warnings" >&2
  exit 1
fi

if (( warnings > 0 )); then
  echo "Inventory validation passed with $warnings warnings" >&2
fi

echo "Inventory validation passed: ${#MANAGED_PATHS[@]} entries" >&2
exit 0
