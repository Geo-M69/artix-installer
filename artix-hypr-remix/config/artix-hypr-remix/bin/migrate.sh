#!/usr/bin/env bash
set -euo pipefail

FRAMEWORK_ROOT="$HOME/.config/artix-hypr-remix"
MIGRATION_DIR="$FRAMEWORK_ROOT/migrations"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/migrations"
SKIPPED_DIR="$STATE_DIR/skipped"

mkdir -p "$STATE_DIR" "$SKIPPED_DIR"

confirm_skip_failed_migration() {
  local migration_name="$1"
  local response

  if command -v gum >/dev/null 2>&1; then
    gum confirm "Migration ${migration_name%.sh} failed. Skip and continue?"
    return
  fi

  read -r -p "Migration ${migration_name%.sh} failed. Skip and continue? [y/N]: " response
  case "${response,,}" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ ! -d "$MIGRATION_DIR" ]]; then
  echo "No migrations directory found: $MIGRATION_DIR"
  exit 0
fi

shopt -s nullglob
for migration_file in "$MIGRATION_DIR"/*.sh; do
  migration_name="$(basename "$migration_file")"

  if [[ -f "$STATE_DIR/$migration_name" || -f "$SKIPPED_DIR/$migration_name" ]]; then
    continue
  fi

  echo "Running migration: ${migration_name%.sh}"

  if bash "$migration_file"; then
    touch "$STATE_DIR/$migration_name"
    continue
  fi

  if confirm_skip_failed_migration "$migration_name"; then
    touch "$SKIPPED_DIR/$migration_name"
  else
    exit 1
  fi
done
shopt -u nullglob
