#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

STATE_DIR=""
STATE_DRY_RUN="false"

state_init() {
  local state_dir="$1"
  local dry_run="${2:-false}"

  STATE_DIR="$state_dir"
  STATE_DRY_RUN="$dry_run"

  if [[ "$STATE_DRY_RUN" == "true" ]]; then
    return 0
  fi

  mkdir -p "$STATE_DIR"
}

state_marker_file() {
  local phase="$1"
  local marker_kind="$2"

  printf '%s/phase-%s.%s\n' "$STATE_DIR" "$phase" "$marker_kind"
}

state_mark_phase_started() {
  local phase="$1"
  local marker_file

  marker_file="$(state_marker_file "$phase" "started")"

  if [[ "$STATE_DRY_RUN" == "true" ]]; then
    info "Dry-run: would mark phase $phase as started ($marker_file)"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$marker_file"
}

state_mark_phase_completed() {
  local phase="$1"
  local marker_file

  marker_file="$(state_marker_file "$phase" "completed")"

  if [[ "$STATE_DRY_RUN" == "true" ]]; then
    info "Dry-run: would mark phase $phase as completed ($marker_file)"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$marker_file"
}

state_phase_completed() {
  local phase="$1"

  [[ -f "$(state_marker_file "$phase" "completed")" ]]
}

state_last_completed_phase() {
  local max_phase="${1:-7}"
  local phase
  local last_completed=0

  for (( phase=1; phase<=max_phase; phase++ )); do
    if state_phase_completed "$phase"; then
      last_completed="$phase"
    fi
  done

  printf '%s\n' "$last_completed"
}
