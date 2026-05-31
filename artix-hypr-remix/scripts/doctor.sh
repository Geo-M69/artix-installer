#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER_SCRIPT="$SCRIPT_DIR/check-config-deps.sh"

checker_args=()

is_virtualized_host() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt -q
    return $?
  fi

  grep -qi hypervisor /proc/cpuinfo 2>/dev/null
}

require_vm_only_host() {
  if [[ "${AHR_ALLOW_NON_VM_TESTING:-0}" == "1" ]]; then
    echo "WARN: VM-only checks bypassed (AHR_ALLOW_NON_VM_TESTING=1)"
    return 0
  fi

  if [[ ! -f /etc/artix-release ]]; then
    echo "ERROR: VM-only policy: Artix host required (/etc/artix-release missing)." >&2
    exit 1
  fi

  if ! is_virtualized_host; then
    echo "ERROR: VM-only policy: virtualization is required for doctor validation." >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage: ./scripts/doctor.sh [options]

Options:
  --no-aur   Pass through to dependency checker (ignore packages/90-*.txt)
  -h, --help Show this help

Environment:
  AHR_ALLOW_NON_VM_TESTING=1  Bypass Artix VM-only guard (maintenance only)
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

require_vm_only_host

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
