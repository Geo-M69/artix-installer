#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER_SCRIPT="$SCRIPT_DIR/check-config-deps.sh"

checker_args=()

usage() {
  cat <<'EOF'
Usage: ./scripts/doctor.sh [options]

Options:
  --no-aur   Pass through to dependency checker (ignore packages/90-*.txt)
  -h, --help Show this help
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

overall_status=0

echo "Running quick environment checks"
for cmd in pacman paru slurp grim hyprctl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK: $cmd"
  else
    echo "MISSING: $cmd"
    overall_status=1
  fi
done

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
