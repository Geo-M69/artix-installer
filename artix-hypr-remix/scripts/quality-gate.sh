#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

include_aur=true

run_core_dependency_check() {
  local output status missing_lines unexpected_lines

  set +e
  output="$($SCRIPT_DIR/check-config-deps.sh --no-aur 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    printf '%s\n' "$output"
    return 0
  fi

  missing_lines="$(printf '%s\n' "$output" | grep -E '^MISSING ' || true)"
  unexpected_lines="$(printf '%s\n' "$missing_lines" | grep -Ev '^MISSING (elephant -> elephant|walker -> walker-bin)$' || true)"

  if [[ -z "$unexpected_lines" ]]; then
    printf '%s\n' "$output" | sed '/^Dependency check failed:/d'
    echo "WARN: no-AUR dependency check has expected AUR-only misses (elephant, walker)"
    return 0
  fi

  printf '%s\n' "$output"
  echo "ERROR: unexpected missing dependencies in no-AUR check"
  return "$status"
}

usage() {
  cat <<'EOF'
Usage: ./scripts/quality-gate.sh [options]

Runs host-independent quality checks for the Artix installer repo.

Options:
  --no-aur   Skip AUR package manifest checks
  -h, --help Show this help
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-aur)
      include_aur=false
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

echo "[1/6] Shell syntax check"
mapfile -t shell_files < <(find "$REPO_ROOT" -type f -name '*.sh' | sort)
if [[ "${#shell_files[@]}" -eq 0 ]]; then
  echo "No shell files found" >&2
  exit 1
fi
bash -n "${shell_files[@]}"

echo "[2/6] OpenRC portability check"
"$SCRIPT_DIR/check-openrc-portability.sh"

echo "[3/6] First-run idempotency check"
"$SCRIPT_DIR/check-first-run-idempotency.sh"

echo "[4/6] Docker profile check"
"$SCRIPT_DIR/check-docker-profile.sh"

echo "[5/6] Config dependency check (core)"
run_core_dependency_check

echo "[6/6] Config dependency check (full)"
if [[ "$include_aur" == "true" ]]; then
  "$SCRIPT_DIR/check-config-deps.sh"
else
  echo "Skipped full dependency check (--no-aur)"
fi

echo "Quality gate passed."
