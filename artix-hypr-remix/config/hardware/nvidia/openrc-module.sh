#!/usr/bin/env bash
set -euo pipefail

dry_run="${1:-false}"
modprobe_file="/etc/modprobe.d/nvidia-drm.conf"
modprobe_dir="$(dirname "$modprobe_file")"
modprobe_content='options nvidia_drm modeset=1'
persistenced_service="nvidia-persistenced"

module_info() {
  printf '[hardware:nvidia] %s\n' "$*"
}

module_warn() {
  printf '[hardware:nvidia][WARN] %s\n' "$*" >&2
}

write_file_if_changed() {
  local path="$1"
  local content="$2"
  local current

  if [[ -f "$path" ]]; then
    current="$(cat "$path")"
    if [[ "$current" == "$content" ]]; then
      module_info "No change needed for $path"
      return 0
    fi
  fi

  if [[ "$dry_run" == "true" ]]; then
    module_info "Dry-run: would write $path"
    return 0
  fi

  printf '%s\n' "$content" > "$path"
  module_info "Updated $path"
}

enable_openrc_service() {
  local service="$1"

  if [[ ! -x "/etc/init.d/$service" ]]; then
    module_warn "Service script not found: /etc/init.d/$service"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    module_info "Dry-run: would ensure OpenRC service '$service' is enabled and running"
    return 0
  fi

  if [[ ! -e "/etc/runlevels/default/$service" ]]; then
    rc-update add "$service" default >/dev/null
    module_info "Enabled OpenRC service '$service' in default runlevel"
  else
    module_info "OpenRC service '$service' already enabled in default runlevel"
  fi

  if rc-service "$service" status >/dev/null 2>&1; then
    module_info "OpenRC service '$service' is already running"
    return 0
  fi

  if rc-service "$service" start >/dev/null 2>&1; then
    module_info "Started OpenRC service '$service'"
  else
    module_warn "Could not start OpenRC service '$service'"
  fi
}

if [[ "$dry_run" == "true" ]]; then
  module_info "Dry-run: evaluating NVIDIA OpenRC module"
fi

if [[ "$dry_run" != "true" ]]; then
  mkdir -p "$modprobe_dir"
fi

write_file_if_changed "$modprobe_file" "$modprobe_content"
enable_openrc_service "$persistenced_service"
