#!/usr/bin/env bash
# Offline regression tests for Phase 3c catalog-managed install and launch.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_ROOT="$REPO_ROOT/config/artix-hypr-remix"
AHR="$FRAMEWORK_ROOT/bin/ahr"
CATALOG="$FRAMEWORK_ROOT/default/flatpak/catalog.json"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-flatpak-operations-test-XXXXXXXX)"
TEST_HOME="$TEST_TMP/home"
STUB_DIR="$TEST_TMP/stub"
SYSTEM_APPLICATIONS_DIR="$TEST_TMP/system-applications"
FLATPAK_LOG="$TEST_TMP/flatpak.log"
ORIGINAL_PATH="$PATH"
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir -p "$TEST_HOME" "$STUB_DIR" "$SYSTEM_APPLICATIONS_DIR"

pass() { printf 'PASS: %s\n' "$1"; ((PASS+=1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; ((FAIL+=1)); }

run_ahr() {
  local catalog_path="${AHR_TEST_CATALOG_PATH:-$CATALOG}"
  local flatpak_command="${AHR_TEST_COMMAND:-ahr-test-flatpak}"
  : > "$FLATPAK_LOG"
  RUN_STATUS=0
  set +e
  RUN_OUTPUT="$(
    HOME="$TEST_HOME" \
    AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    AHR_FLATPAK_CATALOG_PATH="$catalog_path" \
    AHR_FLATPAK_COMMAND="$flatpak_command" \
    AHR_FLATPAK_SYSTEM_APPLICATIONS_DIR="$SYSTEM_APPLICATIONS_DIR" \
    AHR_TEST_FLATPAK_LOG="$FLATPAK_LOG" \
    AHR_TEST_FLATPAK_MODE="${AHR_TEST_FLATPAK_MODE:-install-new}" \
    PATH="$STUB_DIR:$ORIGINAL_PATH" \
    "$AHR" flatpak "$@" 2>&1
  )"
  RUN_STATUS=$?
  set -e
}

cat > "$STUB_DIR/ahr-test-flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AHR_TEST_FLATPAK_LOG"
case "$1" in
  info)
    case "$AHR_TEST_FLATPAK_MODE" in
      already-installed|launch-ok|desktop-missing|run-fail) exit 0 ;;
      *) exit 1 ;;
    esac
    ;;
  remotes)
    case "$AHR_TEST_FLATPAK_MODE" in
      remote-missing|remote-add-fail) exit 1 ;;
      *) printf 'flathub\n'; exit 0 ;;
    esac
    ;;
  remote-add)
    [[ "$AHR_TEST_FLATPAK_MODE" == remote-add-fail ]] && exit 1
    exit 0
    ;;
  install)
    [[ "$AHR_TEST_FLATPAK_MODE" == install-fail ]] && exit 1
    exit 0
    ;;
  run)
    [[ "$AHR_TEST_FLATPAK_MODE" == run-fail ]] && exit 1
    exit 0
    ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$STUB_DIR/ahr-test-flatpak"

run_ahr install 'Zen Browser'
expected_install_log=$'info --system app.zen_browser.zen\nremotes --system --columns=name\ninstall --system --noninteractive flathub app.zen_browser.zen'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == 'Flatpak install plan:'* \
  && "$RUN_OUTPUT" == *'Application: Zen Browser'* \
  && "$RUN_OUTPUT" == *'Zen Browser installed.'* \
  && "$(cat "$FLATPAK_LOG")" == "$expected_install_log" ]]; then
  pass "install resolves display name and uses system-scoped shared operations"
else
  fail "install resolves display name and uses system-scoped shared operations"
fi

AHR_TEST_FLATPAK_MODE=already-installed run_ahr install zen-browser
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'already installed for system scope; no changes made.'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system app.zen_browser.zen' ]]; then
  pass "install is idempotent and performs no remote or install operation"
else
  fail "install is idempotent and performs no remote or install operation"
fi

AHR_TEST_FLATPAK_MODE=remote-missing run_ahr install signal
expected_remote_add_log=$'info --system org.signal.Signal\nremotes --system --columns=name\nremote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo\ninstall --system --noninteractive flathub org.signal.Signal'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Adding Flathub remote (system scope).'* \
  && "$(cat "$FLATPAK_LOG")" == "$expected_remote_add_log" ]]; then
  pass "install configures a missing system Flathub remote"
