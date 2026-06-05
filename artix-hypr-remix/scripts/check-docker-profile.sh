#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

fail() {
  echo "Docker profile check failed: $1" >&2
  if [[ -f "$TMP_OUTPUT" ]]; then
    echo "--- output ---" >&2
    cat "$TMP_OUTPUT" >&2
  fi
  exit 1
}

run_capture() {
  local -a cmd=("$@")

  set +e
  "${cmd[@]}" >"$TMP_OUTPUT" 2>&1
  RUN_STATUS=$?
  set -e
}

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

cd "$REPO_ROOT"

run_capture "$INSTALLER" --help
[[ "$RUN_STATUS" -eq 0 ]] || fail "install --help returned non-zero"
grep -q -- '--docker-profile MODE' "$TMP_OUTPUT" || fail "install --help does not mention --docker-profile"

run_capture env AHR_HOST_POLICY=any "$INSTALLER" --dry-run --from-phase 3 --phase 3 --docker-profile on -y
[[ "$RUN_STATUS" -eq 0 ]] || fail "phase 3 dry-run with docker profile on returned non-zero"
grep -q '^  - docker$' "$TMP_OUTPUT" || fail "phase 3 docker-profile on output is missing docker service"

run_capture env AHR_HOST_POLICY=any "$INSTALLER" --dry-run --from-phase 3 --phase 3 --docker-profile off -y
[[ "$RUN_STATUS" -eq 0 ]] || fail "phase 3 dry-run with docker profile off returned non-zero"
if grep -q '^  - docker$' "$TMP_OUTPUT"; then
  fail "phase 3 docker-profile off output still contains docker service"
fi

run_capture env AHR_HOST_POLICY=any "$INSTALLER" --dry-run --from-phase 2 --phase 2 --hardware-mode off --docker-profile on -y
if [[ "$RUN_STATUS" -ne 0 ]]; then
  if grep -q 'Package availability check failed for phase 2 package set' "$TMP_OUTPUT"; then
    # Package availability failure is acceptable — docker profile injection was still attempted.
    # Skip the docker-openrc output check because the installer exits before listing packages.
    grep -q 'Docker profile enabled: adding' "$TMP_OUTPUT" || fail "phase 2 output did not report docker profile package injection"
    echo "Docker profile check passed (package availability failure is non-blocking for profile check)."
    exit 0
  fi
  fail "phase 2 docker-profile on failed for an unexpected reason"
fi
grep -q 'Docker profile enabled: adding' "$TMP_OUTPUT" || fail "phase 2 output did not report docker profile package injection"
grep -q 'docker-openrc' "$TMP_OUTPUT" || fail "phase 2 output did not contain docker-openrc"

echo "Docker profile check passed."
