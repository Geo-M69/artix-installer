#!/usr/bin/env bash
# Regression tests for the Phase 3e category-driven Flatpak Install/Remove menus.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_ROOT="$REPO_ROOT/config/artix-hypr-remix"
MENU="$FRAMEWORK_ROOT/bin/ahr-menu"
CATALOG="$FRAMEWORK_ROOT/default/flatpak/catalog.json"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-flatpak-menu-test-XXXXXXXX)"
TEST_HOME="$TEST_TMP/home"
STUB_DIR="$TEST_TMP/bin"
TERMINAL_LOG="$TEST_TMP/terminal.log"
FLATPAK_LOG="$TEST_TMP/flatpak.log"
ORIGINAL_PATH="$PATH"
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir -p "$TEST_HOME" "$STUB_DIR"

pass() { printf 'PASS: %s\n' "$1"; ((PASS+=1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; ((FAIL+=1)); }

# Fake terminal: log the invocation and exit successfully. The menu will exec
# this, so the menu process is replaced and we inspect the log afterwards. A
# preference file forces the menu's terminal launcher to pick xterm first,
# avoiding host terminals such as ghostty.
mkdir -p "$TEST_HOME/.config"
printf '%s\n' 'xterm.desktop' > "$TEST_HOME/.config/xdg-terminals.list"

cat > "$STUB_DIR/xterm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AHR_TEST_TERMINAL_LOG"
exit 0
EOF
chmod +x "$STUB_DIR/xterm"

# Fake flatpak: log invocations and report a controlled installed set.
cat > "$STUB_DIR/flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AHR_TEST_FLATPAK_LOG"
if [[ "$1" == "info" && "$2" == "--system" ]]; then
  case "$3" in
    app.zen_browser.zen|org.signal.Signal) exit 0 ;;
    *) exit 1 ;;
  esac
fi
exit 0
EOF
chmod +x "$STUB_DIR/flatpak"

run_menu() {
  local slice="$1"
  local input="$2"
  RUN_STATUS=0
  set +e
  RUN_OUTPUT="$(
    HOME="$TEST_HOME" \
    AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    AHR_FLATPAK_CATALOG_PATH="${AHR_TEST_CATALOG_PATH:-$CATALOG}" \
    AHR_LIB_PATH="$FRAMEWORK_ROOT/bin/ahr-lib.sh" \
    AHR_TOGGLE_LIB_PATH="$FRAMEWORK_ROOT/bin/ahr-toggle-lib.sh" \
    AHR_MENU_BACKEND=tty \
    AHR_TEST_TERMINAL_LOG="$TERMINAL_LOG" \
    AHR_TEST_FLATPAK_LOG="$FLATPAK_LOG" \
    PATH="$STUB_DIR:$ORIGINAL_PATH" \
    "$MENU" "$slice" <<< "$input" 2>&1
  )"
  RUN_STATUS=$?
  set -e
}

# Install: browse to a category and dispatch the exact slug.
: > "$TERMINAL_LOG"
run_menu install $'3\n1\n1\n2\n'
if [[ "$RUN_STATUS" == 0 && "$(cat "$TERMINAL_LOG")" == *'ahr flatpak install zen-browser'* ]]; then
  pass "install menu dispatches exact catalog slug"
else
  fail "install menu dispatches exact catalog slug"
fi

# Install: cancel at the confirmation step; no terminal invocation.
: > "$TERMINAL_LOG"
run_menu install $'3\n1\n1\n1\n14\n6\n'
if [[ "$RUN_STATUS" == 0 && ! -s "$TERMINAL_LOG" ]]; then
  pass "install cancellation makes no mutation"
else
  fail "install cancellation makes no mutation"
fi

# Install: category menu omits empty categories and uses display labels.
run_menu install $'3\n'
if [[ "$RUN_OUTPUT" == *'System Utilities'* && "$RUN_OUTPUT" == *'Office & Writing'* \
  && "$RUN_OUTPUT" != *'Gaming'* && "$RUN_OUTPUT" != *'Development'* && "$RUN_OUTPUT" != *'Creative'* ]]; then
  pass "install category menu omits empty categories with display labels"
else
  fail "install category menu omits empty categories with display labels"
fi

