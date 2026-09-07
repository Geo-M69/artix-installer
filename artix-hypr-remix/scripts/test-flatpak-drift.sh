#!/usr/bin/env bash
# Offline regression tests for out-of-band Flatpak drift at the Phase 3d
# catalog-managed boundary. Every case models system state changed outside the
# catalog (user-scope installs, non-catalog installs, leftover or missing
# desktop-entry exports) with a stub `flatpak` executable and proves the
# documented catalog-visible results: user-scope and non-catalog installs stay
# non-authoritative, missing-desktop-entry and leftover-export mismatch states
# are surfaced consistently, and no catalog command queries or mutates user
# scope. This suite changes no runtime behavior; it pins the behavior already
# documented in docs/FLATSEAL_WAREHOUSE.md.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_ROOT="$REPO_ROOT/config/artix-hypr-remix"
AHR="$FRAMEWORK_ROOT/bin/ahr"
CATALOG="$FRAMEWORK_ROOT/default/flatpak/catalog.json"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-flatpak-drift-test-XXXXXXXX)"
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
  : > "$FLATPAK_LOG"
  RUN_STATUS=0
  set +e
  RUN_OUTPUT="$(
    HOME="$TEST_HOME" \
    AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    AHR_FLATPAK_CATALOG_PATH="$CATALOG" \
    AHR_FLATPAK_SYSTEM_APPLICATIONS_DIR="$SYSTEM_APPLICATIONS_DIR" \
    AHR_TEST_FLATPAK_LOG="$FLATPAK_LOG" \
    AHR_TEST_SYSTEM_IDS="${AHR_TEST_SYSTEM_IDS:-}" \
    AHR_TEST_USER_IDS="${AHR_TEST_USER_IDS:-}" \
    PATH="$STUB_DIR:$ORIGINAL_PATH" \
    "$AHR" flatpak "$@" 2>&1
  )"
  RUN_STATUS=$?
  set -e
}

# The stub models the two real installation pools. `info --user` intentionally
# succeeds for user-installed refs so any code path that consulted user scope
# would change the asserted states; exact log equality plus the user-scope
# query counter proves catalog commands never do.
cat > "$STUB_DIR/flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AHR_TEST_FLATPAK_LOG"
case "$1" in
  info)
    case "$2" in
      --system)
        case " $AHR_TEST_SYSTEM_IDS " in
          *" $3 "*) exit 0 ;;
          *) exit 1 ;;
        esac
        ;;
      --user)
        case " $AHR_TEST_USER_IDS " in
          *" $3 "*) exit 0 ;;
          *) exit 1 ;;
        esac
        ;;
      *) exit 1 ;;
    esac
    ;;
  remotes)
    printf 'flathub\n'
    exit 0
    ;;
  remote-add|install|uninstall|update|run) exit 0 ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$STUB_DIR/flatpak"

user_scope_queries() {
  grep -c -- '--user' "$FLATPAK_LOG" || true
}

status_state_cell() {
  awk 'NR == 2 { print $NF }' <<< "$RUN_OUTPUT"
}

# --- User-scope installs are non-authoritative ------------------------------