else
  fail "install configures a missing system Flathub remote"
fi

AHR_TEST_FLATPAK_MODE=remote-add-fail run_ahr install signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'Flathub is unavailable'* \
  && "$(tail -n 1 "$FLATPAK_LOG")" == remote-add* \
  && "$(cat "$FLATPAK_LOG")" != *$'\ninstall '* ]]; then
  pass "Flathub failure stops before application installation"
else
  fail "Flathub failure stops before application installation"
fi

AHR_TEST_FLATPAK_MODE=install-fail run_ahr install signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'Flatpak installation failed for Signal'* \
  && "$(tail -n 1 "$FLATPAK_LOG")" == 'install --system --noninteractive flathub org.signal.Signal' ]]; then
  pass "application installation failure is reported cleanly"
else
  fail "application installation failure is reported cleanly"
fi

AHR_TEST_COMMAND=ahr-flatpak-command-not-found run_ahr install signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'flatpak is required to install catalog applications'* \
  && ! -s "$FLATPAK_LOG" ]]; then
  pass "missing Flatpak command fails before any operation"
else
  fail "missing Flatpak command fails before any operation"
fi

run_ahr install org.example.NotInCatalog
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'no application matches'* && ! -s "$FLATPAK_LOG" ]]; then
  pass "install rejects non-catalog raw ID without operations"
else
  fail "install rejects non-catalog raw ID without operations"
fi

printf '[Desktop Entry]\nName=Zen Browser\n' > "$SYSTEM_APPLICATIONS_DIR/app.zen_browser.zen.desktop"
AHR_TEST_FLATPAK_MODE=launch-ok run_ahr launch app.zen_browser.zen
expected_launch_log=$'info --system app.zen_browser.zen\nrun --system app.zen_browser.zen'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == 'Flatpak launch plan:'* \
  && "$RUN_OUTPUT" == *'Desktop entry: app.zen_browser.zen.desktop'* \
  && "$(cat "$FLATPAK_LOG")" == "$expected_launch_log" ]]; then
  pass "launch resolves catalog ID, validates desktop entry, and runs system app"
else
  fail "launch resolves catalog ID, validates desktop entry, and runs system app"
fi

AHR_TEST_FLATPAK_MODE=install-new run_ahr launch zen-browser
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'not installed for system scope'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system app.zen_browser.zen' ]]; then
  pass "launch rejects an application not installed for system scope"
else
  fail "launch rejects an application not installed for system scope"
fi

rm -f "$SYSTEM_APPLICATIONS_DIR/app.zen_browser.zen.desktop"
AHR_TEST_FLATPAK_MODE=desktop-missing run_ahr launch zen-browser
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'expected desktop entry is unavailable'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system app.zen_browser.zen' ]]; then
  pass "launch stops when expected desktop entry is missing"
else
  fail "launch stops when expected desktop entry is missing"
fi

printf '[Desktop Entry]\nName=Zen Browser\n' > "$SYSTEM_APPLICATIONS_DIR/app.zen_browser.zen.desktop"
AHR_TEST_FLATPAK_MODE=run-fail run_ahr launch zen-browser
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'Flatpak launch failed for Zen Browser'* \
  && "$(tail -n 1 "$FLATPAK_LOG")" == 'run --system app.zen_browser.zen' ]]; then
  pass "launch failure is reported cleanly"
else
  fail "launch failure is reported cleanly"
fi

invalid_catalog="$TEST_TMP/invalid-catalog.json"
jq '.schema_version = 2' "$CATALOG" > "$invalid_catalog"
AHR_TEST_CATALOG_PATH="$invalid_catalog" run_ahr install zen-browser
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'schema validation failed'* && ! -s "$FLATPAK_LOG" ]]; then
  pass "invalid catalog stops install before Flatpak operations"
else
  fail "invalid catalog stops install before Flatpak operations"
fi

run_ahr launch org.example.NotInCatalog
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'no application matches'* && ! -s "$FLATPAK_LOG" ]]; then
  pass "launch rejects non-catalog selector without operations"
else
  fail "launch rejects non-catalog selector without operations"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
