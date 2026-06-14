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
fi

source_dir="$HOME/.config/artix-hypr-remix/bin"
target_dir="$HOME/.local/bin"

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

install -d -m 0755 "$target_dir"

for command_name in "${commands[@]}"; do
  source_path="$source_dir/$command_name"
  target_path="$target_dir/$command_name"

  if [[ ! -f "$source_path" ]]; then
    echo "Missing command source: $source_path" >&2
    exit 1
  fi

  chmod 0755 "$source_path"
  ln -sfn "$source_path" "$target_path"
  log "Installed command: $target_path"
done

for alias_spec in "${aliases[@]}"; do
  alias_name="${alias_spec%%:*}"
  target_name="${alias_spec##*:}"

  if [[ ! -e "$target_dir/$target_name" ]]; then
    echo "Alias target not found: $target_name" >&2
    exit 1
  fi

  ln -sfn "$target_dir/$target_name" "$target_dir/$alias_name"
  log "Installed compatibility alias: $target_dir/$alias_name -> $target_name"
done

log "Command namespace install complete"
