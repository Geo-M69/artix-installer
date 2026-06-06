#!/usr/bin/env bash
set -euo pipefail

dry_run="${1:-false}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

deploy_acpi_events() {
  local event_dir="/etc/acpi/events"
  local action_dir="/etc/acpi/actions"
  local event_file="$event_dir/artix-hypr-remix-lid"
  local action_file="$action_dir/artix-hypr-remix-lid.sh"
  local source_event="$script_dir/acpi-events/lid"
  local elogind_lid_config="/etc/elogind/logind.conf"
  local elogind_dropin_dir="/etc/elogind/logind.conf.d"
  local handle_lid_value=""
  local elogind_config_found=false

  # Read HandleLidSwitch from logind.conf and drop-ins.
  # Whitespace-tolerant: matches "HandleLidSwitch = suspend # comment".
  # Strips inline comments after extracting the value.
  if [[ -f "$elogind_lid_config" ]]; then
    elogind_config_found=true
    handle_lid_value="$(grep -E '^[[:space:]]*HandleLidSwitch[[:space:]]*=' "$elogind_lid_config" 2>/dev/null | tail -1 | sed 's/^[[:space:]]*HandleLidSwitch[[:space:]]*=[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '[:space:]' || true)"
  fi
  # Check drop-ins (higher priority override main config).
  if [[ -d "$elogind_dropin_dir" ]]; then
    elogind_config_found=true
    local dropin_value
    for dropin in "$elogind_dropin_dir"/*.conf; do
      [[ -f "$dropin" ]] || continue
      dropin_value="$(grep -E '^[[:space:]]*HandleLidSwitch[[:space:]]*=' "$dropin" 2>/dev/null | tail -1 | sed 's/^[[:space:]]*HandleLidSwitch[[:space:]]*=[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '[:space:]' || true)"
      if [[ -n "$dropin_value" ]]; then
        handle_lid_value="$dropin_value"
      fi
    done
  fi

  if [[ -n "$handle_lid_value" ]]; then
    if [[ "$handle_lid_value" == "suspend" ]]; then
      module_info "elogind is configured to handle lid close (HandleLidSwitch=suspend) — skipping acpid lid event deployment to avoid duplicate suspend"
      return 0
    else
      module_info "elogind HandleLidSwitch is set to '$handle_lid_value' — deploying acpid lid event as fallback"
    fi
  elif [[ "$elogind_config_found" == "true" ]]; then
    module_info "elogind HandleLidSwitch not explicitly configured — elogind default may handle lid; skipping acpid lid event to avoid conflict"
    return 0
  else
    module_info "elogind not installed (no config found) — deploying acpid lid event as primary lid handler"
  fi

  if [[ "$dry_run" == "true" ]]; then
    module_info "Dry-run: would deploy acpid lid event handler"
    return 0
  fi

  install -d -m 0755 "$event_dir" "$action_dir"

  if [[ -f "$source_event" ]]; then
    cp "$source_event" "$event_file"
    module_info "Deployed lid event: $event_file"
  else
    module_warn "Source lid event not found: $source_event"
  fi

  # Create a lid-close action script that checks lid state first.
  cat > "$action_file" <<'EOF'
#!/usr/bin/env bash
# Suspends the system when the lid is closed.
# Only triggers for close events — checks /proc/acpi/button/lid state.
# Uses loginctl (elogind) if available, falls back to pm-suspend.

# Exit early unless at least one lid state file explicitly reports "closed".
# This prevents suspend-on-open and avoids suspending when no lid state is
# available (e.g. desktops without a physical lid).
lid_closed=false
for state_file in /proc/acpi/button/lid/*/state; do
  if [[ -f "$state_file" ]] && grep -qi 'closed' "$state_file" 2>/dev/null; then
    lid_closed=true
    break
  fi
done

if [[ "$lid_closed" != "true" ]]; then
  exit 0
fi

if command -v loginctl >/dev/null 2>&1 && loginctl suspend 2>/dev/null; then
  exit 0
fi

command -v pm-suspend >/dev/null 2>&1 && exec pm-suspend
EOF
    chmod 755 "$action_file"
    module_info "Created lid action: $action_file"
}

enable_openrc_service "$service"
deploy_acpi_events
