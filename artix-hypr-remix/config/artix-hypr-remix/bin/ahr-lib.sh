#!/usr/bin/env bash
set -euo pipefail

ahr_trim() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

ahr_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ahr_desktop_entry_exists() {
  local desktop_id="$1"
  local path

  [[ -n "$desktop_id" ]] || return 1

  for path in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$desktop_id" \
    "$HOME/.local/share/flatpak/exports/share/applications/$desktop_id" \
    "/var/lib/flatpak/exports/share/applications/$desktop_id" \
    "/usr/local/share/applications/$desktop_id" \
    "/usr/share/applications/$desktop_id"; do
    if [[ -f "$path" ]]; then
      return 0
    fi
  done

  return 1
}

ahr_read_first_noncomment_line() {
  local file_path="$1"
  local line

  [[ -f "$file_path" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(ahr_trim "$line")"
    [[ -n "$line" ]] || continue
    printf '%s\n' "$line"
    return 0
  done < "$file_path"

  return 1
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

ahr_terminal_preference_file() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"
}

ahr_terminal_id_is_available() {
  local desktop_id="$1"

  case "$desktop_id" in
    com.mitchellh.ghostty.desktop)
      ahr_has_cmd ghostty || ahr_desktop_entry_exists "$desktop_id"
      ;;
    foot.desktop)
      ahr_has_cmd foot || ahr_desktop_entry_exists "$desktop_id"
      ;;
    kitty.desktop)
      ahr_has_cmd kitty || ahr_desktop_entry_exists "$desktop_id"
      ;;
    Alacritty.desktop)
      ahr_has_cmd alacritty || ahr_desktop_entry_exists "$desktop_id"
      ;;
    xterm.desktop)
      ahr_has_cmd xterm || ahr_desktop_entry_exists "$desktop_id"
      ;;
    *)
      return 1
      ;;
  esac
}

ahr_exec_terminal_by_id() {
  local desktop_id="$1"
  shift || true

  case "$desktop_id" in
    com.mitchellh.ghostty.desktop)
      ahr_has_cmd ghostty && exec ghostty "$@"
      ;;
    foot.desktop)
      ahr_has_cmd foot && exec foot "$@"
      ;;
    kitty.desktop)
      ahr_has_cmd kitty && exec kitty "$@"
      ;;
    Alacritty.desktop)
      ahr_has_cmd alacritty && exec alacritty "$@"
      ;;
    xterm.desktop)
      ahr_has_cmd xterm && exec xterm "$@"
      ;;
  esac

  return 1
}

ahr_exec_terminal_app_by_id() {
  local desktop_id="$1"
  local app="$2"
  shift 2 || true

  case "$desktop_id" in
    com.mitchellh.ghostty.desktop)
      ahr_has_cmd ghostty && exec ghostty -e "$app" "$@"
      ;;
    foot.desktop)
      ahr_has_cmd foot && exec foot "$app" "$@"
      ;;
    kitty.desktop)
      ahr_has_cmd kitty && exec kitty "$app" "$@"
      ;;
    Alacritty.desktop)
      ahr_has_cmd alacritty && exec alacritty -e "$app" "$@"
      ;;
    xterm.desktop)
      ahr_has_cmd xterm && exec xterm -e "$app" "$@"
      ;;
  esac

  return 1
}

ahr_exec_terminal() {
  local preferred_id=""
  local term_file

  term_file="$(ahr_terminal_preference_file)"
  preferred_id="$(ahr_read_first_noncomment_line "$term_file" 2>/dev/null || true)"

  if [[ -n "$preferred_id" ]] && ahr_terminal_id_is_available "$preferred_id"; then
    ahr_exec_terminal_by_id "$preferred_id" "$@"
  fi

  ahr_exec_terminal_by_id "com.mitchellh.ghostty.desktop" "$@" ||
    ahr_exec_terminal_by_id "foot.desktop" "$@" ||
    ahr_exec_terminal_by_id "kitty.desktop" "$@" ||
    ahr_exec_terminal_by_id "Alacritty.desktop" "$@" ||
    ahr_exec_terminal_by_id "xterm.desktop" "$@"

  return 1
}

ahr_exec_terminal_app() {
  local app="$1"
  local preferred_id=""
  local term_file
  shift || true

  term_file="$(ahr_terminal_preference_file)"
  preferred_id="$(ahr_read_first_noncomment_line "$term_file" 2>/dev/null || true)"

  if [[ -n "$preferred_id" ]] && ahr_terminal_id_is_available "$preferred_id"; then
    ahr_exec_terminal_app_by_id "$preferred_id" "$app" "$@"
  fi

  ahr_exec_terminal_app_by_id "com.mitchellh.ghostty.desktop" "$app" "$@" ||
    ahr_exec_terminal_app_by_id "foot.desktop" "$app" "$@" ||
    ahr_exec_terminal_app_by_id "kitty.desktop" "$app" "$@" ||
    ahr_exec_terminal_app_by_id "Alacritty.desktop" "$app" "$@" ||
    ahr_exec_terminal_app_by_id "xterm.desktop" "$app" "$@"

  return 1
}
