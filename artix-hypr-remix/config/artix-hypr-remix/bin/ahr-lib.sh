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

# Canonical command-namespace inventory.  Namespace installation and
# historical namespace restoration both use this single inventory so a
# snapshot name is never trusted solely because it matches a filename pattern.
declare -a AHR_NAMESPACE_COMMANDS=(
  ahr ahr-toggle ahr-toggle-lib.sh ahr-menu ahr-menu-keybindings ahr-theme
  ahr-theme-install-omarchy ahr-theme-list ahr-theme-current ahr-theme-set
  ahr-theme-refresh ahr-theme-bg-next ahr-theme-bg-set ahr-theme-bg-switcher
  ahr-theme-bg-install ahr-theme-bg-gallery ahr-theme-set-templates
  ahr-theme-colors-from-alacritty ahr-launch-terminal ahr-launch-apps
  ahr-launch-browser ahr-launch-files ahr-launch-audio ahr-launch-bluetooth
  ahr-launch-wifi ahr-default-browser ahr-default-terminal ahr-update
  ahr-update-available ahr-update-framework ahr-restore-component ahr-repair
  ahr-status ahr-list-backups ahr-voxtype-model ahr-voxtype-config
  ahr-toggle-idle ahr-toggle-nightlight ahr-toggle-notification-silencing
  ahr-toggle-waybar ahr-toggle-waybar-position ahr-restore-nightlight
  ahr-restore-idle ahr-notification-dismiss ahr-restart-mako
  ahr-restart-waybar ahr-restart-walker ahr-migrate ahr-system-lock
  ahr-system-reboot ahr-capture-screenrecording ahr-capture-screenshot
  ahr-capture-picker ahr-edit-config ahr-system-suspend ahr-system-hibernate
  ahr-doctor ahr-font ahr-font-list ahr-font-set
)

declare -a AHR_NAMESPACE_ALIASES=(
  "omarchy:ahr" "omarchy-menu:ahr-menu" "omarchy-menu-keybindings:ahr-menu-keybindings"
  "omarchy-theme:ahr-theme" "omarchy-theme-list:ahr-theme-list"
  "omarchy-theme-current:ahr-theme-current" "omarchy-theme-set:ahr-theme-set"
  "omarchy-theme-refresh:ahr-theme-refresh" "omarchy-theme-bg-next:ahr-theme-bg-next"
  "omarchy-theme-bg-set:ahr-theme-bg-set" "omarchy-theme-set-templates:ahr-theme-set-templates"
  "omarchy-theme-colors-from-alacritty:ahr-theme-colors-from-alacritty"
  "omarchy-launch-terminal:ahr-launch-terminal" "omarchy-launch-walker:ahr-launch-apps"
  "omarchy-launch-browser:ahr-launch-browser" "omarchy-launch-nautilus:ahr-launch-files"
  "omarchy-launch-audio:ahr-launch-audio" "omarchy-launch-bluetooth:ahr-launch-bluetooth"
  "omarchy-launch-wifi:ahr-launch-wifi" "omarchy-system-lock:ahr-system-lock"
  "omarchy-system-reboot:ahr-system-reboot" "omarchy-capture-screenrecording:ahr-capture-screenrecording"
  "omarchy-capture-screenshot:ahr-capture-screenshot" "omarchy-default-browser:ahr-default-browser"
  "omarchy-default-terminal:ahr-default-terminal" "omarchy-update:ahr-update"
  "omarchy-update-available:ahr-update-available" "omarchy-repair:ahr-repair"
  "omarchy-status:ahr-status" "omarchy-list-backups:ahr-list-backups"
  "omarchy-voxtype-model:ahr-voxtype-model" "omarchy-voxtype-config:ahr-voxtype-config"
  "omarchy-toggle-idle:ahr-toggle-idle" "omarchy-toggle-nightlight:ahr-toggle-nightlight"
  "omarchy-toggle-notification-silencing:ahr-toggle-notification-silencing"
  "omarchy-toggle-waybar:ahr-toggle-waybar" "omarchy-restore-nightlight:ahr-restore-nightlight"
  "omarchy-notification-dismiss:ahr-notification-dismiss" "omarchy-restart-mako:ahr-restart-mako"
  "omarchy-restart-waybar:ahr-restart-waybar" "omarchy-restart-walker:ahr-restart-walker"
  "omarchy-migrate:ahr-migrate" "omarchy-edit-config:ahr-edit-config"
  "omarchy-system-suspend:ahr-system-suspend" "omarchy-system-hibernate:ahr-system-hibernate"
  "omarchy-font:ahr-font" "omarchy-font-list:ahr-font-list" "omarchy-font-set:ahr-font-set"
)

