#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER_SCRIPT="$SCRIPT_DIR/check-config-deps.sh"

checker_args=()
host_policy="${AHR_HOST_POLICY:-artix}"
overall_status=0
repair_suggestion_recommended=false

declare -a REQUIRED_ENV_COMMANDS=(pacman slurp grim hyprctl rc-update rc-service)
declare -a REQUIRED_DESKTOP_COMMANDS=(
  polkit-gnome-authentication-agent-1
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
)
declare -a REQUIRED_OPENRC_SERVICES=(dbus elogind NetworkManager bluetoothd)
declare -a OPTIONAL_PRINTING_SERVICES=(cupsd avahi-daemon)
declare -a REQUIRED_FRAMEWORK_COMMANDS=(
  ahr-menu
  ahr-menu-keybindings
  ahr-launch-terminal
  ahr-launch-apps
  ahr-launch-browser
  ahr-launch-files
  ahr-default-browser
  ahr-default-terminal
  ahr-repair
  ahr-system-lock
  ahr-toggle-idle
  ahr-launch-wallpaper-session
  start-hyprland-session.sh
)

target_user="${SUDO_USER:-}"
target_home=""

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

recommend_repair() {
  repair_suggestion_recommended=true
}

resolve_target_user() {
  local current_user

  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    current_user="$(id -un 2>/dev/null || true)"
    if [[ "$current_user" != "root" && -n "$current_user" ]]; then
      target_user="$current_user"
    fi
  fi

  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    return 1
  fi

  if ! id "$target_user" >/dev/null 2>&1; then
    return 1
  fi

  target_home="$(getent passwd "$target_user" | cut -d: -f6)"
  [[ -n "$target_home" && -d "$target_home" ]]
}

service_enabled_in_default_runlevel() {
  local service="$1"
  [[ -e "/etc/runlevels/default/$service" ]]
}

network_default_route_present() {
  if command -v ip >/dev/null 2>&1; then
    ip route show default 2>/dev/null | grep -q '^default'
    return $?
  fi

  awk 'NR > 1 && $2 == "00000000" { found=1 } END { exit(found ? 0 : 1) }' /proc/net/route 2>/dev/null
}

service_runtime_exception_applies() {
  local service="$1"

  case "$service" in
    NetworkManager)
      network_default_route_present
      return $?
      ;;
    *)
      return 1
      ;;
  esac
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
    if service_runtime_exception_applies "$service"; then
      echo "WARN: service not running: $service (default route already present outside NetworkManager)"
      return
    fi

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

check_framework_runtime_commands() {
  local framework_bin_dir command_name command_path

  echo
  echo "Running framework command deployment checks"

  if ! resolve_target_user; then
    echo "WARN: could not resolve a non-root desktop user; skipping framework command deployment checks"
    return
  fi

  framework_bin_dir="$target_home/.config/artix-hypr-remix/bin"
  if [[ ! -d "$framework_bin_dir" ]]; then
    echo "MISSING: framework bin directory: $framework_bin_dir"
    mark_missing
    recommend_repair
    return
  fi

  for command_name in "${REQUIRED_FRAMEWORK_COMMANDS[@]}"; do
    command_path="$framework_bin_dir/$command_name"
    if [[ -x "$command_path" ]]; then
      echo "OK: framework command executable: $command_path"
    elif [[ -e "$command_path" ]]; then
      echo "MISSING: framework command not executable: $command_path"
      mark_missing
      recommend_repair
    else
      echo "MISSING: framework command missing: $command_path"
      mark_missing
      recommend_repair
    fi
  done
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

check_framework_runtime_commands

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
  echo
  echo "Suggested next steps:"
  if [[ "$repair_suggestion_recommended" == "true" ]]; then
    if [[ -n "$target_home" && -x "$target_home/.config/artix-hypr-remix/bin/ahr-repair" ]]; then
      echo "  - Preview safe framework repairs as the desktop user:"
      echo "      $target_home/.config/artix-hypr-remix/bin/ahr-repair"
      echo "  - Apply safe framework repairs after reviewing output:"
      echo "      $target_home/.config/artix-hypr-remix/bin/ahr-repair --apply"
    elif [[ -n "$target_home" ]]; then
      echo "  - Framework repair command is missing; re-run config deployment:"
      echo "      sudo ./install.sh --phase 4 --user ${target_user:-<user>} -y"
    fi
  fi
  echo "  - Package or OpenRC service failures may require rerunning the relevant installer phase or enabling/starting the named service."
  exit 1
fi

echo
echo "Doctor checks passed"