# Remove: requires flatpak command before discovery. Use a PATH that lacks both
# the stub and the real flatpak command, but still contains the utilities the
# menu and catalog CLI need to render the discovery UI.
: > "$TERMINAL_LOG"
min_path="$TEST_TMP/min-path"
mkdir -p "$min_path"
for cmd in bash jq readlink dirname cat mkdir mktemp rm sed grep pgrep wc awk tr cut head tail sort uniq seq tput stty tty; do
  if path_cmd="$(command -v "$cmd" 2>/dev/null)" && [[ -n "$path_cmd" ]]; then
    ln -sf "$path_cmd" "$min_path/$cmd"
  fi
done

RUN_STATUS=0
set +e
RUN_OUTPUT="$(
  HOME="$TEST_HOME" \
  AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
  AHR_LIB_PATH="$FRAMEWORK_ROOT/bin/ahr-lib.sh" \
  AHR_TOGGLE_LIB_PATH="$FRAMEWORK_ROOT/bin/ahr-toggle-lib.sh" \
  AHR_MENU_BACKEND=tty \
  PATH="$min_path" \
  "$MENU" remove <<< $'2\n' 2>&1
)"
RUN_STATUS=$?
set -e
if [[ "$RUN_STATUS" == 0 && "$RUN_OUTPUT" == *"ERROR: 'flatpak' is required"* ]]; then
  pass "remove menu requires flatpak before discovery"
else
  fail "remove menu requires flatpak before discovery"
fi

# Remove: only installed catalog entries are offered.
: > "$TERMINAL_LOG"
run_menu remove $'2\n1\n'
if [[ "$RUN_OUTPUT" == *'Zen Browser'* && "$RUN_OUTPUT" == *'Signal'* \
  && "$RUN_OUTPUT" != *'Discord'* && "$RUN_OUTPUT" != *'Obsidian'* ]]; then
  pass "remove menu shows only installed catalog entries"
else
  fail "remove menu shows only installed catalog entries"
fi

# Remove: dispatch the exact slug and confirm data preservation wording.
: > "$TERMINAL_LOG"
run_menu remove $'2\n1\n1\n2\n'
if [[ "$RUN_STATUS" == 0 && "$(cat "$TERMINAL_LOG")" == *'ahr flatpak remove zen-browser'* ]]; then
  pass "remove menu dispatches exact catalog slug"
else
  fail "remove menu dispatches exact catalog slug"
fi

# Remove: cancel at the confirmation step.
: > "$TERMINAL_LOG"
run_menu remove $'2\n1\n1\n1\n3\n5\n'
if [[ "$RUN_STATUS" == 0 && ! -s "$TERMINAL_LOG" ]]; then
  pass "remove cancellation makes no mutation"
else
  fail "remove cancellation makes no mutation"
fi

# Advanced install path: raw flatpak with system scope and flathub.
: > "$TERMINAL_LOG"
run_menu install $'3\n6\n'
if [[ "$RUN_STATUS" == 0 && "$(cat "$TERMINAL_LOG")" == *'flatpak install --system flathub'* ]]; then
  pass "advanced install path uses raw system-scoped flathub command"
else
  fail "advanced install path uses raw system-scoped flathub command"
fi

# Advanced remove path: raw flatpak with system scope and no --delete-data.
: > "$TERMINAL_LOG"
run_menu remove $'2\n4\n'
terminal_log="$(cat "$TERMINAL_LOG")"
if [[ "$RUN_STATUS" == 0 && "$terminal_log" == *'flatpak uninstall --system'* \
  && "$terminal_log" != *'--delete-data'* ]]; then
  pass "advanced remove path uses raw system-scoped uninstall without --delete-data"
else
  fail "advanced remove path uses raw system-scoped uninstall without --delete-data"
fi

# Back navigation from install/remove Flatpak menus exits cleanly.
: > "$TERMINAL_LOG"
run_menu install $'3\n7\n6\n'
if [[ "$RUN_STATUS" == 0 && ! -s "$TERMINAL_LOG" ]]; then
  pass "install back navigation exits without mutation"
else
  fail "install back navigation exits without mutation"
fi

: > "$TERMINAL_LOG"
run_menu remove $'2\n5\n5\n'
if [[ "$RUN_STATUS" == 0 && ! -s "$TERMINAL_LOG" ]]; then
  pass "remove back navigation exits without mutation"
else
  fail "remove back navigation exits without mutation"
fi

