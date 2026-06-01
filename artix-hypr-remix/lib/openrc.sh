#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

service_exists() {
  local svc="$1"
  [[ -x "/etc/init.d/$svc" ]]
}

enable_service() {
  local svc="$1"
  local runlevel="${2:-default}"
  local start_now="${3:-true}"
  local required="${4:-false}"

  if [[ "$required" != "true" && "$required" != "false" ]]; then
    error "Invalid required flag for service '$svc': $required"
  fi

  if ! service_exists "$svc"; then
    if [[ "$required" == "true" ]]; then
      error "Required OpenRC service '$svc' is missing: /etc/init.d/$svc"
    fi

    warn "Skipping OpenRC service '$svc': /etc/init.d/$svc not found"
    return 0
  fi

  info "Adding OpenRC service '$svc' to runlevel '$runlevel'"
  if ! rc-update add "$svc" "$runlevel" >/dev/null 2>&1; then
    if [[ "$required" == "true" ]]; then
      error "Failed to add required OpenRC service '$svc' to runlevel '$runlevel'"
    fi

    warn "Could not add service '$svc' to runlevel '$runlevel'"
  fi

  if [[ "$start_now" != "true" ]]; then
    return 0
  fi

  if rc-service "$svc" status >/dev/null 2>&1; then
    info "OpenRC service '$svc' is already running"
    return 0
  fi

  info "Starting OpenRC service '$svc'"
  if ! rc-service "$svc" start >/dev/null 2>&1; then
    if [[ "$required" == "true" ]]; then
      error "Required OpenRC service '$svc' failed to start"
    fi

    warn "Service '$svc' was enabled but could not be started right now"
  fi
}
