#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

network_default_route_present() {
  if command -v ip >/dev/null 2>&1; then
    ip route show default 2>/dev/null | grep -q '^default'
    return $?
  fi

  awk 'NR > 1 && $2 == "00000000" { found=1 } END { exit(found ? 0 : 1) }' /proc/net/route 2>/dev/null
}

service_runtime_exception_applies() {
  local svc="$1"

  case "$svc" in
    NetworkManager)
      network_default_route_present
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}

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
    if service_runtime_exception_applies "$svc"; then
      warn "Service '$svc' did not enter a running state, but the system already has a default route; continuing"
      return 0
    fi

    if [[ "$required" == "true" ]]; then
      error "Required OpenRC service '$svc' failed to start"
    fi

    warn "Service '$svc' was enabled but could not be started right now"
    return 0
  fi

  if rc-service "$svc" status >/dev/null 2>&1; then
    info "OpenRC service '$svc' is running"
    return 0
  fi

  if service_runtime_exception_applies "$svc"; then
    warn "Service '$svc' remains inactive, but the system already has a default route; continuing"
    return 0
  fi

  if [[ "$required" == "true" ]]; then
    error "Required OpenRC service '$svc' did not report running after start"
  fi

  warn "Service '$svc' start command completed but status is not running"
}

enable_service_required() {
  local svc="$1"
  local runlevel="${2:-default}"
  local start_now="${3:-true}"

  enable_service "$svc" "$runlevel" "$start_now" "true"
}

enable_service_optional() {
  local svc="$1"
  local runlevel="${2:-default}"
  local start_now="${3:-true}"

  enable_service "$svc" "$runlevel" "$start_now" "false"
}
