#!/usr/bin/env bash
# Offline regression tests for the Phase 3b/3e read-only Flatpak catalog CLI.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_ROOT="$REPO_ROOT/config/artix-hypr-remix"
AHR="$FRAMEWORK_ROOT/bin/ahr"
CATALOG="$FRAMEWORK_ROOT/default/flatpak/catalog.json"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-flatpak-cli-test-XXXXXXXX)"
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
  RUN_STATUS=0
  set +e
  RUN_OUTPUT="$(
    HOME="$TEST_HOME" \
    AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    AHR_FLATPAK_CATALOG_PATH="$catalog_path" \
    AHR_FLATPAK_COMMAND="${AHR_TEST_FLATPAK_COMMAND:-flatpak}" \
    AHR_TEST_FLATPAK_LOG="$FLATPAK_LOG" \
    AHR_TEST_CONFIGURED_LOG="${AHR_TEST_CONFIGURED_LOG:-$TEST_TMP/configured-unused.log}" \
    PATH="$STUB_DIR:$ORIGINAL_PATH" \
    "$AHR" flatpak "$@" 2>&1
  )"
  RUN_STATUS=$?
  set -e
}

expected_list_slugs=$'zen-browser\nflatseal\nwarehouse\ngear-lever\nobs-studio\ndiscord\nvesktop\nobsidian\nspotify\nsignal\nonlyoffice\neasyeffects\nmission-center'

cat > "$STUB_DIR/flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AHR_TEST_FLATPAK_LOG"
if [[ "$1" != "info" || "$2" != "--system" ]]; then
  exit 97
fi
case "$3" in
  app.zen_browser.zen|org.signal.Signal) exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$STUB_DIR/flatpak"

run_ahr list
list_slugs="$(awk 'NR > 1 { print $1 }' <<< "$RUN_OUTPUT")"
if [[ "$RUN_STATUS" == 0 && "$list_slugs" == "$expected_list_slugs" ]]; then
  pass "list preserves catalog order"
else
  fail "list preserves catalog order"
fi

run_ahr search GITHUB
search_slugs="$(awk 'NR > 1 { print $1 }' <<< "$RUN_OUTPUT")"
if [[ "$RUN_STATUS" == 0 && "$search_slugs" == $'flatseal\nwarehouse\neasyeffects' ]]; then
  pass "search is case-insensitive and preserves catalog order"
else
  fail "search is case-insensitive and preserves catalog order"
fi

run_ahr search no-such-application
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == 'No catalog applications match: no-such-application' ]]; then
  pass "search reports no matches without failure"
else
  fail "search reports no matches without failure"
fi

run_ahr info 'Zen Browser'
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Slug: zen-browser'* && "$RUN_OUTPUT" == *'Flatpak ID: app.zen_browser.zen'* ]]; then
  pass "info resolves display name"
else
  fail "info resolves display name"
fi

run_ahr info zen-browser
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Name: Zen Browser'* && "$RUN_OUTPUT" == *'Profile: default'* ]]; then
  pass "info resolves slug"
else
  fail "info resolves slug"
fi

run_ahr info org.signal.Signal
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Name: Signal'* && "$RUN_OUTPUT" == *'Unofficial: true'* ]]; then
  pass "info resolves Flatpak ID"
else
  fail "info resolves Flatpak ID"
fi

run_ahr info no-such-application
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'no application matches: no-such-application'* ]]; then
  pass "info rejects unknown selector"
else
  fail "info rejects unknown selector"
fi

: > "$FLATPAK_LOG"
run_ahr status
info_calls="$(wc -l < "$FLATPAK_LOG")"
unexpected_flatpak_call=false
if grep -qEv '^info --system [A-Za-z0-9._-]+$' "$FLATPAK_LOG"; then
  unexpected_flatpak_call=true
fi
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'zen-browser        Zen Browser'*'installed'* \
  && "$RUN_OUTPUT" == *'discord            Discord'*'not-installed'* \
  && "$info_calls" == 13 && "$unexpected_flatpak_call" == false ]]; then
  pass "status reports local system state without remote operations"
else
  fail "status reports local system state without remote operations"
fi

: > "$FLATPAK_LOG"
run_ahr status signal
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'signal             Signal'*'installed'* \
  && "$RUN_OUTPUT" != *'Zen Browser'* && "$(cat "$FLATPAK_LOG")" == 'info --system org.signal.Signal' ]]; then
  pass "status selector resolves catalog identity"
else
  fail "status selector resolves catalog identity"
fi