ahr_namespace_name_is_managed() {
  local wanted="$1" name alias
  for name in "${AHR_NAMESPACE_COMMANDS[@]}"; do
    [[ "$name" == "$wanted" ]] && return 0
  done
  for alias in "${AHR_NAMESPACE_ALIASES[@]}"; do
    [[ "${alias%%:*}" == "$wanted" ]] && return 0
  done
  return 1
}

# Primary backup manifests are data, never shell input.  Keep the association
# parser here because both the framework updater and component restore open
# those manifests.  A legacy manifest may be used only when its caller has
# already selected the exact backup directory; it may not be associated with a
# transaction automatically.
ahr_validate_backup_id() {
  local id="$1"
  [[ -n "$id" && "$id" != "." && "$id" != ".." ]] || return 1
  [[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ "$id" != *".."* ]] || return 1
}

ahr_validate_transaction_id() {
  local id="$1"
  [[ "$id" =~ ^tx-[A-Za-z0-9._-]+$ ]] || return 1
  [[ "$id" != *".."* ]] || return 1
}

# Sets AHR_PRIMARY_MANIFEST_{LEGACY,BACKUP_ID,TRANSACTION_ID}.  The third
# argument is true for automatic transaction association and false for an
# already-selected exact backup directory.
ahr_parse_primary_manifest() {
  local manifest="$1" selected_backup_id="$2" require_association="${3:-false}"
  local backup_id="" transaction_id="" backup_count=0 transaction_count=0 line
  [[ -f "$manifest" ]] || return 1
  ahr_validate_backup_id "$selected_backup_id" || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      backup_id=*)
        backup_count=$((backup_count + 1))
        backup_id="${line#backup_id=}"
        ;;
      transaction_id=*)
        transaction_count=$((transaction_count + 1))
        transaction_id="${line#transaction_id=}"
        ;;
      backup_id*|transaction_id*)
        printf 'Malformed primary manifest association key\n' >&2
        return 1
        ;;
    esac
  done < "$manifest"

  (( backup_count <= 1 && transaction_count <= 1 )) || {
    printf 'Duplicate primary manifest association metadata\n' >&2
    return 1
  }

  # Any manifest missing either association field is legacy.  Do not infer the
  # missing value from its directory, timestamps, or transaction state.
  if (( backup_count == 0 || transaction_count == 0 )); then
    [[ "$require_association" == "false" ]] || {
      printf 'Legacy backup lacks transaction-association metadata\n' >&2
      return 1
    }
    if (( backup_count == 1 )); then
      ahr_validate_backup_id "$backup_id" || {
        printf 'Invalid manifest backup_id\n' >&2
        return 1
      }
      [[ "$backup_id" == "$selected_backup_id" ]] || {
        printf 'Manifest backup_id does not match selected backup\n' >&2
        return 1
      }
    fi
    if (( transaction_count == 1 )); then
      ahr_validate_transaction_id "$transaction_id" || {
        printf 'Invalid manifest transaction_id\n' >&2
        return 1
      }
    fi
    AHR_PRIMARY_MANIFEST_LEGACY=true
    AHR_PRIMARY_MANIFEST_BACKUP_ID="$backup_id"
    AHR_PRIMARY_MANIFEST_TRANSACTION_ID="$transaction_id"
    return 0
  fi

  ahr_validate_backup_id "$backup_id" || {
    printf 'Invalid manifest backup_id\n' >&2
    return 1
  }
  ahr_validate_transaction_id "$transaction_id" || {
    printf 'Invalid manifest transaction_id\n' >&2
    return 1
  }
  [[ "$backup_id" == "$selected_backup_id" ]] || {
    printf 'Manifest backup_id does not match selected backup\n' >&2
    return 1
  }

  AHR_PRIMARY_MANIFEST_LEGACY=false
  AHR_PRIMARY_MANIFEST_BACKUP_ID="$backup_id"
  AHR_PRIMARY_MANIFEST_TRANSACTION_ID="$transaction_id"
}

# Check that a command is available on PATH.  If missing, print a user-facing
# message with an install hint and return 1 so the caller can choose how to
# respond (show a dialog, skip a menu item, fall back, etc.).
# Usage: ahr_require <command> [package_name]
# If package_name is omitted the command name is used as the package hint.
ahr_require() {
  local cmd="$1"
  local pkg="${2:-$1}"

  command -v "$cmd" >/dev/null 2>&1 && return 0

  cat >&2 <<EOF
ERROR: '$cmd' is required but not installed.
       Install with: sudo pacman -S $pkg
EOF
  return 1
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
