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
  ahr-menu
  ahr-launch-terminal
  ahr-launch-browser
  ahr-launch-files
  ahr-launch-audio
  ahr-launch-wifi
  ahr-default-browser
  ahr-default-terminal
  ahr-update
  ahr-update-available
  ahr-system-lock
  ahr-system-reboot
  ahr-capture-screenshot
)

declare -a aliases=(
  "omarchy-menu:ahr-menu"
  "omarchy-launch-terminal:ahr-launch-terminal"
  "omarchy-launch-browser:ahr-launch-browser"
  "omarchy-launch-nautilus:ahr-launch-files"
  "omarchy-launch-audio:ahr-launch-audio"
  "omarchy-launch-wifi:ahr-launch-wifi"
  "omarchy-system-lock:ahr-system-lock"
  "omarchy-system-reboot:ahr-system-reboot"
  "omarchy-capture-screenshot:ahr-capture-screenshot"
  "omarchy-default-browser:ahr-default-browser"
  "omarchy-default-terminal:ahr-default-terminal"
  "omarchy-update:ahr-update"
  "omarchy-update-available:ahr-update-available"
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