run_ahr list --category communication --format menu
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == $'discord\tDiscord\toptional\ttrue\tfalse\nvesktop\tVesktop\toptional\tfalse\ttrue\nsignal\tSignal\toptional\tfalse\ttrue' ]]; then
  pass "list category filter preserves order and emits menu TSV"
else
  fail "list category filter preserves order and emits menu TSV"
fi

run_ahr list --category gaming --format menu
if [[ "$RUN_STATUS" == 0 && -z "$RUN_OUTPUT" ]]; then
  pass "list empty category succeeds with no output"
else
  fail "list empty category succeeds with no output"
fi

run_ahr list --category invalid --format menu
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'invalid category: invalid'* ]]; then
  pass "list rejects invalid category"
else
  fail "list rejects invalid category"
fi

run_ahr list --format menu
menu_all_slugs="$(awk -F'\t' '{ print $1 }' <<< "$RUN_OUTPUT")"
if [[ "$RUN_STATUS" == 0 && "$menu_all_slugs" == "$expected_list_slugs" && "$(awk -F'\t' 'NR==1 { print NF }' <<< "$RUN_OUTPUT")" == 5 ]]; then
  pass "list menu format preserves catalog order with five columns"
else
  fail "list menu format preserves catalog order with five columns"
fi

run_ahr list --format unknown-format
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'Unknown list format: unknown-format'* ]]; then
  pass "list rejects unknown format"
else
  fail "list rejects unknown format"
fi

run_ahr status --category communication --format menu
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == $'discord\tDiscord\toptional\ttrue\tfalse\nvesktop\tVesktop\toptional\tfalse\ttrue\nsignal\tSignal\toptional\tfalse\ttrue' ]]; then
  pass "status category filter emits menu TSV without state column"
else
  fail "status category filter emits menu TSV without state column"
fi

run_ahr status --category communication --installed --format menu
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == $'signal\tSignal\toptional\tfalse\ttrue' ]]; then
  pass "status installed-only filter returns only installed catalog entries"
else
  fail "status installed-only filter returns only installed catalog entries"
fi

run_ahr status --installed --format menu
installed_menu_slugs="$(awk -F'\t' '{ print $1 }' <<< "$RUN_OUTPUT")"
if [[ "$RUN_STATUS" == 0 && "$installed_menu_slugs" == $'zen-browser\nsignal' ]]; then
  pass "status installed-only filter preserves catalog order across categories"
else
  fail "status installed-only filter preserves catalog order across categories"
fi

run_ahr status zen-browser --category communication
if [[ "$RUN_STATUS" != 0 ]]; then
  pass "status rejects combining positional selector with flags"
else
  fail "status rejects combining positional selector with flags"
fi

run_ahr validate
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Flatpak catalog is valid:'* ]]; then
  pass "validate accepts canonical catalog offline"
else
  fail "validate accepts canonical catalog offline"
fi

invalid_catalog="$TEST_TMP/invalid-catalog.json"
jq '.schema_version = 2' "$CATALOG" > "$invalid_catalog"
AHR_TEST_CATALOG_PATH="$invalid_catalog" run_ahr validate
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'schema validation failed'* ]]; then
  pass "validate rejects invalid catalog"
else
  fail "validate rejects invalid catalog"
fi

AHR_TEST_CATALOG_PATH="$invalid_catalog" run_ahr list
if [[ "$RUN_STATUS" != 0 && "$RUN_OUTPUT" == *'schema validation failed'* ]]; then
  pass "read-only commands reject invalid catalog"
else
  fail "read-only commands reject invalid catalog"
fi

# Offline guarantee: only `status` may touch the local Flatpak installation;
# every other read-only command must work with Flatpak entirely absent and
# must never invoke it when it is present.
: > "$FLATPAK_LOG"
offline_read_only_ok=true
run_ahr list
[[ "$RUN_STATUS" == 0 ]] || offline_read_only_ok=false
run_ahr search zen
[[ "$RUN_STATUS" == 0 ]] || offline_read_only_ok=false
run_ahr info zen-browser
[[ "$RUN_STATUS" == 0 ]] || offline_read_only_ok=false
run_ahr validate
[[ "$RUN_STATUS" == 0 ]] || offline_read_only_ok=false
if [[ "$offline_read_only_ok" == true && ! -s "$FLATPAK_LOG" ]]; then
  pass "list, search, info, and validate never invoke Flatpak"
else
  fail "list, search, info, and validate never invoke Flatpak"
fi

