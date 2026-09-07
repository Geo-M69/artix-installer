#!/usr/bin/env bash
# Offline regression tests for Phase 3d catalog-managed remove and update.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_ROOT="$REPO_ROOT/config/artix-hypr-remix"
AHR="$FRAMEWORK_ROOT/bin/ahr"
CATALOG="$FRAMEWORK_ROOT/default/flatpak/catalog.json"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-flatpak-lifecycle-test-XXXXXXXX)"
TEST_HOME="$TEST_TMP/home"
STUB_DIR="$TEST_TMP/stub"
FLATPAK_LOG="$TEST_TMP/flatpak.log"
ORIGINAL_PATH="$PATH"
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir -p "$TEST_HOME" "$STUB_DIR"

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
    AHR_TEST_FLATPAK_LOG="$FLATPAK_LOG" \
    AHR_TEST_FLATPAK_MODE="${AHR_TEST_FLATPAK_MODE:-normal}" \
    AHR_TEST_INSTALLED_IDS="${AHR_TEST_INSTALLED_IDS:-}" \
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
    case " $AHR_TEST_INSTALLED_IDS " in
      *" $3 "*) exit 0 ;;
      *) exit 1 ;;
    esac
    ;;
  uninstall)
    [[ "$AHR_TEST_FLATPAK_MODE" == remove-fail ]] && exit 1
    exit 0
    ;;
  update)
    [[ "$AHR_TEST_FLATPAK_MODE" == update-fail ]] && exit 1
    exit 0
    ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$STUB_DIR/ahr-test-flatpak"

signal_data="$TEST_HOME/.var/app/org.signal.Signal"
mkdir -p "$signal_data"
printf 'preserve me\n' > "$signal_data/settings"
AHR_TEST_INSTALLED_IDS=org.signal.Signal run_ahr remove Signal
expected_remove_log=$'info --system org.signal.Signal\nuninstall --system --noninteractive org.signal.Signal'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == 'Flatpak removal plan:'* \
  && "$RUN_OUTPUT" == *"Application data: PRESERVED at $signal_data"* \
  && "$(cat "$FLATPAK_LOG")" == "$expected_remove_log" \
  && -f "$signal_data/settings" && "$(cat "$signal_data/settings")" == 'preserve me' \
  && "$expected_remove_log" != *'--delete-data'* ]]; then
  pass "remove uses system scope and preserves application data"
else
  fail "remove uses system scope and preserves application data"
fi

AHR_TEST_INSTALLED_IDS= run_ahr remove signal
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'not installed for system scope; no changes made.'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' \
  && -f "$signal_data/settings" ]]; then
  pass "remove handles already-absent application without mutation"
else
  fail "remove handles already-absent application without mutation"
fi

AHR_TEST_INSTALLED_IDS=org.signal.Signal AHR_TEST_FLATPAK_MODE=remove-fail run_ahr remove signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'Flatpak removal failed for Signal'* \
  && "$(tail -n 1 "$FLATPAK_LOG")" == 'uninstall --system --noninteractive org.signal.Signal' \
  && -f "$signal_data/settings" ]]; then
  pass "remove failure is clear and application data remains untouched"
else
  fail "remove failure is clear and application data remains untouched"
fi

AHR_TEST_COMMAND=ahr-flatpak-command-not-found run_ahr remove signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'flatpak is required to remove catalog applications'* \
  && ! -s "$FLATPAK_LOG" && -f "$signal_data/settings" ]]; then
  pass "remove fails safely when Flatpak is unavailable"
else
  fail "remove fails safely when Flatpak is unavailable"
fi

run_ahr remove ../../unsafe
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'no application matches: ../../unsafe'* \
  && "$RUN_OUTPUT" != *"$TEST_HOME/.var/app/../../unsafe"* && ! -s "$FLATPAK_LOG" ]]; then
  pass "unvalidated selector never becomes an application-data path"
else
  fail "unvalidated selector never becomes an application-data path"
fi

invalid_catalog="$TEST_TMP/invalid-catalog.json"
jq '.schema_version = 2' "$CATALOG" > "$invalid_catalog"
AHR_TEST_CATALOG_PATH="$invalid_catalog" run_ahr remove signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'schema validation failed'* && ! -s "$FLATPAK_LOG" ]]; then
  pass "invalid catalog stops removal before Flatpak operations"
else
  fail "invalid catalog stops removal before Flatpak operations"
fi

AHR_TEST_INSTALLED_IDS=org.signal.Signal run_ahr update signal
expected_single_update_log=$'info --system org.signal.Signal\nupdate --system org.signal.Signal'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == 'Flatpak catalog update plan:'* \
  && "$RUN_OUTPUT" == *'Signal (org.signal.Signal)'* \
  && "$(cat "$FLATPAK_LOG")" == "$expected_single_update_log" ]]; then
  pass "selector update targets one installed catalog application"
else
  fail "selector update targets one installed catalog application"
fi

AHR_TEST_INSTALLED_IDS= run_ahr update signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'is not installed for system scope; it cannot be updated'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' ]]; then
  pass "selector update rejects an application that is not installed"
else
  fail "selector update rejects an application that is not installed"
fi

AHR_TEST_INSTALLED_IDS='app.zen_browser.zen org.signal.Signal' run_ahr update
catalog_info_count="$(grep -c '^info --system ' "$FLATPAK_LOG")"
catalog_update_call="$(tail -n 1 "$FLATPAK_LOG")"
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Applications (2):'* \
  && "$catalog_info_count" == 13 \
  && "$catalog_update_call" == 'update --system app.zen_browser.zen org.signal.Signal' ]]; then
  pass "catalog-wide update selects installed entries in catalog order"
else
  fail "catalog-wide update selects installed entries in catalog order"
fi

AHR_TEST_INSTALLED_IDS= run_ahr update
unexpected_update_call=false
if grep -q '^update ' "$FLATPAK_LOG"; then
  unexpected_update_call=true
fi
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'No installed catalog applications to update; no changes made.'* \
  && "$(grep -c '^info --system ' "$FLATPAK_LOG")" == 13 \
  && "$unexpected_update_call" == false ]]; then
  pass "catalog-wide update is a safe no-op when no catalog apps are installed"
else
  fail "catalog-wide update is a safe no-op when no catalog apps are installed"
fi

AHR_TEST_INSTALLED_IDS=org.signal.Signal AHR_TEST_FLATPAK_MODE=update-fail run_ahr update signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'Flatpak update failed for the catalog update plan'* \
  && "$RUN_OUTPUT" == *'catalog update plan: Signal (org.signal.Signal)'* \
  && "$(tail -n 1 "$FLATPAK_LOG")" == 'update --system org.signal.Signal' ]]; then
  pass "update failure is reported cleanly"
else
  fail "update failure is reported cleanly"
fi

run_ahr update org.example.NotInCatalog
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'no application matches'* && ! -s "$FLATPAK_LOG" ]]; then
  pass "selector update rejects non-catalog raw ID without operations"
else
  fail "selector update rejects non-catalog raw ID without operations"
fi

AHR_TEST_CATALOG_PATH="$invalid_catalog" run_ahr update
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'schema validation failed'* && ! -s "$FLATPAK_LOG" ]]; then
  pass "invalid catalog stops update before Flatpak operations"
else
  fail "invalid catalog stops update before Flatpak operations"
fi

run_ahr help
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'remove <selector>'* && "$RUN_OUTPUT" == *'update [selector]'* ]]; then
  pass "dispatcher help exposes remove and update commands"
else
  fail "dispatcher help exposes remove and update commands"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
