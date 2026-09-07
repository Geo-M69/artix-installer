#!/usr/bin/env bash
# Focused offline regression tests for the Flatpak reporting states of
# `ahr-update-available`. A failed `flatpak remote-ls --updates` query must be
# distinguishable from a genuinely current state in both human and JSON output,
# while successful query counts keep their existing behavior.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_BIN="$REPO_ROOT/config/artix-hypr-remix"
UPDATE_AVAILABLE="$FRAMEWORK_BIN/bin/ahr-update-available"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-update-available-flatpak-test-XXXXXXXX)"
TEST_HOME="$TEST_TMP/home"
STUB_DIR="$TEST_TMP/stub"
NOFLATPAK_DIR="$TEST_TMP/noflatpak"
SANDBOX_FRAMEWORK="$TEST_TMP/framework"
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir -p "$TEST_HOME" "$STUB_DIR" "$NOFLATPAK_DIR" "$SANDBOX_FRAMEWORK/bin" "$SANDBOX_FRAMEWORK/migrations"

pass() { printf 'PASS: %s\n' "$1"; ((PASS+=1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; ((FAIL+=1)); }

# Isolated framework metadata: an empty update_source keeps the framework check
# out of every scenario so only the Flatpak lane is exercised.
cat > "$SANDBOX_FRAMEWORK/framework.json" <<'EOF'
{
  "version": "0.1.0",
  "revision": null,
  "channel": "stable",
  "update_source": "",
  "updated_at": null
}
EOF

# A strictly controlled PATH keeps host checkupdates/pacman/AUR helpers and any
# real flatpak out of the results; only these tools and the scenario stub are
# visible to the script under test.
for cmd in bash jq wc sed head tr cut basename find sort uniq date mktemp cat grep dirname readlink; do
  if path_cmd="$(command -v "$cmd" 2>/dev/null)" && [[ -n "$path_cmd" ]]; then
    ln -sf "$path_cmd" "$STUB_DIR/$cmd"
    ln -sf "$path_cmd" "$NOFLATPAK_DIR/$cmd"
  fi
done

cat > "$STUB_DIR/flatpak" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "remote-ls" ]]; then
  case "${AHR_TEST_FLATPAK_MODE:-current}" in
    current) exit 0 ;;
    updates)
      printf 'org.example.One\norg.example.Two\n'
      exit 0
      ;;
    query-fail)
      printf 'error: Unable to load summaries from remote\n' >&2
      exit 1
      ;;
  esac
fi
exit 0
EOF
chmod +x "$STUB_DIR/flatpak"

run_available() {
  local mode="$1"
  local path_dir="$2"
  shift 2
  RUN_STATUS=0
  set +e
  RUN_OUTPUT="$(
    AHR_TEST_FLATPAK_MODE="$mode" \
    HOME="$TEST_HOME" \
    XDG_STATE_HOME="$TEST_HOME/.local/state" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" \
    AHR_FRAMEWORK_ROOT="$SANDBOX_FRAMEWORK" \
    AHR_LIB_PATH="$FRAMEWORK_BIN/bin/ahr-lib.sh" \
    AHR_VERSION_LIB_PATH="$FRAMEWORK_BIN/bin/ahr-version.sh" \
    AHR_CACHE_LIB_PATH="$FRAMEWORK_BIN/bin/ahr-cache.sh" \
    PATH="$path_dir" \
    bash "$UPDATE_AVAILABLE" "$@" 2>&1
  )"
  RUN_STATUS=$?
  set -e
}

json_field() {
  local field="$1"
  printf '%s' "$RUN_OUTPUT" | jq -r ".$field"
}

# --- Successful queries keep their existing count/state behavior -------------

run_available current "$STUB_DIR" --json
if [[ "$(json_field flatpak_state)" == "current" && "$(json_field flatpak)" == "0" ]]; then
  pass "zero updates report flatpak_state current with count zero"
else
  fail "zero updates report flatpak_state current with count zero"
fi

run_available current "$STUB_DIR"
if [[ "$RUN_STATUS" == 1 && "$RUN_OUTPUT" == "No updates pending." ]]; then
  pass "successful zero-update query keeps the clean up-to-date human output"
else
  fail "successful zero-update query keeps the clean up-to-date human output"
fi

run_available updates "$STUB_DIR" --json
if [[ "$(json_field flatpak_state)" == "current" && "$(json_field flatpak)" == "2" \
  && "$(json_field total)" == "2" && "$(json_field pending)" == "true" ]]; then
  pass "updates available report count through the current state as before"
else
  fail "updates available report count through the current state as before"
fi

run_available updates "$STUB_DIR"
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Flatpak apps: 2'* ]]; then
  pass "human output keeps the successful update count line"
else
  fail "human output keeps the successful update count line"
fi

# --- Failed queries are distinguishable from a current state -----------------

run_available query-fail "$STUB_DIR" --json
if [[ "$(json_field flatpak_state)" == "query-failed" && "$(json_field flatpak)" == "0" ]]; then
  pass "failed remote-ls query reports query-failed, not current"
else
  fail "failed remote-ls query reports query-failed, not current"
fi

run_available query-fail "$STUB_DIR"
if [[ "$RUN_OUTPUT" == *'query failed'* && "$RUN_OUTPUT" == *"flatpak remote-ls --updates"* \
  && "$RUN_OUTPUT" != "No updates pending." ]]; then
  pass "human output surfaces the Flatpak query failure with a diagnostic"
else
  fail "human output surfaces the Flatpak query failure with a diagnostic"
fi

run_available query-fail "$STUB_DIR" --json
total="$(json_field total)"
run_available query-fail "$STUB_DIR"
if [[ "$total" == "0" && "$RUN_OUTPUT" != "No updates pending." && "$RUN_OUTPUT" == *'state unknown'* ]]; then
  pass "query failure adds no pending work but is never reported as up to date"
else
  fail "query failure adds no pending work but is never reported as up to date"
fi

# --- Missing Flatpak command remains unavailable -----------------------------

run_available current "$NOFLATPAK_DIR" --json
if [[ "$(json_field flatpak_state)" == "unavailable" && "$(json_field flatpak)" == "0" ]]; then
  pass "missing flatpak command reports unavailable, distinct from current and query-failed"
else
  fail "missing flatpak command reports unavailable, distinct from current and query-failed"
fi

run_available current "$NOFLATPAK_DIR"
if [[ "$RUN_STATUS" == 1 && "$RUN_OUTPUT" == "No updates pending." ]]; then
  pass "missing flatpak command keeps the existing up-to-date human output"
else
  fail "missing flatpak command keeps the existing up-to-date human output"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