AHR_TEST_USER_IDS=org.signal.Signal run_ahr status signal
if [[ "$RUN_STATUS" == 0 && "$(status_state_cell)" == 'not-installed' \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' \
  && "$(user_scope_queries)" == 0 ]]; then
  pass "status reports a user-scope-only install as not-installed and never queries user scope"
else
  fail "status reports a user-scope-only install as not-installed and never queries user scope"
fi

AHR_TEST_USER_IDS=app.zen_browser.zen run_ahr install zen-browser
expected_user_install_log=$'info --system app.zen_browser.zen\nremotes --system --columns=name\ninstall --system --noninteractive flathub app.zen_browser.zen'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Installing Zen Browser'* \
  && "$RUN_OUTPUT" != *'already installed'* \
  && "$(cat "$FLATPAK_LOG")" == "$expected_user_install_log" \
  && "$(user_scope_queries)" == 0 ]]; then
  pass "install offers a system-scope copy despite a user-scope-only install"
else
  fail "install offers a system-scope copy despite a user-scope-only install"
fi

printf '[Desktop Entry]\nName=Signal\n' > "$SYSTEM_APPLICATIONS_DIR/org.signal.Signal.desktop"
AHR_TEST_USER_IDS=org.signal.Signal run_ahr launch signal
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'not installed for system scope'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' \
  && "$(user_scope_queries)" == 0 ]]; then
  pass "launch rejects a user-scope-only install despite a present desktop entry"
else
  fail "launch rejects a user-scope-only install despite a present desktop entry"
fi

AHR_TEST_USER_IDS=org.signal.Signal run_ahr remove signal
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'not installed for system scope; no changes made.'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' \
  && "$(user_scope_queries)" == 0 ]]; then
  pass "remove treats a user-scope-only install as absent without mutation"
else
  fail "remove treats a user-scope-only install as absent without mutation"
fi

AHR_TEST_USER_IDS=org.signal.Signal run_ahr update signal
if [[ "$RUN_STATUS" != 0 \
  && "$RUN_OUTPUT" == *'is not installed for system scope; it cannot be updated'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' \
  && "$(user_scope_queries)" == 0 ]]; then
  pass "selector update rejects a user-scope-only install"
else
  fail "selector update rejects a user-scope-only install"
fi

AHR_TEST_USER_IDS='app.zen_browser.zen org.signal.Signal' run_ahr update
catalog_info_count="$(grep -c '^info --system ' "$FLATPAK_LOG")"
update_call_present=false
if grep -q '^update ' "$FLATPAK_LOG"; then
  update_call_present=true
fi
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'No installed catalog applications to update; no changes made.'* \
  && "$catalog_info_count" == 13 && "$update_call_present" == false \
  && "$(user_scope_queries)" == 0 ]]; then
  pass "catalog-wide update ignores user-scope installs and stays a safe no-op"
else
  fail "catalog-wide update ignores user-scope installs and stays a safe no-op"
fi

# --- Non-catalog system installs are outside the catalog --------------------

AHR_TEST_SYSTEM_IDS='app.zen_browser.zen org.example.NotInCatalog' run_ahr update
catalog_update_call="$(tail -n 1 "$FLATPAK_LOG")"
non_catalog_queries="$(grep -c 'org.example.NotInCatalog' "$FLATPAK_LOG" || true)"
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Applications (1):'* \
  && "$RUN_OUTPUT" == *'Zen Browser (app.zen_browser.zen)'* \
  && "$catalog_update_call" == 'update --system app.zen_browser.zen' \
  && "$non_catalog_queries" == 0 ]]; then
  pass "catalog-wide update ignores non-catalog system installs and targets only catalog IDs"
else
  fail "catalog-wide update ignores non-catalog system installs and targets only catalog IDs"
fi

# --- Installed but expected desktop entry missing (export drift) ------------

rm -f "$SYSTEM_APPLICATIONS_DIR/org.signal.Signal.desktop"
AHR_TEST_SYSTEM_IDS=org.signal.Signal run_ahr status signal
if [[ "$RUN_STATUS" == 0 && "$(status_state_cell)" == 'installed' \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' ]]; then
  pass "status reports the drifted system install as installed even with the expected desktop entry missing"
else
  fail "status reports the drifted system install as installed even with the expected desktop entry missing"
fi

AHR_TEST_SYSTEM_IDS=org.signal.Signal run_ahr launch signal
if [[ "$RUN_STATUS" != 0 \
  && "$RUN_OUTPUT" == *"expected desktop entry is unavailable: $SYSTEM_APPLICATIONS_DIR/org.signal.Signal.desktop"* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' ]]; then
  pass "launch surfaces the missing expected desktop entry with its full path and never runs the app"
else
  fail "launch surfaces the missing expected desktop entry with its full path and never runs the app"
fi

AHR_TEST_SYSTEM_IDS=org.signal.Signal run_ahr install signal
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'already installed for system scope; no changes made.'* \
  && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' ]]; then
  pass "install remains an idempotent no-op for a drifted install and does not attempt export repair"
else
  fail "install remains an idempotent no-op for a drifted install and does not attempt export repair"
fi

# --- Operator-facing diagnostics are consistent across commands -------------

not_installed_phrase='Signal (org.signal.Signal) is not installed for system scope'
AHR_TEST_USER_IDS=org.signal.Signal run_ahr launch signal
launch_output="$RUN_OUTPUT"; launch_status="$RUN_STATUS"
AHR_TEST_USER_IDS=org.signal.Signal run_ahr remove signal
remove_output="$RUN_OUTPUT"; remove_status="$RUN_STATUS"
AHR_TEST_USER_IDS=org.signal.Signal run_ahr update signal
update_output="$RUN_OUTPUT"
if [[ "$launch_status" != 0 && "$remove_status" == 0 \
  && "$launch_output" == *"$not_installed_phrase"* \
  && "$remove_output" == *"$not_installed_phrase"* \
  && "$update_output" == *"$not_installed_phrase"* ]]; then
  pass "launch, remove, and update report one not-installed state with identical scoped wording"
else
  fail "launch, remove, and update report one not-installed state with identical scoped wording"
fi

AHR_TEST_SYSTEM_IDS=org.signal.Signal run_ahr install signal
install_noop_output="$RUN_OUTPUT"
AHR_TEST_SYSTEM_IDS= run_ahr remove signal
remove_noop_output="$RUN_OUTPUT"
if [[ "$install_noop_output" == *'Signal (org.signal.Signal) is already installed for system scope; no changes made.'* \
  && "$remove_noop_output" == *'Signal (org.signal.Signal) is not installed for system scope; no changes made.'* ]]; then
  pass "install and remove state no-ops share one scope-qualified wording skeleton"
else
  fail "install and remove state no-ops share one scope-qualified wording skeleton"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
