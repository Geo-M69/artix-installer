#!/usr/bin/env bash
set -euo pipefail

ahr_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ahr_notify() {
  local title="$1"
  local body="${2:-}"

  if ahr_has_cmd notify-send; then
    # Notifications are best-effort; headless sessions may not have a working bus.
    notify-send "$title" "$body" >/dev/null 2>&1 || true
  fi
}

ahr_fail() {
  local message="$1"
  printf '%s\n' "$message" >&2
  ahr_notify "artix-hypr-remix" "$message"
  exit 1
}

ahr_exec_terminal_app() {
  local app="$1"
  shift || true

  if ahr_has_cmd ghostty; then
    exec ghostty -e "$app" "$@"
  fi

  if ahr_has_cmd foot; then
    exec foot "$app" "$@"
  fi

  if ahr_has_cmd kitty; then
    exec kitty "$app" "$@"
  fi

  if ahr_has_cmd alacritty; then
    exec alacritty -e "$app" "$@"
  fi

  if ahr_has_cmd xterm; then
    exec xterm -e "$app" "$@"
  fi

  return 1
}
