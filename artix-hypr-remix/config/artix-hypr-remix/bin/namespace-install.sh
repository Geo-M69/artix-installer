#!/usr/bin/env bash
set -euo pipefail

quiet=false

if (( $# > 0 )); then
  case "$1" in
    --quiet) quiet=true ;;
    *)
      echo "Usage: namespace-install.sh [--quiet]" >&2
      exit 1
      ;;
  esac
  shift
fi

source_dir="${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/bin"
target_dir="${AHR_LOCAL_BIN:-$HOME/.local/bin}"

declare -a commands=(
  ahr
  ahr-toggle
  ahr-toggle-lib.sh
  ahr-menu
  ahr-menu-keybindings
  ahr-theme
  ahr-theme-install-omarchy
  ahr-theme-list
  ahr-theme-current
  ahr-theme-set
  ahr-theme-refresh
  ahr-theme-bg-next
  ahr-theme-bg-set
  ahr-theme-bg-switcher
  ahr-theme-bg-install
  ahr-theme-bg-gallery
  ahr-theme-set-templates
  ahr-theme-colors-from-alacritty
  ahr-launch-terminal
  ahr-launch-apps
  ahr-launch-browser
  ahr-launch-files
  ahr-launch-audio
  ahr-launch-bluetooth
  ahr-launch-wifi
  ahr-default-browser
  ahr-default-terminal
  ahr-update
  ahr-update-available
  ahr-update-framework
  ahr-restore-component
  ahr-repair
  ahr-status
  ahr-list-backups
  ahr-voxtype-model
  ahr-voxtype-config
  ahr-toggle-idle
  ahr-toggle-nightlight
  ahr-toggle-notification-silencing
  ahr-toggle-waybar
  ahr-toggle-waybar-position
  ahr-restore-nightlight
  ahr-restore-idle
  ahr-notification-dismiss
  ahr-restart-mako
  ahr-restart-waybar
  ahr-restart-walker
  ahr-migrate
  ahr-system-lock
  ahr-system-reboot
  ahr-capture-screenrecording
  ahr-capture-screenshot
  ahr-capture-picker
  ahr-edit-config
  ahr-system-suspend
  ahr-system-hibernate
  ahr-doctor
  ahr-font
  ahr-font-list
  ahr-font-set
)

declare -a aliases=(
  "omarchy:ahr"
  "omarchy-menu:ahr-menu"
  "omarchy-menu-keybindings:ahr-menu-keybindings"
  "omarchy-theme:ahr-theme"
  "omarchy-theme-list:ahr-theme-list"
  "omarchy-theme-current:ahr-theme-current"
  "omarchy-theme-set:ahr-theme-set"
  "omarchy-theme-refresh:ahr-theme-refresh"
  "omarchy-theme-bg-next:ahr-theme-bg-next"
  "omarchy-theme-bg-set:ahr-theme-bg-set"
  "omarchy-theme-set-templates:ahr-theme-set-templates"
  "omarchy-theme-colors-from-alacritty:ahr-theme-colors-from-alacritty"
  "omarchy-launch-terminal:ahr-launch-terminal"
  "omarchy-launch-walker:ahr-launch-apps"
  "omarchy-launch-browser:ahr-launch-browser"
  "omarchy-launch-nautilus:ahr-launch-files"
  "omarchy-launch-audio:ahr-launch-audio"
  "omarchy-launch-bluetooth:ahr-launch-bluetooth"
  "omarchy-launch-wifi:ahr-launch-wifi"
  "omarchy-system-lock:ahr-system-lock"
  "omarchy-system-reboot:ahr-system-reboot"
  "omarchy-capture-screenrecording:ahr-capture-screenrecording"
  "omarchy-capture-screenshot:ahr-capture-screenshot"
  "omarchy-default-browser:ahr-default-browser"
  "omarchy-default-terminal:ahr-default-terminal"
  "omarchy-update:ahr-update"
  "omarchy-update-available:ahr-update-available"
  "omarchy-repair:ahr-repair"
  "omarchy-status:ahr-status"
  "omarchy-list-backups:ahr-list-backups"
  "omarchy-voxtype-model:ahr-voxtype-model"
  "omarchy-voxtype-config:ahr-voxtype-config"
  "omarchy-toggle-idle:ahr-toggle-idle"
  "omarchy-toggle-nightlight:ahr-toggle-nightlight"
  "omarchy-toggle-notification-silencing:ahr-toggle-notification-silencing"
  "omarchy-toggle-waybar:ahr-toggle-waybar"
  "omarchy-restore-nightlight:ahr-restore-nightlight"
  "omarchy-notification-dismiss:ahr-notification-dismiss"
  "omarchy-restart-mako:ahr-restart-mako"
  "omarchy-restart-waybar:ahr-restart-waybar"
  "omarchy-restart-walker:ahr-restart-walker"
  "omarchy-migrate:ahr-migrate"
  "omarchy-edit-config:ahr-edit-config"
  "omarchy-system-suspend:ahr-system-suspend"
  "omarchy-system-hibernate:ahr-system-hibernate"
  "omarchy-font:ahr-font"
  "omarchy-font-list:ahr-font-list"
  "omarchy-font-set:ahr-font-set"
)