min_bin="$TEST_TMP/min-bin"
mkdir -p "$min_bin"
ln -s "$(command -v bash)" "$min_bin/bash"
ln -s "$(command -v jq)" "$min_bin/jq"
ln -s "$(command -v readlink)" "$min_bin/readlink"
ln -s "$(command -v dirname)" "$min_bin/dirname"
absent_status=0
absent_output="$(
  HOME="$TEST_HOME" \
  AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
  AHR_FLATPAK_CATALOG_PATH="$CATALOG" \
  PATH="$min_bin" \
  "$AHR" flatpak status 2>&1
)" || absent_status=$?
if [[ "$absent_status" == 0 && "$(grep -c 'unavailable' <<< "$absent_output")" == 13 ]]; then
  pass "status degrades to unavailable for all rows when Flatpak is absent"
else
  fail "status degrades to unavailable for all rows when Flatpak is absent"
fi

# Status/runtime boundary: installation-state mechanics run through the runtime
# library, so the CLI must honor AHR_FLATPAK_COMMAND instead of a hardcoded
# `flatpak` executable. A differently-named configured stub receives every call
# and the PATH `flatpak` stub is never touched.
configured_log="$TEST_TMP/configured-flatpak.log"
cat > "$STUB_DIR/ahr-configured-flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AHR_TEST_CONFIGURED_LOG"
case "$3" in
  app.zen_browser.zen|org.signal.Signal) exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$STUB_DIR/ahr-configured-flatpak"
: > "$FLATPAK_LOG"
: > "$configured_log"
AHR_TEST_FLATPAK_COMMAND=ahr-configured-flatpak AHR_TEST_CONFIGURED_LOG="$configured_log" run_ahr status
configured_calls="$(wc -l < "$configured_log")"
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'zen-browser        Zen Browser'*'installed'* \
  && "$RUN_OUTPUT" == *'discord            Discord'*'not-installed'* \
  && "$configured_calls" == 13 && ! -s "$FLATPAK_LOG" ]]; then
  pass "status queries installation state through the configured Flatpak command"
else
  fail "status queries installation state through the configured Flatpak command"
fi

# The availability check itself follows the configured command: a real `flatpak`
# on PATH must not make rows report installed/not-installed when the configured
# command is absent, and no Flatpak process may run at all.
: > "$FLATPAK_LOG"
AHR_TEST_FLATPAK_COMMAND=ahr-configured-command-absent run_ahr status
if [[ "$RUN_STATUS" == 0 && "$(grep -c 'unavailable' <<< "$RUN_OUTPUT")" == 13 \
  && ! -s "$FLATPAK_LOG" ]]; then
  pass "status availability follows the configured command, not a hardcoded flatpak"
else
  fail "status availability follows the configured command, not a hardcoded flatpak"
fi

# Static boundary: the catalog library stays pure data interpretation. It must
# contain no Flatpak execution, so installation-state mechanics cannot drift
# back into it or be duplicated outside the runtime library.
catalog_exec_lines="$(grep -Ev '^[[:space:]]*#' "$FRAMEWORK_ROOT/bin/ahr-flatpak-catalog-lib.sh" \
  | grep -E 'command -v .?flatpak|flatpak (info|install|run|update|uninstall|remotes|remote-add|remote-ls)' || true)"
if [[ -z "$catalog_exec_lines" ]] \
  && grep -q 'ahr_flatpak_system_ref_installed' "$FRAMEWORK_ROOT/bin/ahr-flatpak-runtime-lib.sh"; then
  pass "catalog library performs no direct Flatpak execution"
else
  fail "catalog library performs no direct Flatpak execution"
fi

run_ahr help
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *'Usage: ahr flatpak <command> [args]'* ]]; then
  pass "dispatcher reaches Flatpak command group"
else
  fail "dispatcher reaches Flatpak command group"
fi

namespace_list="$(HOME="$TEST_HOME" AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$AHR" list)"
if grep -Fxq 'ahr-flatpak' <<< "$namespace_list"; then
  pass "command inventory includes ahr-flatpak"
else
  fail "command inventory includes ahr-flatpak"
fi

namespace_home="$TEST_TMP/namespace-home"
if HOME="$namespace_home" AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
  bash "$FRAMEWORK_ROOT/bin/namespace-install.sh" --quiet >/dev/null 2>&1 \
  && namespace_output="$(HOME="$namespace_home" AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$namespace_home/.local/bin/ahr" flatpak list)" \
  && [[ "$namespace_output" == *'zen-browser'* ]]; then
  pass "namespace-installed ahr dispatches Flatpak CLI"
else
  fail "namespace-installed ahr dispatches Flatpak CLI"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
