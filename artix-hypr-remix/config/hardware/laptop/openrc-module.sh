#!/usr/bin/env bash
set -euo pipefail

dry_run="${1:-false}"
service="acpid"

module_info() {
  printf '[hardware:laptop] %s\n' "$*"
}

module_warn() {
  printf '[hardware:laptop][WARN] %s\n' "$*" >&2
}

enable_openrc_service() {
  local service_name="$1"

  if [[ ! -x "/etc/init.d/$service_name" ]]; then
    module_warn "Service script not found: /etc/init.d/$service_name"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    module_info "Dry-run: would ensure OpenRC service '$service_name' is enabled and running"
    return 0
  fi

  if [[ ! -e "/etc/runlevels/default/$service_name" ]]; then
    rc-update add "$service_name" default >/dev/null
    module_info "Enabled OpenRC service '$service_name' in default runlevel"
  else
    module_info "OpenRC service '$service_name' already enabled in default runlevel"
  fi

  if rc-service "$service_name" status >/dev/null 2>&1; then
    module_info "OpenRC service '$service_name' is already running"
    return 0
  fi

  if rc-service "$service_name" start >/dev/null 2>&1; then
    module_info "Started OpenRC service '$service_name'"
  else
    module_warn "Could not start OpenRC service '$service_name'"
  fi
}

enable_openrc_service "$service"
