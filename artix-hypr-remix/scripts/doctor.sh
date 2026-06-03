#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER_SCRIPT="$SCRIPT_DIR/check-config-deps.sh"

checker_args=()
host_policy="${AHR_HOST_POLICY:-artix}"
overall_status=0

declare -a REQUIRED_ENV_COMMANDS=(pacman slurp grim hyprctl rc-update rc-service)
declare -a REQUIRED_DESKTOP_COMMANDS=(
  polkit-gnome-authentication-agent-1
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
)
declare -a REQUIRED_OPENRC_SERVICES=(dbus elogind NetworkManager bluetoothd)
declare -a OPTIONAL_PRINTING_SERVICES=(cupsd avahi-daemon)

is_virtualized_host() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt -q
    return $?
  fi

  grep -qi hypervisor /proc/cpuinfo 2>/dev/null
}

require_supported_host() {
  local effective_host_policy="$host_policy"

  if [[ "${AHR_ALLOW_NON_VM_TESTING:-0}" == "1" ]]; then
    echo "WARN: AHR_ALLOW_NON_VM_TESTING=1 is set; forcing host policy to any"
    effective_host_policy="any"
  fi

  case "$effective_host_policy" in
    any)
      echo "WARN: Host checks bypassed (host policy: any)"
      ;;
    artix)
      if [[ ! -f /etc/artix-release ]]; then
        echo "ERROR: Host policy requires Artix (/etc/artix-release missing)." >&2
        exit 1
      fi
      ;;
    vm)
      if [[ ! -f /etc/artix-release ]]; then
        echo "ERROR: Host policy 'vm' requires Artix (/etc/artix-release missing)." >&2
        exit 1
      fi

      if ! is_virtualized_host; then
        echo "ERROR: Host policy 'vm' requires virtualization for doctor validation." >&2
        exit 1
      fi
      ;;
    *)
      echo "ERROR: Invalid AHR_HOST_POLICY '$effective_host_policy' (use artix, vm, or any)." >&2
      exit 1
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: ./scripts/doctor.sh [options]

Options:
  --no-aur   Pass through to dependency checker (ignore packages/9[0-9]-*.txt)
  -h, --help Show this help

Environment:
  AHR_HOST_POLICY=artix|vm|any  Host policy (default: artix)
  AHR_ALLOW_NON_VM_TESTING=1    Legacy compatibility; forces policy to any
EOF
}

mark_missing() {
  overall_status=1
}

service_enabled_in_default_runlevel() {
  local service="$1"
  [[ -e "/etc/runlevels/default/$service" ]]
}

check_openrc_service_health() {
  local service="$1"
  local required="${2:-true}"

  if [[ ! -x "/etc/init.d/$service" ]]; then
    if [[ "$required" == "true" ]]; then
      echo "MISSING: /etc/init.d/$service"
      mark_missing
    else
      echo "WARN: optional service script missing: /etc/init.d/$service"
    fi
    return
  fi

  echo "OK: service script /etc/init.d/$service"

  if service_enabled_in_default_runlevel "$service"; then
    echo "OK: service enabled in default runlevel: $service"
  else
    if [[ "$required" == "true" ]]; then
      echo "MISSING: service not enabled in default runlevel: $service"
      mark_missing
    else
      echo "WARN: optional service not enabled in default runlevel: $service"
    fi
  fi

  if rc-service "$service" status >/dev/null 2>&1; then
    echo "OK: service running: $service"
  else
    if [[ "$required" == "true" ]]; then
      echo "MISSING: service not running: $service"
      mark_missing
    else
      echo "WARN: optional service not running: $service"
    fi
  fi
}

desktop_command_available() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  case "$cmd" in
    polkit-gnome-authentication-agent-1)
      [[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]
      return $?
      ;;
    xdg-desktop-portal)
      [[ -x /usr/lib/xdg-desktop-portal ]]
      return $?
      ;;
    xdg-desktop-portal-hyprland)
      [[ -x /usr/lib/xdg-desktop-portal-hyprland ]]
      return $?
      ;;
  esac

  return 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-aur)
      checker_args+=("--no-aur")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_supported_host

echo "Running quick environment checks"
for cmd in "${REQUIRED_ENV_COMMANDS[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK: $cmd"
  else
    echo "MISSING: $cmd"
    mark_missing
  fi
done

echo
echo "Running desktop runtime command checks"
for cmd in "${REQUIRED_DESKTOP_COMMANDS[@]}"; do
  if desktop_command_available "$cmd"; then
    echo "OK: $cmd"
  else
    echo "MISSING: $cmd"
    mark_missing
  fi
done

if command -v swww >/dev/null 2>&1; then
  echo "OK: swww"
elif command -v swaybg >/dev/null 2>&1; then
  echo "OK: swaybg"
else
  echo "MISSING: wallpaper backend (swww or swaybg)"
  mark_missing
fi

# AUR helper is optional for runtime health checks.
if command -v paru >/dev/null 2>&1; then
  echo "OK: paru"
else
  echo "WARN: paru (optional)"
fi

echo
echo "Running OpenRC service health checks"
for service in "${REQUIRED_OPENRC_SERVICES[@]}"; do
  check_openrc_service_health "$service" "true"
done

for service in "${OPTIONAL_PRINTING_SERVICES[@]}"; do
  if [[ -x "/etc/init.d/$service" ]]; then
    check_openrc_service_health "$service" "false"
  fi
done

echo
echo "Running config dependency validation"
if [[ ! -x "$CHECKER_SCRIPT" ]]; then
  echo "MISSING: $CHECKER_SCRIPT is not executable"
  mark_missing
else
  if ! "$CHECKER_SCRIPT" "${checker_args[@]}"; then
    mark_missing
  fi
fi

if (( overall_status != 0 )); then
  echo
  echo "Doctor checks failed"
  exit 1
fi

echo
echo "Doctor checks passed"