log() {
  if [[ "$quiet" == "false" ]]; then
    printf '%s\n' "$1"
  fi
}

backup_dir=""
setup_backup() {
  backup_dir="$(mktemp -d "$HOME/.local/state/artix-hypr-remix/namespace-backup-XXXXXXXX" 2>/dev/null)" || \
    backup_dir="$(mktemp -d "${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/namespace-backup-XXXXXXXX" 2>/dev/null)" || true
}

# Check whether a target path is safe to replace.
# Returns 0 if safe, 1 if unsafe.
check_target_safe() {
  local target_path="$1"
  local source_path="$2"

  # Missing is always safe
  [[ ! -e "$target_path" ]] && return 0

  # Already a correct symlink — safe
  if [[ -L "$target_path" ]]; then
    local current_target
    current_target="$(readlink "$target_path" 2>/dev/null)" || return 1
    [[ "$current_target" == "$source_path" ]] && return 0
    # Symlink exists but points elsewhere — check if it's AHR-owned
    # AHR-owned: points to source_dir or a known framework target
    case "$current_target" in
      "$source_dir/"*|"$target_dir/ahr-"*|"$target_dir/omarchy-"*)
        return 0 ;;
    esac
    # Unrelated symlink — unsafe
    return 1
  fi

  # Regular file — unsafe unless we back it up first
  # We back up but still proceed
  return 0
}

# Prevalidate command sources before any changes.
# Alias targets cannot be checked until after commands are installed.
prevalidate_commands() {
  for command_name in "${commands[@]}"; do
    local source_path="$source_dir/$command_name"
    local target_path="$target_dir/$command_name"
    if [[ ! -f "$source_path" ]]; then
      echo "Missing command source: $source_path" >&2
      return 1
    fi
    if ! check_target_safe "$target_path" "$source_path"; then
      log "Warning: Unrelated file exists at $target_path — creating safety backup"
    fi
  done
  return 0
}

# Validate alias targets after commands have been installed.
validate_aliases() {
  for alias_spec in "${aliases[@]}"; do
    local alias_name="${alias_spec%%:*}"
    local target_name="${alias_spec##*:}"
    if [[ ! -e "$target_dir/$target_name" ]]; then
      echo "Alias target not found: $target_name" >&2
      return 1
    fi
  done
  return 0
}

# Run command prevalidation first
if ! prevalidate_commands; then
  echo "Prevalidation failed — no changes made." >&2
  exit 1
fi

# Setup backup directory before any mutations
setup_backup
mkdir -p "$target_dir"

for command_name in "${commands[@]}"; do
  source_path="$source_dir/$command_name"
  target_path="$target_dir/$command_name"

  # If target exists and is an unrelated file, back it up
  if [[ -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
    cp -a "$target_path" "$backup_dir/$command_name.bak"
    log "Backed up existing file: $target_path -> $backup_dir/$command_name.bak"
  elif [[ -L "$target_path" ]]; then
    current_target="$(readlink "$target_path" 2>/dev/null)" || true
    case "$current_target" in
      "$source_dir/"*|"$target_dir/ahr-"*|"$target_dir/omarchy-"*) ;;
      *)
        cp -a "$target_path" "$backup_dir/$command_name.bak"
        log "Backed up existing symlink: $target_path -> $backup_dir/$command_name.bak"
        ;;
    esac
  fi

  chmod 0755 "$source_path"
  ln -sfn "$source_path" "$target_path"
  log "Installed command: $target_path"
done

# Validate alias targets now that commands have been installed
if ! validate_aliases; then
  echo "Alias validation failed — no aliases changed." >&2
  exit 1
fi

for alias_spec in "${aliases[@]}"; do
  alias_name="${alias_spec%%:*}"
  target_name="${alias_spec##*:}"

  # Safety backup if exists and unrelated
  if [[ -e "$target_dir/$alias_name" ]]; then
    cp -a "$target_dir/$alias_name" "$backup_dir/$alias_name.bak" 2>/dev/null || true
  fi

  ln -sfn "$target_dir/$target_name" "$target_dir/$alias_name"
  log "Installed compatibility alias: $target_dir/$alias_name -> $target_name"
done

log "Command namespace install complete"
if [[ -d "$backup_dir" ]] && ls "$backup_dir" >/dev/null 2>&1; then
  log "Safety backups stored in: $backup_dir"
fi
