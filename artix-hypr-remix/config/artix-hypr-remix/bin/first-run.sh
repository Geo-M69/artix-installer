#!/usr/bin/env bash
set -euo pipefail

FRAMEWORK_ROOT="$HOME/.config/artix-hypr-remix"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"
FIRST_RUN_MODE="$STATE_DIR/first-run.mode"
LOG_FILE="$STATE_DIR/first-run.log"
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
  bash "$task_script" >> "$LOG_FILE" 2>&1
  log_line "Completed first-run task: $task_name"
}

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

if [[ ! -f "$FIRST_RUN_MODE" ]]; then
  exit 0
fi

log_line "First-run mode detected"
rm -f "$FIRST_RUN_MODE"

if [[ -d "$TASK_DIR" ]]; then
  shopt -s nullglob
  for task_script in "$TASK_DIR"/*.sh; do
    run_task "$task_script"
  done
  shopt -u nullglob
else
  log_line "Task directory not found: $TASK_DIR"
fi

if [[ -f "$HOOK_INSTALLER" && -f "$VOXTYPE_HOOK" ]]; then
  log_line "Installing post-update voxtype hook"
  bash "$HOOK_INSTALLER" post-update "$VOXTYPE_HOOK" >> "$LOG_FILE" 2>&1
fi

if command -v sudo >/dev/null 2>&1; then
  sudo /bin/rm -f "$FIRST_RUN_SUDOERS_FILE" >/dev/null 2>&1 || true
fi

log_line "First-run framework completed"