# Menu-level trust label rendering (Phase 3e). Install: Communication contains
# a proprietary and two unofficial entries; the submenu must render both flags.
: > "$TERMINAL_LOG"
run_menu install $'3\n2\n'
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'Discord (optional) [Proprietary] [slug: discord]'* \
  && "$RUN_OUTPUT" == *'Vesktop (optional) [Unofficial] [slug: vesktop]'* \
  && "$RUN_OUTPUT" == *'Signal (optional) [Unofficial] [slug: signal]'* ]]; then
  pass "install submenu renders Proprietary and Unofficial labels at menu level"
else
  fail "install submenu renders Proprietary and Unofficial labels at menu level"
fi

# Remove: All Installed Catalog Apps shows the installed entries (Zen = default
# proprietary stub id set, Signal = unofficial) with their flags rendered.
: > "$TERMINAL_LOG"
run_menu remove $'2\n1\n'
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'Signal (optional) [Unofficial] [slug: signal]'* \
  && "$RUN_OUTPUT" == *'Zen Browser (default) [slug: zen-browser]'* ]]; then
  pass "remove submenu renders Unofficial label and unflagged default entry"
else
  fail "remove submenu renders Unofficial label and unflagged default entry"
fi

# Catalog-menu failure visibility: an invalid catalog must surface an actionable
# diagnostic, present no misleading catalog choices, never auto-fall back to the
# advanced raw-ID path, and exit cleanly to the parent menu.
BROKEN_CATALOG="$TEST_TMP/broken-catalog.json"
jq '.schema_version = 2' "$CATALOG" > "$BROKEN_CATALOG"
: > "$TERMINAL_LOG"
AHR_TEST_CATALOG_PATH="$BROKEN_CATALOG" run_menu install $'3\n'
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'catalog query failed'* \
  && "$RUN_OUTPUT" == *'ahr flatpak validate'* \
  && "$RUN_OUTPUT" != *'All Catalog Apps'* \
  && "$RUN_OUTPUT" != *'Advanced: Install by Flatpak ID'* \
  && "$RUN_OUTPUT" != *'Communication'* \
  && ! -s "$TERMINAL_LOG" ]]; then
  pass "invalid catalog install menu shows diagnostic without choices or raw-ID fallback"
else
  fail "invalid catalog install menu shows diagnostic without choices or raw-ID fallback"
fi

# Remove: same guarantee for the removal discovery menu.
: > "$TERMINAL_LOG"
AHR_TEST_CATALOG_PATH="$BROKEN_CATALOG" run_menu remove $'2\n'
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'catalog query failed'* \
  && "$RUN_OUTPUT" == *'ahr flatpak validate'* \
  && "$RUN_OUTPUT" != *'All Installed Catalog Apps'* \
  && "$RUN_OUTPUT" != *'Advanced: Remove by Flatpak ID'* \
  && ! -s "$TERMINAL_LOG" ]]; then
  pass "invalid catalog remove menu shows diagnostic without choices or raw-ID fallback"
else
  fail "invalid catalog remove menu shows diagnostic without choices or raw-ID fallback"
fi

# Missing catalog file is treated the same way as an invalid one.
: > "$TERMINAL_LOG"
AHR_TEST_CATALOG_PATH="$TEST_TMP/no-such-catalog.json" run_menu install $'3\n'
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'catalog query failed'* \
  && "$RUN_OUTPUT" == *'ahr flatpak validate'* \
  && "$RUN_OUTPUT" != *'All Catalog Apps'* \
  && ! -s "$TERMINAL_LOG" ]]; then
  pass "missing catalog install menu shows diagnostic without choices"
else
  fail "missing catalog install menu shows diagnostic without choices"
fi

# After the failure the parent menu is still usable: no app entries rendered,
# and Back exits with no terminal invocation at all.
: > "$TERMINAL_LOG"
AHR_TEST_CATALOG_PATH="$BROKEN_CATALOG" run_menu install $'3\n6\n'
if [[ "$RUN_STATUS" == 0 \
  && "$RUN_OUTPUT" == *'catalog query failed'* \
  && "$RUN_OUTPUT" != *'Discord (optional)'* \
  && "$RUN_OUTPUT" != *'Install: Communication'* \
  && ! -s "$TERMINAL_LOG" ]]; then
  pass "failing catalog menu never renders app entries and exits to the parent menu"
else
  fail "failing catalog menu never renders app entries and exits to the parent menu"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
