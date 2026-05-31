#!/usr/bin/env bash
set -euo pipefail

FRAMEWORK_ROOT="$HOME/.config/artix-hypr-remix"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"
FIRST_RUN_MODE="$STATE_DIR/first-run.mode"
LOG_FILE="$STATE_DIR/first-run.log"
TASK_STATE_DIR="$STATE_DIR/first-run.tasks"
TASK_DIR="$FRAMEWORK_ROOT/first-run.d"
HOOK_INSTALLER="$FRAMEWORK_ROOT/bin/hook-install.sh"
VOXTYPE_HOOK="$FRAMEWORK_ROOT/hooks/install-voxtype.hook"
FIRST_RUN_SUDOERS_FILE="/etc/sudoers.d/99-artix-hypr-remix-first-run"

log_line() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

run_task() {
  local task_script="$1"
  local task_name

  task_name="$(basename "$task_script")"
  log_line "Running first-run task: $task_name"

  if bash "$task_script" >> "$LOG_FILE" 2>&1; then
    log_line "Completed first-run task: $task_name"
    return 0
  fi

  log_line "Failed first-run task: $task_name"
  return 1
}

task_done_path() {
  local task_name="$1"
  printf '%s/%s.done\n' "$TASK_STATE_DIR" "$task_name"
}

task_is_done() {
  local task_name="$1"
  [[ -f "$(task_done_path "$task_name")" ]]
}

mark_task_done() {
  local task_name="$1"
  touch "$(task_done_path "$task_name")"
}

mkdir -p "$STATE_DIR"
mkdir -p "$TASK_STATE_DIR"
touch "$LOG_FILE"

if [[ ! -f "$FIRST_RUN_MODE" ]]; then
  exit 0
fi

log_line "First-run mode detected"

first_run_complete=true

if [[ -d "$TASK_DIR" ]]; then
  shopt -s nullglob
  for task_script in "$TASK_DIR"/*.sh; do
    task_name="$(basename "$task_script")"

    if task_is_done "$task_name"; then
      log_line "Skipping completed first-run task: $task_name"
      continue
    fi

    if run_task "$task_script"; then
      mark_task_done "$task_name"
      continue
    fi

    first_run_complete=false
    break
  done
  shopt -u nullglob
else
  log_line "Task directory not found: $TASK_DIR"
fi

if [[ "$first_run_complete" == "true" && -f "$HOOK_INSTALLER" && -f "$VOXTYPE_HOOK" ]]; then
  log_line "Installing post-update voxtype hook"
  if ! bash "$HOOK_INSTALLER" post-update "$VOXTYPE_HOOK" >> "$LOG_FILE" 2>&1; then
    log_line "Failed to install post-update voxtype hook"
    first_run_complete=false
  fi
fi

if [[ "$first_run_complete" != "true" ]]; then
  log_line "First-run framework incomplete; mode marker preserved for retry"
  exit 1
fi

rm -f "$FIRST_RUN_MODE"

if command -v sudo >/dev/null 2>&1; then
  sudo /bin/rm -f "$FIRST_RUN_SUDOERS_FILE" >/dev/null 2>&1 || true
fi

log_line "First-run framework completed"
