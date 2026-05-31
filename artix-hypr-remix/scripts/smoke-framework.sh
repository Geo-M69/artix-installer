#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_SOURCE="$REPO_ROOT/config/artix-hypr-remix"

keep_sandbox=false
sandbox=""

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
    echo "ERROR: VM-only policy: virtualization is required for smoke validation." >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage: ./scripts/smoke-framework.sh [options]

Runs a non-destructive framework smoke test in a temporary HOME directory.
Execution is restricted to Artix VMs unless AHR_ALLOW_NON_VM_TESTING=1.

Options:
  --keep-sandbox  Keep the temporary HOME directory for inspection
  -h, --help      Show this help
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

require_vm_only_host

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

echo "[5/5] Run migrations non-interactively"
HOME="$sandbox" "$sandbox/.local/bin/ahr-migrate" --non-interactive
HOME="$sandbox" "$sandbox/.local/bin/ahr-migrate" --status

if [[ "$keep_sandbox" == "true" ]]; then
  echo "Smoke test completed (sandbox retained): $sandbox"
else
  echo "Smoke test completed"
fi
