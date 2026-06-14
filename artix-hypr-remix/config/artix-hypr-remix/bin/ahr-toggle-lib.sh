#!/usr/bin/env bash
# Shared toggle state framework for Artix Hypr Remix.
# Provides a consistent interface for flag-file-based toggles
# under $XDG_STATE_HOME/artix-hypr-remix/toggles/.
#
# Pattern (matching Omarchy's omarchy-toggle / omarchy-toggle-enabled):
#   source ahr-toggle-lib.sh
#   ahr_toggle "nightlight" --enabled-notification "ON" --disabled-notification "OFF"
#   if ahr_toggle_enabled "nightlight"; then ...
#
# Requirements: ahr-lib.sh must be sourced first (provides ahr_notify, ahr_has_cmd).
set -euo pipefail

AHR_TOGGLE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/toggles"

# ── Helpers ────────────────────────────────────────────────────

# Print the toggle state directory (creates it if needed).
ahr_toggle_state_dir() {
  mkdir -p "$AHR_TOGGLE_STATE_DIR"
  printf '%s\n' "$AHR_TOGGLE_STATE_DIR"
}

# Return 0 if the named toggle is enabled (flag file exists), 1 otherwise.
# Usage: if ahr_toggle_enabled "nightlight"; then ...
ahr_toggle_enabled() {
  local name="$1"
  _ahr_toggle_validate_name "$name" || return 2
  [[ -f "$AHR_TOGGLE_STATE_DIR/$name" ]]
}

# Sanitise a toggle name: reject anything containing / or ..
# Returns 0 if valid, 1 if invalid.
_ahr_toggle_validate_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    printf 'ERROR: toggle name must not be empty\n' >&2
    return 1
  fi
  if [[ "$name" == */* ]] || [[ "$name" == *..* ]]; then
    printf 'ERROR: invalid toggle name: %s (names must not contain / or ..)\n' "$name" >&2
    return 1
  fi
  return 0
}

# Create the flag file for a toggle.
# Usage: ahr_toggle_set "nightlight" [--notification "Message"]
ahr_toggle_set() {
  local name="" notification=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --notification) notification="$2"; shift 2 ;;
      *) name="$1"; shift ;;
    esac
  done
  _ahr_toggle_validate_name "$name" || return 1
  mkdir -p "$AHR_TOGGLE_STATE_DIR"
  : > "$AHR_TOGGLE_STATE_DIR/$name"
  if [[ -n "$notification" ]]; then
    ahr_notify "artix-hypr-remix" "$notification"
  fi
}

# Remove the flag file for a toggle.
# Usage: ahr_toggle_unset "nightlight" [--notification "Message"]
ahr_toggle_unset() {
  local name="" notification=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --notification) notification="$2"; shift 2 ;;
      *) name="$1"; shift ;;
    esac
  done
  _ahr_toggle_validate_name "$name" || return 1
  rm -f "$AHR_TOGGLE_STATE_DIR/$name"
  if [[ -n "$notification" ]]; then
    ahr_notify "artix-hypr-remix" "$notification"
  fi
}

# Toggle a flag file on/off.  Returns 0 if now enabled, 1 if now disabled.
# Usage: ahr_toggle "nightlight" \
#   --enabled-notification "Nightlight enabled" \
#   --disabled-notification "Nightlight disabled"
ahr_toggle() {
  local name="" enabled_notification="" disabled_notification=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enabled-notification) enabled_notification="$2"; shift 2 ;;
      --disabled-notification) disabled_notification="$2"; shift 2 ;;
      *) name="$1"; shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    printf 'Usage: ahr_toggle <name> [--enabled-notification <text>] [--disabled-notification <text>]\n' >&2
    return 2
  fi

  if ahr_toggle_enabled "$name"; then
    ahr_toggle_unset "$name" --notification "$disabled_notification"
    return 1
  else
    ahr_toggle_set "$name" --notification "$enabled_notification"
    return 0
  fi
}

# List all toggle flags with their state.
# Output: one line per toggle, format: <name>  enabled|disabled
ahr_toggle_list() {
  mkdir -p "$AHR_TOGGLE_STATE_DIR"
  local name

  if [[ -d "$AHR_TOGGLE_STATE_DIR" ]]; then
    for f in "$AHR_TOGGLE_STATE_DIR"/*; do
      if [[ -f "$f" ]] && [[ ! -L "$f" ]]; then
        name="$(basename "$f")"
        printf '  %-30s enabled\n' "$name"
      fi
    done
  fi
}

# Output Waybar JSON for a named toggle.
# The caller is responsible for process-based authoritative checks
# (e.g. pgrep hypridle for idle lock); this function reads only the
# flag file.
# Usage: ahr_toggle_waybar_status <name> <icon-enabled> <icon-disabled> \
#   [<tooltip-enabled>] [<tooltip-disabled>]
ahr_toggle_waybar_status() {
  local name="$1"
  local icon_enabled="$2"
  local icon_disabled="$3"
  local tooltip_enabled="${4:-Enabled}"
  local tooltip_disabled="${5:-Disabled}"

  if ahr_toggle_enabled "$name"; then
    printf '{"text":"%s","class":"active","tooltip":"%s"}\n' "$icon_enabled" "$tooltip_enabled"
  else
    printf '{"text":"%s","class":"inactive","tooltip":"%s"}\n' "$icon_disabled" "$tooltip_disabled"
  fi
}
