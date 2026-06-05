#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_SOURCE="$REPO_ROOT/config/artix-hypr-remix"

keep_sandbox=false
sandbox=""
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
        echo "ERROR: Host policy 'vm' requires virtualization for smoke validation." >&2
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
Usage: ./scripts/smoke-framework.sh [options]

Runs a non-destructive framework smoke test in a temporary HOME directory.
Default host policy is Artix-only (AHR_HOST_POLICY=artix).
Set AHR_HOST_POLICY=vm for strict VM-only validation.

Options:
  --keep-sandbox  Keep the temporary HOME directory for inspection
  -h, --help      Show this help

Environment:
  AHR_HOST_POLICY=artix|vm|any  Host policy (default: artix)
  AHR_ALLOW_NON_VM_TESTING=1    Legacy compatibility; forces policy to any
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --keep-sandbox)
      keep_sandbox=true
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

if [[ ! -d "$FRAMEWORK_SOURCE" ]]; then
  echo "Framework source not found: $FRAMEWORK_SOURCE" >&2
  exit 1
fi

sandbox="$(mktemp -d)"

cleanup() {
  if [[ "$keep_sandbox" == "false" ]]; then
    rm -rf "$sandbox"
  fi
}
trap cleanup EXIT

mkdir -p "$sandbox/.config"
cp -a "$FRAMEWORK_SOURCE" "$sandbox/.config/"

echo "Smoke test sandbox: $sandbox"

export AHR_THEME_NO_RELOAD=1

echo "[1/5] Install command namespace"
HOME="$sandbox" bash "$sandbox/.config/artix-hypr-remix/bin/namespace-install.sh" --quiet

echo "[2/5] Migration status + dry-run"
HOME="$sandbox" "$sandbox/.local/bin/ahr-migrate" --status
HOME="$sandbox" "$sandbox/.local/bin/ahr-migrate" --dry-run

echo "[3/5] Update runner migrations-only dry-run"
HOME="$sandbox" "$sandbox/.local/bin/ahr-update" --migrations-only --dry-run --quiet

echo "[4/5] Dispatcher lookup without PATH dependency"
set +e
HOME="$sandbox" "$sandbox/.local/bin/ahr" update-available --json
status_no_path=$?
set -e
if [[ "$status_no_path" -ne 0 && "$status_no_path" -ne 1 ]]; then
  echo "Dispatcher smoke test failed with exit code: $status_no_path" >&2
  exit "$status_no_path"
fi

echo "[5/7] ahr status --quiet"
HOME="$sandbox" "$sandbox/.local/bin/ahr-status" --quiet

echo "[6/7] ahr list-backups --count"
count="$(HOME="$sandbox" "$sandbox/.local/bin/ahr-list-backups" --count)"
echo "Backups found in sandbox: $count"
if [[ "$count" -ne 0 ]]; then
  echo "WARN: sandbox unexpectedly contains config backups" >&2
fi

echo "[7/7] Run migrations non-interactively"
HOME="$sandbox" "$sandbox/.local/bin/ahr-migrate" --non-interactive
HOME="$sandbox" "$sandbox/.local/bin/ahr-migrate" --status

if [[ "$keep_sandbox" == "true" ]]; then
  echo "Smoke test completed (sandbox retained): $sandbox"
else
  echo "Smoke test completed"
fi
