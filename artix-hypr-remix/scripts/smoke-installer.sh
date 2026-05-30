#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

keep_shims=false

usage() {
  cat <<'EOF'
Usage: ./scripts/smoke-installer.sh [options] [-- <installer args>]

Runs installer dry-runs on non-Artix hosts by creating temporary command shims
for pacman/OpenRC tooling.

Options:
  --keep-shims   Keep temporary shim directory for inspection
  -h, --help     Show this help

Examples:
  ./scripts/smoke-installer.sh
  ./scripts/smoke-installer.sh -- --phase 2 --hardware-mode recommend
  ./scripts/smoke-installer.sh -- --phase 5 --user demo --startup-mode greetd
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --keep-shims)
      keep_shims=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ ! -f "$INSTALLER" ]]; then
  echo "Installer not found: $INSTALLER" >&2
  exit 1
fi

shim_dir="$(mktemp -d)"
cleanup() {
  if [[ "$keep_shims" == "false" ]]; then
    rm -rf "$shim_dir"
  fi
}
trap cleanup EXIT

cat >"$shim_dir/pacman" <<'EOF'
#!/usr/bin/env bash
# Dev smoke shim: pacman queries succeed, writes are no-ops.
case "${1:-}" in
  -Si|-Sy|-S)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF

cat >"$shim_dir/rc-update" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$shim_dir/rc-service" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$shim_dir/pacman" "$shim_dir/rc-update" "$shim_dir/rc-service"

echo "Installer smoke shim directory: $shim_dir"

default_args=(--phase 2 --hardware-mode recommend)
if [[ "$#" -gt 0 ]]; then
  default_args=("$@")
fi

PATH="$shim_dir:$PATH" bash "$INSTALLER" --dry-run --yes --dev-simulate-artix "${default_args[@]}"

if [[ "$keep_shims" == "true" ]]; then
  echo "Smoke installer run completed (shims retained): $shim_dir"
else
  echo "Smoke installer run completed"
fi
