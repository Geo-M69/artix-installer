#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER_SCRIPT="$SCRIPT_DIR/check-config-deps.sh"

checker_args=()
host_policy="${AHR_HOST_POLICY:-artix}"

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

overall_status=0

echo "Running quick environment checks"
for cmd in pacman slurp grim hyprctl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK: $cmd"
  else
    echo "MISSING: $cmd"
    overall_status=1
  fi
done

# AUR helper is optional for runtime health checks.
if command -v paru >/dev/null 2>&1; then
  echo "OK: paru"
else
  echo "WARN: paru (optional)"
fi

echo
echo "Running config dependency validation"
if [[ ! -x "$CHECKER_SCRIPT" ]]; then
  echo "MISSING: $CHECKER_SCRIPT is not executable"
  overall_status=1
else
  if ! "$CHECKER_SCRIPT" "${checker_args[@]}"; then
    overall_status=1
  fi
fi

if (( overall_status != 0 )); then
  echo
  echo "Doctor checks failed"
  exit 1
fi

echo
echo "Doctor checks passed"
