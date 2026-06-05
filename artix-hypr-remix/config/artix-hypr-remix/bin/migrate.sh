#!/usr/bin/env bash
set -euo pipefail

FRAMEWORK_ROOT="$HOME/.config/artix-hypr-remix"
MIGRATION_DIR="$FRAMEWORK_ROOT/migrations"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/migrations"
SKIPPED_DIR="$STATE_DIR/skipped"
LOCK_FILE="$STATE_DIR/migrate.lock"
LOCK_DIR="$STATE_DIR/.migrate.lock"
LOG_FILE="$STATE_DIR/migrate.log"

quiet=false
show_status=false
dry_run=false
retry_skipped=false
non_interactive=false
lock_mode=""

usage() {
  cat <<'EOF'
Usage: migrate.sh [options]

Options:
  --status           Print migration status without running migrations
  --dry-run          Show what would run, but do not apply migrations
  --retry-skipped    Retry migrations previously marked as skipped
  --non-interactive  Do not prompt to skip failed migrations
  --quiet            Reduce non-error output
  -h, --help         Show this help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --status) show_status=true ;;
    --dry-run) dry_run=true ;;
    --retry-skipped) retry_skipped=true ;;
    --non-interactive) non_interactive=true ;;
    --quiet) quiet=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

mkdir -p "$STATE_DIR" "$SKIPPED_DIR"
touch "$LOG_FILE"

log_line() {
  local message="$1"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$LOG_FILE"
}

log() {
  local message="$1"
  log_line "$message"
  if [[ "$quiet" == "false" ]]; then
    printf '%s\n' "$message"
  fi
}

cleanup_lock() {
  if [[ "$lock_mode" == "mkdir" ]]; then
    rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
}

acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      echo "Another migration run is already in progress." >&2
      exit 1
    fi
    lock_mode="flock"
    return 0
  fi

  if mkdir "$LOCK_DIR" >/dev/null 2>&1; then
    lock_mode="mkdir"
    return 0
  fi

  echo "Another migration run is already in progress." >&2
  exit 1
}

trap cleanup_lock EXIT

confirm_skip_failed_migration() {
  local migration_name="$1"
  local response

  if [[ "$non_interactive" == "true" || ! -t 0 ]]; then
    return 1
  fi

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

describe_status() {
  local total_count="$1"
  local applied_count="$2"
  local skipped_count="$3"
  local pending_count="$4"
  local skipped_file skipped_name

  log "Migration status: total=$total_count applied=$applied_count skipped=$skipped_count pending=$pending_count"

  if (( skipped_count > 0 )); then
    log "Skipped migrations need review before they are retried:"
    shopt -s nullglob
    for skipped_file in "$SKIPPED_DIR"/*.sh; do
      skipped_name="$(basename "$skipped_file")"
      log "  - ${skipped_name%.sh}"
    done
    shopt -u nullglob
    log "Retry skipped migrations with: ahr migrate --retry-skipped"
    log "Preview pending work with: ahr migrate --dry-run"
  fi
}

if [[ ! -d "$MIGRATION_DIR" ]]; then
  log "No migrations directory found: $MIGRATION_DIR"
  exit 0
fi

declare -a migration_files=()
declare -a pending_migrations=()
total_count=0
applied_count=0
skipped_count=0
pending_count=0

shopt -s nullglob
for migration_file in "$MIGRATION_DIR"/*.sh; do
  [[ -f "$migration_file" ]] || continue
  migration_files+=("$migration_file")
done
shopt -u nullglob

if (( ${#migration_files[@]} > 0 )); then
  mapfile -t migration_files < <(printf '%s\n' "${migration_files[@]}" | LC_ALL=C sort)
fi

total_count="${#migration_files[@]}"

for migration_file in "${migration_files[@]}"; do
  migration_name="$(basename "$migration_file")"

  if [[ -f "$STATE_DIR/$migration_name" || -f "$SKIPPED_DIR/$migration_name" ]]; then
    if [[ -f "$STATE_DIR/$migration_name" ]]; then
      ((applied_count+=1))
    else
      if [[ "$retry_skipped" == "true" ]]; then
        pending_migrations+=("$migration_file")
      else
        ((skipped_count+=1))
      fi
    fi
    continue
  fi

  pending_migrations+=("$migration_file")
done

pending_count="${#pending_migrations[@]}"

describe_status "$total_count" "$applied_count" "$skipped_count" "$pending_count"

if [[ "$show_status" == "true" ]]; then
  exit 0
fi

if [[ "$dry_run" == "true" ]]; then
  if (( ${#pending_migrations[@]} == 0 )); then
    log "Dry-run: no pending migrations"
    exit 0
  fi

  log "Dry-run: pending migrations"
  for migration_file in "${pending_migrations[@]}"; do
    log "  - $(basename "$migration_file")"
  done
  if [[ "$retry_skipped" == "true" ]]; then
    log "Dry-run includes previously skipped migrations because --retry-skipped was provided"
  fi
  exit 0
fi

if (( ${#pending_migrations[@]} == 0 )); then
  log "No pending migrations"
  exit 0
fi

acquire_lock

for migration_file in "${pending_migrations[@]}"; do
  migration_name="$(basename "$migration_file")"

  if [[ "$retry_skipped" == "true" ]]; then
    log "Retrying previously skipped migration if present: ${migration_name%.sh}"
    rm -f "$SKIPPED_DIR/$migration_name"
  fi

  log "Running migration: ${migration_name%.sh}"

  if bash "$migration_file"; then
    touch "$STATE_DIR/$migration_name"
    rm -f "$SKIPPED_DIR/$migration_name"
    log "Completed migration: ${migration_name%.sh}"
    continue
  fi

  if confirm_skip_failed_migration "$migration_name"; then
    touch "$SKIPPED_DIR/$migration_name"
    log "Skipped failed migration: ${migration_name%.sh}"
    log "Retry later with: ahr migrate --retry-skipped"
  else
    log "Migration failed: ${migration_name%.sh}"
    log "Review log: $LOG_FILE"
    exit 1
  fi
done

log "Migration run completed"
