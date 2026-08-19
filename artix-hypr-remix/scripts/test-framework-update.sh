#!/usr/bin/env bash
# Offline test suite for Phase 1 framework update and rollback.
#
# Every test asserts exact exit status, output content, state phase,
# and filesystem effects. No false positives.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_BIN="$REPO_ROOT/config/artix-hypr-remix/bin"
UPDATE_FRAMEWORK="$FRAMEWORK_BIN/ahr-update-framework"
UPDATE_AVAILABLE="$FRAMEWORK_BIN/ahr-update-available"
UPDATE="$FRAMEWORK_BIN/ahr-update"
VERSION_LIB="$FRAMEWORK_BIN/ahr-version.sh"
RESTORE_COMPONENT="$FRAMEWORK_BIN/ahr-restore-component"

PASS=0
FAIL=0
tmp_root="$(mktemp -d "/tmp/ahr-test-XXXXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

pass() { echo "  PASS: $1"; ((PASS+=1)); }
fail() { echo "  FAIL: $1" >&2; [[ -n "${2:-}" ]] && echo "    $2" >&2; ((FAIL+=1)); }

# ── Helpers ────────────────────────────────────────────────────────

create_test_repo() {
  local parent="$1" ver="$2" channel="${3:-stable}" migrations="${4:-0}"
  local rd="$parent/repo"
  mkdir -p "$rd/artix-hypr-remix/config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
  for d in bin migrations docs hooks first-run.d default; do
    touch "$rd/artix-hypr-remix/config/artix-hypr-remix/$d/.gitkeep"
  done
  echo "{\"version\":\"$ver\",\"revision\":null,\"channel\":\"$channel\",\"update_source\":\"file://$rd\",\"updated_at\":null}" > "$rd/artix-hypr-remix/config/artix-hypr-remix/framework.json"
  for f in ahr ahr-update ahr-update-framework ahr-update-available ahr-restore-component migrate.sh namespace-install.sh ahr-doctor; do
    echo '#!/usr/bin/env bash' > "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
  done
  # Copy real library files (not commands — those are dummy scripts for testing)
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-lib.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-version.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-cache.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-backup-helper.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-managed-paths.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-theme-lib.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-toggle-lib.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-font-lib.sh"
  chmod 0644 \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-cache.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-managed-paths.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-theme-lib.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-font-lib.sh"
  chmod +x \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-update" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-update-framework" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-update-available" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-restore-component" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/migrate.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/namespace-install.sh" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor" \
    "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh"
  (cd "$rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m "v$ver" >/dev/null)
  printf '%s' "$rd"
}

setup_installed_framework() {
  local home_dir="$1" update_source="${2:-}" extra_migrations="${3:-0}"
  mkdir -p "$home_dir/.config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
  mkdir -p "$home_dir/.config/artix-hypr-remix/current/theme"
  printf 'fallback\n' > "$home_dir/.config/artix-hypr-remix/current/theme.name"
  printf 'background\n' > "$home_dir/.config/artix-hypr-remix/current/theme/background.txt"
  ln -s "theme/background.txt" "$home_dir/.config/artix-hypr-remix/current/background"
  mkdir -p "$home_dir/.local/state/artix-hypr-remix/migrations/skipped"
  mkdir -p "$home_dir/.cache/artix-hypr-remix"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" \
     "$home_dir/.config/artix-hypr-remix/bin/"
  cat > "$home_dir/.config/artix-hypr-remix/bin/ahr-doctor" <<'EOF'
#!/usr/bin/env bash
echo "All checks passed."
exit 0
EOF
  chmod +x "$home_dir/.config/artix-hypr-remix/bin/ahr-doctor"
  cat > "$home_dir/.config/artix-hypr-remix/bin/migrate.sh" <<'EOF'
#!/usr/bin/env bash
FRAMEWORK_ROOT="${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}"
MIGRATION_DIR="$FRAMEWORK_ROOT/migrations"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/migrations"
mkdir -p "$STATE_DIR"
fail=0
shopt -s nullglob
for f in "$MIGRATION_DIR"/*.sh; do
  n="$(basename "$f")"
  [[ -f "$STATE_DIR/$n" ]] && continue
  if ! bash "$f"; then fail=1; break; fi
  touch "$STATE_DIR/$n"
done
shopt -u nullglob
exit $fail
EOF
  chmod +x "$home_dir/.config/artix-hypr-remix/bin/migrate.sh"
  printf '{"version":"0.1.0","revision":null,"channel":"stable","update_source":"%s","updated_at":"2026-07-31T00:00:00Z"}\n' "$update_source" > "$home_dir/.config/artix-hypr-remix/framework.json"
}

run_ahr() {
  local home="$1"; shift
  HOME="$home" XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache" \
  AHR_FRAMEWORK_ROOT="$home/.config/artix-hypr-remix" \
  AHR_LIB_PATH="$home/.config/artix-hypr-remix/bin/ahr-lib.sh" \
    bash "$@"
}

run_namespace_install() {
  local home="$1"; shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache" XDG_DATA_HOME="$home/.local/share" \
  AHR_FRAMEWORK_ROOT="$home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$home/.local/bin" \
    bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" "$@"
}

run_restore_component() {
  local home="$1"; shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache" XDG_DATA_HOME="$home/.local/share" \
  AHR_FRAMEWORK_ROOT="$home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$home/.local/bin" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
    bash "$RESTORE_COMPONENT" "$@"
}

# Read a JSON string value from a file (jq or python3 fallback)
json_get() {
  local file="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // ""' "$file" 2>/dev/null
  else
    python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key',''))" 2>/dev/null
  fi
}

create_current_tree_repo() {
  local parent="$1" ver="$2" channel="${3:-stable}"
  local rd="$parent/repo"
  mkdir -p "$rd/artix-hypr-remix/config"
  cp -a "$REPO_ROOT/config/artix-hypr-remix" "$rd/artix-hypr-remix/config/"
  printf '{"version":"%s","revision":null,"channel":"%s","update_source":"file://%s","updated_at":null}\n' \
    "$ver" "$channel" "$rd" > "$rd/artix-hypr-remix/config/artix-hypr-remix/framework.json"
  (cd "$rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m "current-tree-$ver" >/dev/null)
  printf '%s' "$rd"
}

commit_test_repo() {
  local rd="$1" msg="${2:-update}"
  (cd "$rd" && git add -A && git commit -q -m "$msg" >/dev/null)
}

run_direct_staged_validation() {
  local home="$1" staged="$2" version="$3" commit="$4" channel="$5"
  HOME="$home" XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache" \
  AHR_FRAMEWORK_ROOT="$home/.config/artix-hypr-remix" \
  AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
  AHR_VERSION_LIB_PATH="$FRAMEWORK_BIN/ahr-version.sh" \
  AHR_CACHE_LIB_PATH="$FRAMEWORK_BIN/ahr-cache.sh" \
  AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
    bash -s -- "$UPDATE_FRAMEWORK" "$staged" "$version" "$commit" "$channel" <<'EOF'
set -euo pipefail
update_framework="$1"
staged="$2"
version="$3"
commit="$4"
channel="$5"
set --
source <(sed -n '1,/^# ── Transaction-based/p' "$update_framework")
validate_staged_framework "$staged" "$version" "$commit" "$channel"
EOF
}

# ── Test Cases ────────────────────────────────────────────────────

echo "=== TC1: Direct version comparator ==="

source "$VERSION_LIB"
P=0; F=0
ok() { echo "    PASS: $1"; ((P+=1)); }
nok() { echo "    FAIL: $1" >&2; ((F+=1)); }

# Direct comparator calls — no integration indirection
ahr_version_validate "0.9.0" 2>/dev/null && ok "validate 0.9.0" || nok "validate 0.9.0"
ahr_version_validate "01.0.0" 2>/dev/null && nok "should reject 01.0.0" || ok "reject 01.0.0"
ahr_version_validate "1.foo.0" 2>/dev/null && nok "should reject 1.foo.0" || ok "reject 1.foo.0"
ahr_version_validate "" 2>/dev/null && nok "should reject empty" || ok "reject empty"

got="$(ahr_version_compare "0.9.0" "0.10.0")"
[[ "$got" == "-1" ]] && ok "0.9.0 < 0.10.0" || nok "expected -1, got '$got'"
got="$(ahr_version_compare "1.9.0" "1.10.0")"
[[ "$got" == "-1" ]] && ok "1.9.0 < 1.10.0" || nok "expected -1, got '$got'"
got="$(ahr_version_compare "1.0.0" "1.0.0")"
[[ "$got" == "0" ]] && ok "1.0.0 == 1.0.0" || nok "expected 0, got '$got'"
got="$(ahr_version_compare "1.0.0-alpha.2" "1.0.0-alpha.10")"
[[ "$got" == "-1" ]] && ok "1.0.0-alpha.2 < 1.0.0-alpha.10" || nok "expected -1, got '$got'"
got="$(ahr_version_compare "1.0.0-rc.1" "1.0.0")"
[[ "$got" == "-1" ]] && ok "1.0.0-rc.1 < 1.0.0" || nok "expected -1, got '$got'"

ahr_version_channel "stable" 2>/dev/null && ok "channel stable" || nok "channel stable"
ahr_version_channel "nightly" 2>/dev/null && nok "should reject nightly" || ok "reject nightly"

if (( F > 0 )); then
  fail "Version comparator tests" "F=$F P=$P"
else
  pass "Version comparator tests ($P assertions)"
fi

echo ""
echo "=== TC2: ahr-update-available without vercmp ==="

# Test 0.9.0 vs 0.10.0 comparison without vercmp
tc2_home="$tmp_root/tc2"
mkdir -p "$tc2_home/.config/artix-hypr-remix/bin" "$tc2_home/.local/state/artix-hypr-remix" "$tc2_home/.cache/artix-hypr-remix"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$tc2_home/.config/artix-hypr-remix/bin/"
echo '{"version":"0.9.0","revision":null,"channel":"stable","update_source":"","updated_at":null}' > "$tc2_home/.config/artix-hypr-remix/framework.json"

# With a valid remote source
tc2_repo="$(create_test_repo "$tmp_root" "0.10.0")"
echo "{\"version\":\"0.9.0\",\"revision\":null,\"channel\":\"stable\",\"update_source\":\"file://$tc2_repo\",\"updated_at\":null}" > "$tc2_home/.config/artix-hypr-remix/framework.json"

tc2_json="$(HOME="$tc2_home" XDG_STATE_HOME="$tc2_home/.local/state" XDG_CACHE_HOME="$tc2_home/.cache" AHR_FRAMEWORK_ROOT="$tc2_home/.config/artix-hypr-remix" AHR_LIB_PATH="$tc2_home/.config/artix-hypr-remix/bin/ahr-lib.sh" PATH="/usr/bin:/bin" bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"

# Parse and check framework state
framework_state="$(printf '%s' "$tc2_json" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('framework',''))" 2>/dev/null || echo "")"
if [[ "$framework_state" == "pending" ]]; then
  pass "0.9.0 vs 0.10.0 reports pending without vercmp"
else
  fail "Expected pending, got '$framework_state'" "$tc2_json"
fi

echo ""
echo "=== TC3: Apply uses one authoritative commit ==="

tc3_home="$tmp_root/tc3"
tc3_repo="$(create_test_repo "$tmp_root/tc3_repo" "0.2.0")"
setup_installed_framework "$tc3_home" "file://$tc3_repo"

# Commit A
commit_a="$(cd "$tc3_repo" && git rev-parse HEAD)"
echo "  Commit A: $commit_a"

# Add a unique file to repo
echo "marker-A" > "$tc3_repo/artix-hypr-remix/.gitkeep"
(cd "$tc3_repo" && git add -A && git commit -q -m "add A" >/dev/null)
commit_a2="$(cd "$tc3_repo" && git rev-parse HEAD)"

# Begin discovery
tc3_exit=0
run_ahr "$tc3_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc3_exit=$?

# Check that installed commit matches A
installed_revision="$(python3 -c "import json; d=json.load(open('$tc3_home/.config/artix-hypr-remix/framework.json')); print(d.get('revision',''))" 2>/dev/null || echo "")"
if [[ "$installed_revision" == "$commit_a2" ]]; then
  pass "Installed commit matches commit A"
else
  fail "Expected commit A ($commit_a2), got '$installed_revision'"
fi

echo ""
echo "=== TC4: Apply and rollback cycle ==="

tc4_home="$tmp_root/tc4"
tc4_repo="$(create_test_repo "$tmp_root/tc4_repo" "0.2.0")"
setup_installed_framework "$tc4_home" "file://$tc4_repo"
touch "$tc4_home/.config/artix-hypr-remix/bin/old-cmd" && chmod +x "$tc4_home/.config/artix-hypr-remix/bin/old-cmd"

# Apply
tc4_apply_exit=0
run_ahr "$tc4_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc4_apply_exit=$?

# Assertions
tc4_ver="$(json_get "$tc4_home/.config/artix-hypr-remix/framework.json" version)"
[[ "$tc4_ver" == "0.2.0" ]] && pass "version updated to 0.2.0" || fail "version is '$tc4_ver'"

tc4_nested="$(find "$tc4_home/.config/artix-hypr-remix/bin" -mindepth 2 -type d 2>/dev/null | wc -l)"
(( tc4_nested == 0 )) && pass "no nested directories" || fail "$tc4_nested nested dirs found"

[[ ! -f "$tc4_home/.config/artix-hypr-remix/bin/old-cmd" ]] && pass "old-cmd removed" || fail "old-cmd still present"

[[ -f "$tc4_home/.config/artix-hypr-remix/bin/ahr" ]] && pass "new command present" || fail "new command missing"

# Transaction was created and committed
tc4_tx_count="$(find "$tc4_home/.local/state/artix-hypr-remix/framework-transactions" -name state 2>/dev/null | wc -l)"
(( tc4_tx_count > 0 )) && pass "transaction record created" || fail "no transaction record"

# Stale paths
tc4_stale="$(find "$tc4_home/.config/artix-hypr-remix" -maxdepth 1 \( -name '*.old.*' -o -name '*.new.*' \) 2>/dev/null | wc -l)"
(( tc4_stale == 0 )) && pass "no stale transaction paths" || fail "$tc4_stale stale paths"

# Backup created with manifest
tc4_backup_count="$(find "$tc4_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
(( tc4_backup_count > 0 )) && pass "backup created" || fail "no backup"

tc4_manifest="$(find "$tc4_home/.local/state/artix-hypr-remix/framework-backups" -name manifest.txt 2>/dev/null | head -1)"
[[ -f "$tc4_manifest" ]] && pass "backup manifest exists" || fail "no manifest"
[[ -f "$tc4_manifest" ]] && grep -q 'completed=true' "$tc4_manifest" && pass "manifest has completed=true" || fail "manifest incomplete"

# Rollback
tc4_rb_exit=0
run_ahr "$tc4_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc4_rb_exit=$?
(( tc4_rb_exit == 0 )) && pass "rollback exit 0" || fail "rollback exit $tc4_rb_exit"

tc4_ver_after="$(json_get "$tc4_home/.config/artix-hypr-remix/framework.json" version)"
[[ "$tc4_ver_after" == "0.1.0" ]] && pass "version restored to 0.1.0" || fail "version is '$tc4_ver_after'"

[[ -f "$tc4_home/.config/artix-hypr-remix/bin/old-cmd" ]] && pass "old-cmd restored" || fail "old-cmd not restored"

tc4_rb_stale="$(find "$tc4_home/.config/artix-hypr-remix" -maxdepth 1 \( -name '*.old.*' -o -name '*.new.*' \) 2>/dev/null | wc -l)"
(( tc4_rb_stale == 0 )) && pass "no stale paths after rollback" || fail "$tc4_rb_stale stale after rollback"

echo ""
echo "=== TC5: Doctor failure propagates ==="

tc5_home="$tmp_root/tc5"
tc5_repo="$(create_test_repo "$tmp_root/tc5_repo" "0.2.0")"
setup_installed_framework "$tc5_home" "file://$tc5_repo"
echo '#!/usr/bin/env bash
exit 42' > "$tc5_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
chmod +x "$tc5_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
(cd "$tc5_repo" && git add -A && git commit -q -m "failing doctor")

tc5_exit=0
run_ahr "$tc5_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc5_exit=$?
(( tc5_exit != 0 )) && pass "apply exits nonzero on doctor failure (exit $tc5_exit)" || fail "apply exited 0"

echo ""
echo "=== TC6: ahr-update --framework propagates failure ==="

tc6_home="$tmp_root/tc6"
tc6_repo="$(create_test_repo "$tmp_root/tc6_repo" "0.2.0")"
setup_installed_framework "$tc6_home" "file://$tc6_repo"
echo '#!/usr/bin/env bash
exit 42' > "$tc6_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
chmod +x "$tc6_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
(cd "$tc6_repo" && git add -A && git commit -q -m "failing doctor")
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-update" "$tc6_home/.config/artix-hypr-remix/bin/ahr-update"
chmod +x "$tc6_home/.config/artix-hypr-remix/bin/ahr-update"

tc6_exit=0
run_ahr "$tc6_home" "$tc6_home/.config/artix-hypr-remix/bin/ahr-update" --no-system --no-aur --no-migrate --framework >/dev/null 2>&1 || tc6_exit=$?
(( tc6_exit != 0 )) && pass "ahr-update --framework propagates failure (exit $tc6_exit)" || fail "ahr-update exited 0"

echo ""
echo "=== TC7: No-jq JSON is valid ==="

tc7_home="$tmp_root/tc7"
mkdir -p "$tc7_home/.config/artix-hypr-remix/bin" "$tc7_home/.local/state/artix-hypr-remix" "$tc7_home/.cache/artix-hypr-remix"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$tc7_home/.config/artix-hypr-remix/bin/"
echo '{"version":"0.1.0","revision":null,"channel":"stable","update_source":"","updated_at":null}' > "$tc7_home/.config/artix-hypr-remix/framework.json"

tc7_json="$(HOME="$tc7_home" XDG_STATE_HOME="$tc7_home/.local/state" XDG_CACHE_HOME="$tc7_home/.cache" AHR_FRAMEWORK_ROOT="$tc7_home/.config/artix-hypr-remix" AHR_LIB_PATH="$tc7_home/.config/artix-hypr-remix/bin/ahr-lib.sh" PATH="/usr/bin:/bin" bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"

if printf '%s' "$tc7_json" | python3 -m json.tool >/dev/null 2>&1; then
  pass "no-jq JSON parses as valid"
else
  fail "no-jq JSON invalid" "$tc7_json"
fi

# Verify field types
tc7_system="$(printf '%s' "$tc7_json" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(type(d['system']).__name__)" 2>/dev/null || echo "")"
[[ "$tc7_system" == "int" ]] && pass "system is int" || fail "system is '$tc7_system'"

tc7_theme="$(printf '%s' "$tc7_json" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['theme'])" 2>/dev/null || echo "")"
[[ "$tc7_theme" == "unsupported" ]] && pass "theme is unsupported" || fail "theme is '$tc7_theme'"

echo ""
echo "=== TC8: Staged validation rejects unsupported channel ==="

tc8_home="$tmp_root/tc8"
tc8_rd="$tmp_root/tc8_repo"
mkdir -p "$tc8_rd/artix-hypr-remix/config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
for d in bin migrations docs hooks first-run.d default; do
  touch "$tc8_rd/artix-hypr-remix/config/artix-hypr-remix/$d/.gitkeep"
done
echo '{"version":"0.2.0","revision":null,"channel":"nightly","update_source":"file://'"$tc8_rd"'","updated_at":null}' > "$tc8_rd/artix-hypr-remix/config/artix-hypr-remix/framework.json"
for f in ahr ahr-update ahr-update-framework ahr-update-available migrate.sh namespace-install.sh; do
  echo '#!/usr/bin/env bash' > "$tc8_rd/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" \
   "$tc8_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"
chmod +x "$tc8_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"*
(cd "$tc8_rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m init >/dev/null)
setup_installed_framework "$tc8_home" "file://$tc8_rd"

tc8_exit=0
run_ahr "$tc8_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc8_exit=$?
(( tc8_exit != 0 )) && pass "rejects unsupported channel (exit $tc8_exit)" || fail "accepted unsupported channel"

echo ""
echo "=== TC9: Staged validation rejects malformed version ==="

tc9_home="$tmp_root/tc9"
tc9_rd="$tmp_root/tc9_repo"
mkdir -p "$tc9_rd/artix-hypr-remix/config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
for d in bin migrations docs hooks first-run.d default; do
  touch "$tc9_rd/artix-hypr-remix/config/artix-hypr-remix/$d/.gitkeep"
done
echo '{"version":"1.foo.0","revision":null,"channel":"stable","update_source":"file://'"$tc9_rd"'","updated_at":null}' > "$tc9_rd/artix-hypr-remix/config/artix-hypr-remix/framework.json"
for f in ahr ahr-update ahr-update-framework ahr-update-available migrate.sh namespace-install.sh; do
  echo '#!/usr/bin/env bash' > "$tc9_rd/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" \
   "$tc9_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"
chmod +x "$tc9_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"*
(cd "$tc9_rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m init >/dev/null)
setup_installed_framework "$tc9_home" "file://$tc9_rd"

tc9_exit=0
run_ahr "$tc9_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc9_exit=$?
(( tc9_exit != 0 )) && pass "rejects malformed version (exit $tc9_exit)" || fail "accepted malformed version"

echo ""
echo "=== TC10: Incomplete transaction blocks new apply ==="

tc10_home="$tmp_root/tc10"
tc10_repo="$(create_test_repo "$tmp_root/tc10_repo" "0.2.0")"
setup_installed_framework "$tc10_home" "file://$tc10_repo"

# Create a fake incomplete transaction
mkdir -p "$tc10_home/.local/state/artix-hypr-remix/framework-transactions/tx-fake-XXXX"
mkdir -p "$tmp_root/tc10_tx"
mv "$tc10_home/.local/state/artix-hypr-remix/framework-transactions/tx-fake-XXXX" "$tmp_root/tc10_tx/" 2>/dev/null || true
mkdir -p "$tc10_home/.local/state/artix-hypr-remix/framework-transactions/tx-fakeincomplete"
cat > "$tc10_home/.local/state/artix-hypr-remix/framework-transactions/tx-fakeincomplete/state" <<EOF
txid=tx-fakeincomplete
action=apply
pid=99999
target_version=0.2.0
staging_commit=abc
backup_dir=/nonexistent
phase=activation_in_progress
completion=in_progress
EOF

tc10_exit=0
run_ahr "$tc10_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc10_exit=$?
(( tc10_exit != 0 )) && pass "incomplete transaction blocks apply (exit $tc10_exit)" || fail "apply proceeded with incomplete tx"

# Cleanup
rm -rf "$tc10_home/.local/state/artix-hypr-remix/framework-transactions/tx-fakeincomplete"

echo ""
echo "=== TC11: Backup collision resistance ==="

tc11_home="$tmp_root/tc11"
tc11_repo="$(create_test_repo "$tmp_root/tc11_repo" "0.2.0")"
setup_installed_framework "$tc11_home" "file://$tc11_repo"

# Create multiple backups rapidly
for i in 1 2 3 4 5; do
  run_ahr "$tc11_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || true
  run_ahr "$tc11_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || true
done

tc11_dirs="$(find "$tc11_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
(( tc11_dirs >= 4 )) && pass "rapid backups produced $tc11_dirs unique dirs" || fail "expected >=4 backup dirs, got $tc11_dirs"

# Verify all have unique names
tc11_unique="$(find "$tc11_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -u | wc -l)"
(( tc11_unique == tc11_dirs )) && pass "all backup dirs unique" || fail "duplicate backup dirs: $tc11_dirs total, $tc11_unique unique"

echo ""
echo "=== TC12: Staged validation rejects broken migration ==="

tc12_home="$tmp_root/tc12"
tc12_rd="$tmp_root/tc12_repo"
mkdir -p "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
for d in bin migrations docs hooks first-run.d default; do
  touch "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix/$d/.gitkeep"
done
echo '{"version":"0.2.0","revision":null,"channel":"stable","update_source":"file://'"$tc12_rd"'","updated_at":null}' > "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix/framework.json"
for f in ahr ahr-update ahr-update-framework ahr-update-available migrate.sh namespace-install.sh; do
  echo '#!/usr/bin/env bash' > "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
# Add a broken migration
echo '#!/usr/bin/env bash
if true; then
  echo "error"
fi
else
  echo "ok"
fi' > "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix/migrations/20260801-broken.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" \
   "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"
chmod +x "$tc12_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"*
(cd "$tc12_rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m init >/dev/null)
setup_installed_framework "$tc12_home" "file://$tc12_rd"

tc12_exit=0
run_ahr "$tc12_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc12_exit=$?
(( tc12_exit != 0 )) && pass "rejects broken migration (exit $tc12_exit)" || fail "accepted broken migration"

echo ""
echo "=== TC13: Staged validation rejects external symlink ==="

tc13_home="$tmp_root/tc13"
tc13_rd="$tmp_root/tc13_repo"
mkdir -p "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
for d in bin migrations docs hooks first-run.d default; do
  touch "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix/$d/.gitkeep"
done
echo '{"version":"0.2.0","revision":null,"channel":"stable","update_source":"file://'"$tc13_rd"'","updated_at":null}' > "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix/framework.json"
for f in ahr ahr-update ahr-update-framework ahr-update-available migrate.sh namespace-install.sh; do
  echo '#!/usr/bin/env bash' > "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
# Create an external symlink in docs/
mkdir -p "$tmp_root/tc13_external"
echo "external" > "$tmp_root/tc13_external/file.txt"
ln -s "$tmp_root/tc13_external/file.txt" "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix/docs/external-link"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" \
   "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"
chmod +x "$tc13_rd/artix-hypr-remix/config/artix-hypr-remix/bin/"*
(cd "$tc13_rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m init >/dev/null)
setup_installed_framework "$tc13_home" "file://$tc13_rd"

tc13_exit=0
run_ahr "$tc13_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc13_exit=$?
(( tc13_exit != 0 )) && pass "rejects external symlink (exit $tc13_exit)" || fail "accepted external symlink"

echo ""
echo "=== TC14: Rollback refuses incomplete backup ==="

tc14_home="$tmp_root/tc14"
tc14_repo="$(create_test_repo "$tmp_root/tc14_repo" "0.2.0")"
setup_installed_framework "$tc14_home" "file://$tc14_repo"

# Create a backup then delete part of it
run_ahr "$tc14_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || true
# Find the backup and remove docs/ from it
tc14_backup="$(find "$tc14_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
rm -rf "$tc14_backup/docs"

tc14_exit=0
run_ahr "$tc14_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc14_exit=$?
(( tc14_exit != 0 )) && pass "rollback refuses incomplete backup (exit $tc14_exit)" || fail "rollback succeeded with incomplete backup"

# Verify framework was NOT modified
tc14_ver="$(json_get "$tc14_home/.config/artix-hypr-remix/framework.json" version)"
[[ "$tc14_ver" == "0.2.0" ]] && pass "framework not modified on rollback refusal" || fail "version changed to '$tc14_ver'"

echo ""
echo "=== TC15: ahr-restore-component --list ==="

tc15_list="$(HOME="$tmp_root" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" bash "$RESTORE_COMPONENT" --list 2>&1)"
echo "$tc15_list" | grep -q "framework-config" && pass "lists framework-config" || fail "missing framework-config"
echo "$tc15_list" | grep -q "theme-state" && pass "lists theme-state" || fail "missing theme-state"

echo ""
echo "=== TC16: ahr-restore-component refuses unsafe component without --apply ==="

tc16_home="$tmp_root/tc16"
mkdir -p "$tc16_home/.config/artix-hypr-remix/current" "$tc16_home/.local/state/artix-hypr-remix/framework-backups/test-bk"
echo "current" > "$tc16_home/.config/artix-hypr-remix/current/marker"
cp -a "$tc16_home/.config/artix-hypr-remix/current" "$tc16_home/.local/state/artix-hypr-remix/framework-backups/test-bk/derived-theme-state"
cat > "$tc16_home/.local/state/artix-hypr-remix/framework-backups/test-bk/manifest.txt" <<EOF
manifest_version=1
completed=true
previous_version=0.1.0
new_version=0.2.0
EOF

tc16_exit=0
run_restore_component "$tc16_home" chromium-theme --backup test-bk >/dev/null 2>&1 || tc16_exit=$?
(( tc16_exit != 0 )) && pass "refuses structured-file component without --apply" || fail "accepted structured-file without --apply"

# With --apply, should succeed
tc16_apply_exit=0
run_restore_component "$tc16_home" theme-state --backup test-bk --apply >/dev/null 2>&1 || tc16_apply_exit=$?
(( tc16_apply_exit == 0 )) && pass "accepts unsafe component with --apply" || fail "rejected with --apply"

echo ""
echo "=== TC17: Production namespace symlinks resolve libraries ==="

tc17_home="$tmp_root/tc17"
mkdir -p "$tc17_home/.config" "$tc17_home/.local/state"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc17_home/.config/"
tc17_setup=0
run_namespace_install "$tc17_home" --quiet >/dev/null || tc17_setup=$?
(( tc17_setup == 0 )) && pass "namespace setup succeeds" || fail "namespace setup failed (exit $tc17_setup)"

tc17_status=0
HOME="$tc17_home" XDG_CONFIG_HOME="$tc17_home/.config" XDG_STATE_HOME="$tc17_home/.local/state" XDG_CACHE_HOME="$tc17_home/.cache" XDG_DATA_HOME="$tc17_home/.local/share" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr-update-framework" --status >"$tmp_root/tc17-status.out" 2>&1 || tc17_status=$?
(( tc17_status == 0 )) && pass "namespace ahr-update-framework --status" || fail "namespace status exit $tc17_status" "$(cat "$tmp_root/tc17-status.out")"

tc17_avail=0
HOME="$tc17_home" XDG_CONFIG_HOME="$tc17_home/.config" XDG_STATE_HOME="$tc17_home/.local/state" XDG_CACHE_HOME="$tc17_home/.cache" XDG_DATA_HOME="$tc17_home/.local/share" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr-update-available" --json >"$tmp_root/tc17-available.out" 2>&1 || tc17_avail=$?
# Exit 0 or 1 is valid for availability; missing-library errors are never valid.
if [[ "$tc17_avail" == "0" || "$tc17_avail" == "1" ]] && ! grep -q 'No such file\|ahr-version.sh' "$tmp_root/tc17-available.out"; then
  pass "namespace ahr-update-available resolves libraries"
else
  fail "namespace availability failed" "$(cat "$tmp_root/tc17-available.out")"
fi

tc17_restore=0
HOME="$tc17_home" XDG_CONFIG_HOME="$tc17_home/.config" XDG_STATE_HOME="$tc17_home/.local/state" XDG_CACHE_HOME="$tc17_home/.cache" XDG_DATA_HOME="$tc17_home/.local/share" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr-restore-component" --list >"$tmp_root/tc17-restore.out" 2>&1 || tc17_restore=$?
if [[ "$tc17_restore" == "0" ]] && grep -q 'framework-config' "$tmp_root/tc17-restore.out"; then
  pass "namespace ahr-restore-component --list"
else
  fail "namespace restore-component failed" "$(cat "$tmp_root/tc17-restore.out")"
fi

tc17_dispatch=0
HOME="$tc17_home" XDG_CONFIG_HOME="$tc17_home/.config" XDG_STATE_HOME="$tc17_home/.local/state" XDG_CACHE_HOME="$tc17_home/.cache" XDG_DATA_HOME="$tc17_home/.local/share" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr" restore-component --list >"$tmp_root/tc17-dispatch.out" 2>&1 || tc17_dispatch=$?
if [[ "$tc17_dispatch" == "0" ]] && grep -q 'theme-state' "$tmp_root/tc17-dispatch.out"; then
  pass "ahr dispatcher restore-component"
else
  fail "dispatcher restore-component failed" "$(cat "$tmp_root/tc17-dispatch.out")"
fi

echo ""
echo "=== TC18: Real failed migration preserves complete transaction state ==="

tc18_home="$tmp_root/tc18"
tc18_repo_dir="$tmp_root/tc18_repo"
mkdir -p "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin" \
         "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/migrations" \
         "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/docs" \
         "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/hooks" \
         "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/first-run.d" \
         "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/default"
for d in bin migrations docs hooks first-run.d default; do
  touch "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/$d/.gitkeep"
done
echo '{"version":"0.2.0","revision":null,"channel":"stable","update_source":"file://'"$tc18_repo_dir"'","updated_at":null}' > "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/framework.json"
for f in ahr ahr-update ahr-update-framework ahr-update-available ahr-restore-component namespace-install.sh ahr-doctor; do
  echo '#!/usr/bin/env bash' > "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-lib.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-version.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-cache.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-backup-helper.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-managed-paths.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-managed-paths.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-validate-managed-paths.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-theme-lib.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-theme-lib.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-toggle-lib.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-toggle-lib.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-font-lib.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-font-lib.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/migrate.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/migrate.sh"
# Add a failing migration file in the migrations directory
echo '#!/usr/bin/env bash
echo "migration side effect" >> "$HOME/.config/artix-hypr-remix/migrations.log"
exit 1' > "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/migrations/20260801-failing-migration.sh"
chmod +x "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/"*
chmod +x "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/migrations/"*
(cd "$tc18_repo_dir" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m "v0.2.0" >/dev/null)

setup_installed_framework "$tc18_home" "file://$tc18_repo_dir"

run_ahr "$tc18_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || true

tx_state_file="$(find "$tc18_home/.local/state/artix-hypr-remix/framework-transactions" -name state 2>/dev/null | head -1)"
if [[ -n "$tx_state_file" ]]; then
  pass "transaction state exists after failed migration"
  for key in txid action pid target_version staging_commit backup_dir phase completion; do
    grep -q "^${key}=" "$tx_state_file" && pass "state has $key" || fail "state missing $key"
  done
  grep -q '^completion=migration_failed' "$tx_state_file" && pass "completion=migration_failed recorded" || fail "completion marker missing"
  grep -q '^phase=migration_failed' "$tx_state_file" && pass "phase=migration_failed recorded" || fail "phase marker missing"
  grep -q '^backup_dir=' "$tx_state_file" && pass "backup_dir preserved" || fail "backup_dir missing"
  grep -q '^recovery_command=' "$tx_state_file" && pass "recovery_command recorded" || fail "recovery_command missing"
else
  fail "no transaction state after failed migration"
fi

# A subsequent apply must be refused because the failed transaction is still unresolved.
tc18_apply2=0
run_ahr "$tc18_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc18_apply2=$?
(( tc18_apply2 != 0 )) && pass "subsequent apply refused (exit $tc18_apply2)" || fail "apply proceeded with unresolved failure"

echo ""
echo "=== TC19: Doctor failure retains complete unresolved transaction state ==="

tc19_home="$tmp_root/tc19"
tc19_repo="$(create_test_repo "$tmp_root/tc19_repo" "0.2.0")"
setup_installed_framework "$tc19_home" "file://$tc19_repo"
echo '#!/usr/bin/env bash
exit 7' > "$tc19_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
chmod +x "$tc19_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
(cd "$tc19_repo" && git add -A && git commit -q -m "failing doctor" >/dev/null)

run_ahr "$tc19_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || true

tc19_state="$(find "$tc19_home/.local/state/artix-hypr-remix/framework-transactions" -name state 2>/dev/null | head -1)"
if [[ -n "$tc19_state" ]]; then
  grep -q '^phase=health_check_failed' "$tc19_state" && pass "phase=health_check_failed recorded" || fail "health phase marker missing"
  grep -q '^completion=health_check_failed' "$tc19_state" && pass "completion=health_check_failed recorded" || fail "health completion marker missing"
  grep -q 'doctor_exit=' "$tc19_state" && pass "doctor_exit recorded" || fail "doctor_exit missing"
  grep -q 'recovery_command=' "$tc19_state" && pass "recovery_command recorded" || fail "recovery_command missing"
else
  fail "no transaction state after doctor failure"
fi

tc19_apply2=0
run_ahr "$tc19_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc19_apply2=$?
(( tc19_apply2 != 0 )) && pass "apply refused after doctor failure" || fail "apply proceeded after doctor failure"

# Rollback restores previous framework (including passing doctor from backup).
# The backup was created before activation, so it contains the previous (passing) doctor.
tc19_rb=0
run_ahr "$tc19_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc19_rb=$?
# Rollback may exit 0 (doctor passes from backup) or 1 (doctor still fails)
(( tc19_rb == 0 || tc19_rb == 1 )) && pass "rollback completed (exit $tc19_rb)" || fail "rollback exit $tc19_rb"

tc19_post="$(json_get "$tc19_home/.config/artix-hypr-remix/framework.json" version)"
[[ "$tc19_post" == "0.1.0" ]] && pass "version restored after rollback" || fail "version is $tc19_post"

# The doctor should now be the restored (passing) version
tc19_doc="$tc19_home/.config/artix-hypr-remix/bin/ahr-doctor"
if [[ -f "$tc19_doc" ]] && grep -q 'exit 0' "$tc19_doc"; then
  pass "doctor restored to passing version"
else
  fail "doctor not restored to passing version"
fi

echo ""
echo "=== TC20: Namespace installation runs during apply ==="

tc20_home="$tmp_root/tc20"
tc20_repo="$(create_test_repo "$tmp_root/tc20_repo" "0.2.0")"
setup_installed_framework "$tc20_home" "file://$tc20_repo"

# Replace namespace-install.sh in the staged repo with one that creates a marker
cat > "$tc20_repo/artix-hypr-remix/config/artix-hypr-remix/bin/namespace-install.sh" <<'NSEQ'
#!/usr/bin/env bash
set -euo pipefail
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/namespace-installed.marker"
NSEQ
chmod +x "$tc20_repo/artix-hypr-remix/config/artix-hypr-remix/bin/namespace-install.sh"
(cd "$tc20_repo" && git add -A && git commit -q -m "namespace marker" >/dev/null)

tc20_exit=0
run_ahr "$tc20_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc20_exit=$?
(( tc20_exit == 0 )) && pass "apply with namespace marker succeeds" || fail "apply exit $tc20_exit"

if [[ -f "$tc20_home/.config/artix-hypr-remix/namespace-installed.marker" ]]; then
  pass "namespace-installed.marker exists after apply"
else
  fail "namespace-installed.marker not found"
fi

echo ""
echo "=== TC21: Namespace failure stops migrations and doctor ==="

tc21_home="$tmp_root/tc21"
tc21_repo="$(create_test_repo "$tmp_root/tc21_repo" "0.2.0")"
setup_installed_framework "$tc21_home" "file://$tc21_repo"

# Add a migration that creates a marker (should NOT run if namespace fails)
mkdir -p "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/migrations"
cat > "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/migrations/20260802-test-migration.sh" <<'MIGEOF'
#!/usr/bin/env bash
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/migration-ran.marker"
exit 0
MIGEOF
chmod +x "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/migrations/20260802-test-migration.sh"

# Replace namespace-install.sh with one that exits 42
cat > "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/bin/namespace-install.sh" <<'NSEQ'
#!/usr/bin/env bash
exit 42
NSEQ
chmod +x "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/bin/namespace-install.sh"

# Replace ahr-doctor with one that creates a marker (should NOT run)
cat > "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor" <<'DOCEOF'
#!/usr/bin/env bash
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/doctor-ran.marker"
exit 0
DOCEOF
chmod +x "$tc21_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"

(cd "$tc21_repo" && git add -A && git commit -q -m "failing namespace" >/dev/null)

tc21_exit=0
run_ahr "$tc21_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc21_exit=$?
(( tc21_exit != 0 )) && pass "apply fails on namespace exit 42 (exit $tc21_exit)" || fail "apply succeeded despite namespace failure"

# Migrations must NOT have run
if [[ ! -f "$tc21_home/.config/artix-hypr-remix/migration-ran.marker" ]]; then
  pass "migration did not run after namespace failure"
else
  fail "migration ran despite namespace failure"
fi

# Doctor must NOT have run
if [[ ! -f "$tc21_home/.config/artix-hypr-remix/doctor-ran.marker" ]]; then
  pass "doctor did not run after namespace failure"
else
  fail "doctor ran despite namespace failure"
fi

# Transaction state must record namespace_failed
tc21_tx="$(find "$tc21_home/.local/state/artix-hypr-remix/framework-transactions" -name state 2>/dev/null | head -1)"
if [[ -n "$tc21_tx" ]]; then
  grep -q '^phase=namespace_failed' "$tc21_tx" && pass "phase=namespace_failed recorded" || fail "phase not namespace_failed"
  grep -q '^completion=namespace_failed' "$tc21_tx" && pass "completion=namespace_failed recorded" || fail "completion not namespace_failed"
  grep -q 'namespace_exit=' "$tc21_tx" && pass "namespace_exit recorded" || fail "namespace_exit missing"
  grep -q 'recovery_command=' "$tc21_tx" && pass "recovery_command recorded" || fail "recovery_command missing"
else
  fail "no transaction state after namespace failure"
fi

# Backup must still exist
tc21_backup="$(find "$tc21_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
[[ -n "$tc21_backup" ]] && pass "backup preserved after namespace failure" || fail "backup missing"

# Subsequent apply must be refused (unresolved transaction)
tc21_apply2=0
run_ahr "$tc21_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc21_apply2=$?
(( tc21_apply2 != 0 )) && pass "subsequent apply refused after namespace failure" || fail "apply proceeded with unresolved namespace failure"

echo ""
echo "=== TC22: Valid-cache availability check second invocation ==="

tc22_home="$tmp_root/tc22"
mkdir -p "$tc22_home/.config/artix-hypr-remix/bin" "$tc22_home/.local/state/artix-hypr-remix" "$tc22_home/.cache/artix-hypr-remix"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$tc22_home/.config/artix-hypr-remix/bin/"

tc22_repo="$(create_test_repo "$tmp_root/tc22_repo" "0.10.0")"
echo "{\"version\":\"0.9.0\",\"revision\":null,\"channel\":\"stable\",\"update_source\":\"file://$tc22_repo\",\"updated_at\":null}" > "$tc22_home/.config/artix-hypr-remix/framework.json"

tc22_env="HOME=$tc22_home XDG_STATE_HOME=$tc22_home/.local/state XDG_CACHE_HOME=$tc22_home/.cache AHR_FRAMEWORK_ROOT=$tc22_home/.config/artix-hypr-remix AHR_LIB_PATH=$tc22_home/.config/artix-hypr-remix/bin/ahr-lib.sh PATH=/usr/bin:/bin"

# First invocation — creates cache
tc22_json1="$(eval $tc22_env bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"

# Second invocation — must use cache, must NOT produce "local: can only be used in a function" error
tc22_json2="$(eval $tc22_env bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"

if printf '%s' "$tc22_json2" | grep -q 'local: can only be used in a function'; then
  fail "second invocation produced 'local: can only be used in a function' error"
else
  pass "no top-level local error on second invocation"
fi

# Both must parse as valid JSON
if printf '%s' "$tc22_json1" | python3 -m json.tool >/dev/null 2>&1; then
  pass "first invocation JSON valid"
else
  fail "first invocation JSON invalid" "$tc22_json1"
fi
if printf '%s' "$tc22_json2" | python3 -m json.tool >/dev/null 2>&1; then
  pass "second invocation JSON valid"
else
  fail "second invocation JSON invalid" "$tc22_json2"
fi

# Both must return equivalent framework state
tc22_f1="$(printf '%s' "$tc22_json1" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('framework',''))" 2>/dev/null || echo "")"
tc22_f2="$(printf '%s' "$tc22_json2" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('framework',''))" 2>/dev/null || echo "")"
[[ "$tc22_f1" == "$tc22_f2" ]] && pass "framework state consistent across invocations" || fail "framework state mismatch: '$tc22_f1' vs '$tc22_f2'"

# Cache file must exist after first invocation
[[ -f "$tc22_home/.cache/artix-hypr-remix/framework-remote.cache" ]] && pass "cache file created" || fail "cache file missing"

# Invalid cache must not be treated as valid when the remote is unavailable.
sed -i 's/^version=.*/version=bad version/' "$tc22_home/.cache/artix-hypr-remix/framework-remote.cache"
mv "$tc22_repo" "$tc22_repo.offline"
tc22_json3="$(eval $tc22_env bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"
tc22_f3="$(printf '%s' "$tc22_json3" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('framework',''))" 2>/dev/null || echo "")"
[[ "$tc22_f3" == "unavailable" ]] && pass "invalid cache unavailable remote reports unavailable" || fail "invalid cache reused with unavailable remote: '$tc22_f3'"

echo ""
echo "=== TC23: Cache schema validation ==="

# All production cache writes must contain format_version=1 and mode 600
tc23_cache_dir="$tmp_root/tc23_cache"
mkdir -p "$tc23_cache_dir"
tc23_cache="$tc23_cache_dir/test.cache"

# Source ahr-cache.sh and write a test record
source "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh"
write_cache_record "$tc23_cache" "0.2.0" "https://example.com/repo.git" "stable" "abc123def456789012345678901234567890abcd" 2>/dev/null

if [[ -f "$tc23_cache" ]]; then
  # Must contain format_version=1
  grep -q '^format_version=1$' "$tc23_cache" && pass "cache contains format_version=1" || fail "cache missing format_version=1"

  # Must have mode 600
  tc23_perm="$(stat -c %a "$tc23_cache" 2>/dev/null || echo "")"
  [[ "$tc23_perm" == "600" ]] && pass "cache mode is 600" || fail "cache mode is '$tc23_perm'"

  # Must be valid
  validate_cache_record "$tc23_cache" && pass "cache record validates" || fail "cache record invalid"
else
  fail "cache file not created"
fi

# Verify atomicity: write should leave previous cache intact on success
tc23_cache2="$tc23_cache_dir/test2.cache"
write_cache_record "$tc23_cache2" "0.3.0" "https://example.com/repo.git" "stable" "abc123def456789012345678901234567890abcd" 2>/dev/null
[[ -f "$tc23_cache2" ]] && pass "second cache write succeeded" || fail "second cache write failed"
grep -q '^version=0.3.0$' "$tc23_cache2" && pass "second cache has correct version" || fail "second cache version wrong"

# Reject multiline values
tc23_bad="$tc23_cache_dir/bad.cache"
cat > "$tc23_bad" <<'EOF'
format_version=1
timestamp=12345
source=https://example.com
channel=stable
version=0.1.0
commit=abc
invalid=value
with
newlines
EOF
validate_cache_record "$tc23_bad" && fail "accepted multiline values" || pass "rejected multiline values"

# Reject unsupported format version
tc23_bad2="$tc23_cache_dir/bad2.cache"
cat > "$tc23_bad2" <<'EOF'
format_version=99
timestamp=12345
source=https://example.com
channel=stable
version=0.1.0
commit=abc123def456789012345678901234567890abcd
EOF
validate_cache_record "$tc23_bad2" && fail "accepted unsupported format version" || pass "rejected unsupported format version"

write_cache_fixture() {
  local file="$1"
  cat > "$file" <<'EOF'
format_version=1
timestamp=12345
source=https://example.com/repo.git
channel=stable
version=0.1.0
commit=abc123def456789012345678901234567890abcd
EOF
}

for tc23_empty_key in format_version timestamp source channel version commit; do
  tc23_empty="$tc23_cache_dir/empty-$tc23_empty_key.cache"
  write_cache_fixture "$tc23_empty"
  sed -i "s|^$tc23_empty_key=.*|$tc23_empty_key=|" "$tc23_empty"
  validate_cache_record "$tc23_empty" && fail "accepted empty cache $tc23_empty_key" || pass "rejected empty cache $tc23_empty_key"
done

tc23_bad_version="$tc23_cache_dir/bad-version.cache"
write_cache_fixture "$tc23_bad_version"
sed -i 's/^version=.*/version=bad version/' "$tc23_bad_version"
validate_cache_record "$tc23_bad_version" && fail "accepted cache version with whitespace" || pass "rejected cache version with whitespace"

tc23_bad_version2="$tc23_cache_dir/bad-version2.cache"
write_cache_fixture "$tc23_bad_version2"
sed -i 's/^version=.*/version=1.foo.0/' "$tc23_bad_version2"
validate_cache_record "$tc23_bad_version2" && fail "accepted invalid cache version" || pass "rejected invalid cache version"

tc23_bad_channel="$tc23_cache_dir/bad-channel.cache"
write_cache_fixture "$tc23_bad_channel"
sed -i 's/^channel=.*/channel=nightly/' "$tc23_bad_channel"
validate_cache_record "$tc23_bad_channel" && fail "accepted unsupported cache channel" || pass "rejected unsupported cache channel"

tc23_dup_source="$tc23_cache_dir/dup-source.cache"
write_cache_fixture "$tc23_dup_source"
printf '%s\n' 'source=https://duplicate.example/repo.git' >> "$tc23_dup_source"
validate_cache_record "$tc23_dup_source" && fail "accepted duplicate cache source" || pass "rejected duplicate cache source"

tc23_dup_version="$tc23_cache_dir/dup-version.cache"
write_cache_fixture "$tc23_dup_version"
printf '%s\n' 'version=0.3.0' >> "$tc23_dup_version"
validate_cache_record "$tc23_dup_version" && fail "accepted duplicate cache version" || pass "rejected duplicate cache version"

tc23_bad_commit="$tc23_cache_dir/bad-commit.cache"
write_cache_fixture "$tc23_bad_commit"
sed -i 's/^commit=.*/commit=notasha/' "$tc23_bad_commit"
validate_cache_record "$tc23_bad_commit" && fail "accepted invalid cache commit" || pass "rejected invalid cache commit"

tc23_source_mismatch="$tc23_cache_dir/source-mismatch.cache"
write_cache_fixture "$tc23_source_mismatch"
validate_cache_consistency "$tc23_source_mismatch" "https://other.example/repo.git" "stable" 900 && fail "accepted cache source mismatch" || pass "rejected cache source mismatch"

tc23_channel_mismatch="$tc23_cache_dir/channel-mismatch.cache"
write_cache_fixture "$tc23_channel_mismatch"
validate_cache_consistency "$tc23_channel_mismatch" "https://example.com/repo.git" "beta" 900 && fail "accepted cache channel mismatch" || pass "rejected cache channel mismatch"

tc23_expired="$tc23_cache_dir/expired.cache"
write_cache_fixture "$tc23_expired"
tc23_old_ts="$(( $(date +%s) - 9999 ))"
sed -i "s/^timestamp=.*/timestamp=$tc23_old_ts/" "$tc23_expired"
validate_cache_consistency "$tc23_expired" "https://example.com/repo.git" "stable" 900 && fail "accepted expired cache" || pass "rejected expired cache"

echo ""
echo "=== TC24: Migration lock identity consistency ==="

# Verify that migrate.sh and restore_migration_state use the same lock paths
tc24_migrate_lock="$(grep -F 'LOCK_FILE=' "$REPO_ROOT/config/artix-hypr-remix/bin/migrate.sh" | head -n1)"
tc24_migrate_dir="$(grep -F 'LOCK_DIR=' "$REPO_ROOT/config/artix-hypr-remix/bin/migrate.sh" | head -n1)"

# Check that restore_migration_state uses the same flock path and mkdir path
tc24_restore_uses_migrate_lock="$(grep -c 'MIGRATION_STATE_DIR/migrate.lock' "$UPDATE_FRAMEWORK")"
tc24_restore_uses_migrate_dir="$(grep -c 'MIGRATION_STATE_DIR/.migrate.lock' "$UPDATE_FRAMEWORK")"

(( tc24_restore_uses_migrate_lock > 0 )) && pass "restore uses same flock file as migrate" || fail "restore flock path mismatch"
(( tc24_restore_uses_migrate_dir > 0 )) && pass "restore uses same mkdir dir as migrate" || fail "restore mkdir dir mismatch"

# Must NOT reference .restore-migrate.lock
tc24_bad_lock="$(grep -c '\.restore-migrate\.lock' "$UPDATE_FRAMEWORK" || true)"
[[ "$tc24_bad_lock" == "0" ]] && pass "no .restore-migrate.lock references" || fail "found .restore-migrate.lock references"

echo ""
echo "=== TC25: Migration marker restoration is transactional ==="

tc25_home="$tmp_root/tc25"
mkdir -p "$tc25_home/.config/artix-hypr-remix/bin"
mkdir -p "$tc25_home/.local/state/artix-hypr-remix/migrations/skipped"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
   "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-backup-helper.sh" \
   "$tc25_home/.config/artix-hypr-remix/bin/"

# Set up initial migration state with pre-existing markers
touch "$tc25_home/.local/state/artix-hypr-remix/migrations/pre-existing.sh"
touch "$tc25_home/.local/state/artix-hypr-remix/migrations/skipped/pre-existing-skipped.sh"

# Create a snapshot that should restore: only pre-existing.sh applied, no skipped
tc25_snapshot="$tmp_root/tc25_snapshot"
mkdir -p "$tc25_snapshot/applied" "$tc25_snapshot/skipped"
touch "$tc25_snapshot/applied/pre-existing.sh"

# Create an empty snapshot directory (no applied, no skipped)
tc25_empty_snapshot="$tmp_root/tc25_empty_snapshot"
mkdir -p "$tc25_empty_snapshot/applied" "$tc25_empty_snapshot/skipped"

# Source the framework and test restore
source "$UPDATE_FRAMEWORK" <<< "" 2>/dev/null || true

# We need to source ahr-update-framework to get the restore_migration_state function
# But it calls die/exit. Let's source just the function definitions.
# Instead, test by invoking the full restore through a subshell.

# Test: restore from snapshot with pre-existing marker
# After restore, pre-existing.sh must exist, pre-existing-skipped.sh must NOT exist
tc25_err=0
(
  export AHR_FRAMEWORK_ROOT="$tc25_home/.config/artix-hypr-remix"
  export XDG_STATE_HOME="$tc25_home/.local/state"
  export AHR_LIB_PATH="$tc25_home/.config/artix-hypr-remix/bin/ahr-lib.sh"
  source "$tc25_home/.config/artix-hypr-remix/bin/ahr-lib.sh"
  source "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh"
  source "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh"

  # Define variables that the sed extraction misses
  STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"
  MIGRATION_STATE_DIR="$STATE_ROOT/migrations"
  MIGRATION_SKIPPED_DIR="$MIGRATION_STATE_DIR/skipped"

  # Source only the functions from ahr-update-framework (not main)
  eval "$(sed -n '/^MIGRATION_DIR=/,/^case.*mode/p' "$UPDATE_FRAMEWORK" | head -n -1)"
  restore_migration_state "$tc25_snapshot"
) 2>/dev/null || tc25_err=$?

if (( tc25_err == 0 )); then
  pass "restore_migration_state succeeded"
else
  fail "restore_migration_state failed (exit $tc25_err)"
fi

# pre-existing.sh must exist
[[ -f "$tc25_home/.local/state/artix-hypr-remix/migrations/pre-existing.sh" ]] && pass "pre-existing marker preserved" || fail "pre-existing marker lost"

# pre-existing-skipped.sh must NOT exist (not in snapshot)
[[ ! -f "$tc25_home/.local/state/artix-hypr-remix/migrations/skipped/pre-existing-skipped.sh" ]] && pass "skipped marker removed (not in snapshot)" || fail "skipped marker not removed"

# Test: newly introduced markers must disappear after restore from empty snapshot
touch "$tc25_home/.local/state/artix-hypr-remix/migrations/new-marker.sh"
tc25_err2=0
(
  export AHR_FRAMEWORK_ROOT="$tc25_home/.config/artix-hypr-remix"
  export XDG_STATE_HOME="$tc25_home/.local/state"
  export AHR_LIB_PATH="$tc25_home/.config/artix-hypr-remix/bin/ahr-lib.sh"
  source "$tc25_home/.config/artix-hypr-remix/bin/ahr-lib.sh"
  source "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh"
  source "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh"
  STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"
  MIGRATION_STATE_DIR="$STATE_ROOT/migrations"
  MIGRATION_SKIPPED_DIR="$MIGRATION_STATE_DIR/skipped"
  eval "$(sed -n '/^MIGRATION_DIR=/,/^case.*mode/p' "$UPDATE_FRAMEWORK" | head -n -1)"
  restore_migration_state "$tc25_empty_snapshot"
) 2>/dev/null || tc25_err2=$?

if (( tc25_err2 == 0 )); then
  pass "restore from empty snapshot succeeded"
else
  fail "restore from empty snapshot failed (exit $tc25_err2)"
fi

[[ ! -f "$tc25_home/.local/state/artix-hypr-remix/migrations/new-marker.sh" ]] && pass "newly introduced marker disappeared" || fail "newly introduced marker still present"
[[ ! -f "$tc25_home/.local/state/artix-hypr-remix/migrations/pre-existing.sh" ]] && pass "pre-existing marker removed by empty snapshot" || fail "pre-existing marker not removed"

# Test: empty snapshot produces valid empty marker directories
[[ -d "$tc25_home/.local/state/artix-hypr-remix/migrations" ]] && pass "migrations dir exists after empty snapshot" || fail "migrations dir missing"
[[ -d "$tc25_home/.local/state/artix-hypr-remix/migrations/skipped" ]] && pass "skipped dir exists after empty snapshot" || fail "skipped dir missing"

echo ""
echo "=== TC26: Namespace conflict — unrelated regular file ==="

tc26_home="$tmp_root/tc26"
mkdir -p "$tc26_home/.config/artix-hypr-remix/bin" "$tc26_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc26_home/.config/"
# Plant an unrelated file at a destination
echo "my custom script" > "$tc26_home/.local/bin/ahr-doctor"
tc26_before="$(cat "$tc26_home/.local/bin/ahr-doctor")"
tc26_exit=0
HOME="$tc26_home" AHR_FRAMEWORK_ROOT="$tc26_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc26_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null || tc26_exit=$?
(( tc26_exit != 0 )) && pass "refuses to overwrite unrelated file (exit $tc26_exit)" || fail "overwrite succeeded"
tc26_after="$(cat "$tc26_home/.local/bin/ahr-doctor" 2>/dev/null || echo "MISSING")"
[[ "$tc26_after" == "$tc26_before" ]] && pass "unrelated file preserved byte-for-byte" || fail "unrelated file modified"

echo ""
echo "=== TC27: Namespace conflict — unrelated symlink ==="

tc27_home="$tmp_root/tc27"
mkdir -p "$tc27_home/.config/artix-hypr-remix/bin" "$tc27_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc27_home/.config/"
ln -s "/usr/bin/python3" "$tc27_home/.local/bin/ahr-doctor"
tc27_before="$(readlink "$tc27_home/.local/bin/ahr-doctor")"
tc27_exit=0
HOME="$tc27_home" AHR_FRAMEWORK_ROOT="$tc27_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc27_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null || tc27_exit=$?
(( tc27_exit != 0 )) && pass "refuses to overwrite unrelated symlink (exit $tc27_exit)" || fail "overwrite succeeded"
tc27_after="$(readlink "$tc27_home/.local/bin/ahr-doctor" 2>/dev/null || echo "MISSING")"
[[ "$tc27_after" == "$tc27_before" ]] && pass "unrelated symlink preserved" || fail "unrelated symlink changed"

echo ""
echo "=== TC28: Namespace conflict — directory ==="

tc28_home="$tmp_root/tc28"
mkdir -p "$tc28_home/.config/artix-hypr-remix/bin" "$tc28_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc28_home/.config/"
mkdir "$tc28_home/.local/bin/ahr-doctor"
tc28_exit=0
HOME="$tc28_home" AHR_FRAMEWORK_ROOT="$tc28_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc28_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null || tc28_exit=$?
(( tc28_exit != 0 )) && pass "refuses to overwrite directory (exit $tc28_exit)" || fail "overwrite succeeded"
[[ -d "$tc28_home/.local/bin/ahr-doctor" ]] && pass "directory preserved" || fail "directory removed"

echo ""
echo "=== TC29: Namespace conflict — correct AHR symlink is left unchanged ==="

tc29_home="$tmp_root/tc29"
mkdir -p "$tc29_home/.config/artix-hypr-remix/bin" "$tc29_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc29_home/.config/"
# Install once to create correct links
HOME="$tc29_home" AHR_FRAMEWORK_ROOT="$tc29_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc29_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null
tc29_before="$(readlink "$tc29_home/.local/bin/ahr-doctor")"
# Install again — should not change anything
HOME="$tc29_home" AHR_FRAMEWORK_ROOT="$tc29_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc29_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null
tc29_after="$(readlink "$tc29_home/.local/bin/ahr-doctor")"
[[ "$tc29_before" == "$tc29_after" ]] && pass "correct AHR symlink preserved" || fail "correct symlink changed"

echo ""
echo "=== TC30: Namespace — missing source command ==="

tc30_home="$tmp_root/tc30"
mkdir -p "$tc30_home/.config/artix-hypr-remix/bin" "$tc30_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc30_home/.config/"
# Remove a required command from the source
rm -f "$tc30_home/.config/artix-hypr-remix/bin/ahr-doctor"
tc30_exit=0
HOME="$tc30_home" AHR_FRAMEWORK_ROOT="$tc30_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc30_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null || tc30_exit=$?
(( tc30_exit != 0 )) && pass "fails on missing source command (exit $tc30_exit)" || fail "succeeded with missing source"
# Verify nothing was changed in target
tc30_count="$(find "$tc30_home/.local/bin" -maxdepth 1 -type l 2>/dev/null | wc -l)"
(( tc30_count == 0 )) && pass "no links created before failure" || fail "$tc30_count links created"

echo ""
echo "=== TC31: Namespace transactional rollback on failure ==="

tc31_home="$tmp_root/tc31"
mkdir -p "$tc31_home/.config/artix-hypr-remix/bin" "$tc31_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc31_home/.config/"
# Create a broken symlink in the commands list that will cause ln to fail
# We simulate this by creating a dest that is a read-only directory
chmod 0555 "$tc31_home/.local/bin"
tc31_exit=0
HOME="$tc31_home" AHR_FRAMEWORK_ROOT="$tc31_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc31_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet 2>/dev/null || tc31_exit=$?
chmod 0755 "$tc31_home/.local/bin"
(( tc31_exit != 0 )) && pass "fails when target dir is read-only (exit $tc31_exit)" || fail "succeeded with read-only dir"
# Verify nothing was installed
tc31_count="$(find "$tc31_home/.local/bin" -maxdepth 1 -type l 2>/dev/null | wc -l)"
(( tc31_count == 0 )) && pass "no links created before rollback" || fail "$tc31_count links remain"

echo ""
echo "=== TC32: Backup-ID validation ==="

# Source the validate_backup_id function from ahr-restore-component
(
  export AHR_FRAMEWORK_ROOT="$tmp_root/doesnotexist"
  export XDG_STATE_HOME="$tmp_root/doesnotexist/.local/state"
  export AHR_LIB_PATH="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh"
  source "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh"
  source <(sed -n '/^validate_backup_id()/,/^}$/p' "$RESTORE_COMPONENT")

  # Valid IDs
  validate_backup_id "20260802-120000-abc123" && echo "PASS_VALID1" || echo "FAIL_VALID1"
  validate_backup_id "backup-v1.0" && echo "PASS_VALID2" || echo "FAIL_VALID2"

  # Invalid IDs
  validate_backup_id "../evil" && echo "FAIL_EVIL1" || echo "PASS_EVIL1"
  validate_backup_id "/absolute/path" && echo "FAIL_ABS1" || echo "PASS_ABS1"
  validate_backup_id "nested/path" && echo "FAIL_NEST1" || echo "PASS_NEST1"
  validate_backup_id "." && echo "FAIL_DOT1" || echo "PASS_DOT1"
  validate_backup_id ".." && echo "FAIL_DOTDOT1" || echo "PASS_DOTDOT1"
  validate_backup_id "" && echo "FAIL_EMPTY1" || echo "PASS_EMPTY1"
  validate_backup_id $'tab\there' && echo "FAIL_TAB1" || echo "PASS_TAB1"
  validate_backup_id $'new\nline' && echo "FAIL_NL1" || echo "PASS_NL1"
) 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    PASS_*) pass "$line" ;;
    FAIL_*) fail "$line" ;;
  esac
done

echo ""
echo "=== TC33: Backup-ID symlink escape rejection ==="

tc33_home="$tmp_root/tc33"
mkdir -p "$tc33_home/.local/state/artix-hypr-remix/framework-backups/legit-backup"
mkdir -p "$tmp_root/tc33_outside"
echo "evil" > "$tmp_root/tc33_outside/manifest.txt"
ln -s "$tmp_root/tc33_outside" "$tc33_home/.local/state/artix-hypr-remix/framework-backups/escape-link"
tc33_exit=0
HOME="$tc33_home" AHR_FRAMEWORK_ROOT="$tc33_home/.config/artix-hypr-remix" AHR_LIB_PATH="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" \
  bash "$RESTORE_COMPONENT" framework-config --backup escape-link 2>/dev/null || tc33_exit=$?
(( tc33_exit != 0 )) && pass "rejects symlink-escaping backup ID" || fail "accepted escaped backup"

echo ""
echo "=== TC34: Namespace restore — valid manifest ==="

tc34_home="$tmp_root/tc34"
mkdir -p "$tc34_home/.config/artix-hypr-remix/bin" "$tc34_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc34_home/.config/"
tc34_setup=0
run_namespace_install "$tc34_home" --quiet 2>/dev/null || tc34_setup=$?
(( tc34_setup == 0 )) && pass "namespace restore setup succeeds" || fail "namespace restore setup failed (exit $tc34_setup)"
# Create a stale AHR-owned symlink (points into framework root but to wrong binary)
tc34_fw="$tc34_home/.config/artix-hypr-remix"
ln -sf "$tc34_fw/bin/ahr-update" "$tc34_home/.local/bin/ahr-doctor"
# Create a backup with a manifest
tc34_backup="$tc34_home/.local/state/artix-hypr-remix/framework-backups/test-ns-restore"
mkdir -p "$tc34_backup"
printf "manifest_version=1\ncompleted=true\nprevious_version=0.1.0\nnew_version=0.2.0\n" > "$tc34_backup/manifest.txt"
# Create namespace manifest with correct targets
printf 'ahr-doctor\t%s/bin/ahr-doctor\n' "$tc34_fw" > "$tc34_backup/derived-namespace-links"
tc34_exit=0
run_restore_component "$tc34_home" namespace-links --backup test-ns-restore --apply 2>/dev/null || tc34_exit=$?
(( tc34_exit == 0 )) && pass "namespace restore from manifest succeeds" || fail "namespace restore failed (exit $tc34_exit)"
tc34_target="$(readlink "$tc34_home/.local/bin/ahr-doctor" 2>/dev/null || echo "MISSING")"
[[ "$tc34_target" == "$tc34_fw/bin/ahr-doctor" ]] && pass "link restored to manifest target" || fail "link target wrong: $tc34_target"

echo ""
echo "=== TC35: Namespace restore — dry-run non-destructive ==="

tc35_home="$tmp_root/tc35"
mkdir -p "$tc35_home/.config/artix-hypr-remix/bin" "$tc35_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc35_home/.config/"
tc35_setup=0
run_namespace_install "$tc35_home" --quiet 2>/dev/null || tc35_setup=$?
(( tc35_setup == 0 )) && pass "namespace dry-run setup succeeds" || fail "namespace dry-run setup failed (exit $tc35_setup)"
tc35_before="$(readlink "$tc35_home/.local/bin/ahr-doctor" 2>/dev/null || echo "MISSING")"
# Create a backup with manifest
tc35_backup="$tc35_home/.local/state/artix-hypr-remix/framework-backups/test-ns-dry"
mkdir -p "$tc35_backup"
printf "manifest_version=1\ncompleted=true\nprevious_version=0.1.0\nnew_version=0.2.0\n" > "$tc35_backup/manifest.txt"
tc35_fw="$tc35_home/.config/artix-hypr-remix"
printf 'ahr-doctor\t%s/bin/ahr-doctor\n' "$tc35_fw" > "$tc35_backup/derived-namespace-links"
tc35_exit=0
tc35_output="$(run_restore_component "$tc35_home" namespace-links --backup test-ns-dry 2>&1 || true)"
tc35_after="$(readlink "$tc35_home/.local/bin/ahr-doctor" 2>/dev/null || echo "MISSING")"
[[ "$tc35_before" == "$tc35_after" ]] && pass "dry-run does not modify links" || fail "dry-run modified links"
echo "$tc35_output" | grep -q 'DRY RUN' && pass "dry-run reports DRY RUN" || fail "no DRY RUN output"

echo ""
echo "=== TC36: Namespace restore — conflicts with unrelated file ==="

tc36_home="$tmp_root/tc36"
mkdir -p "$tc36_home/.config/artix-hypr-remix/bin" "$tc36_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc36_home/.config/"
tc36_setup=0
run_namespace_install "$tc36_home" --quiet 2>/dev/null || tc36_setup=$?
(( tc36_setup == 0 )) && pass "namespace conflict setup succeeds" || fail "namespace conflict setup failed (exit $tc36_setup)"
# Remove the symlink and create a regular file at the same path (unrelated)
rm -f "$tc36_home/.local/bin/ahr-doctor"
echo "unrelated" > "$tc36_home/.local/bin/ahr-doctor"
tc36_backup="$tc36_home/.local/state/artix-hypr-remix/framework-backups/test-ns-conflict"
mkdir -p "$tc36_backup"
printf "manifest_version=1\ncompleted=true\nprevious_version=0.1.0\nnew_version=0.2.0\n" > "$tc36_backup/manifest.txt"
tc36_fw="$tc36_home/.config/artix-hypr-remix"
printf 'ahr-doctor\t%s/bin/ahr-doctor\n' "$tc36_fw" > "$tc36_backup/derived-namespace-links"
tc36_exit=0
run_restore_component "$tc36_home" namespace-links --from-last-update --apply 2>/dev/null || tc36_exit=$?
(( tc36_exit != 0 )) && pass "refuses restore with unrelated file conflict" || fail "restore succeeded despite conflict"
tc36_after="$(cat "$tc36_home/.local/bin/ahr-doctor" 2>/dev/null || echo "MISSING")"
[[ "$tc36_after" == "unrelated" ]] && pass "unrelated file preserved" || fail "unrelated file modified"

echo ""
echo "=== TC37: File restore — transactional rollback ==="

tc37_home="$tmp_root/tc37"
mkdir -p "$tc37_home/.config/artix-hypr-remix" "$tc37_home/.local/state/artix-hypr-remix/framework-backups/test-f-restore"
echo "original config" > "$tc37_home/.config/artix-hypr-remix/framework.json"
echo "backup config" > "$tc37_home/.local/state/artix-hypr-remix/framework-backups/test-f-restore/derived-framework-config"
cat > "$tc37_home/.local/state/artix-hypr-remix/framework-backups/test-f-restore/manifest.txt" <<'MFEOF'
manifest_version=1
completed=true
previous_version=0.1.0
new_version=0.2.0
MFEOF
tc37_before="$(cat "$tc37_home/.config/artix-hypr-remix/framework.json")"
# Make the target directory read-only so mv fails
chmod 0555 "$tc37_home/.config/artix-hypr-remix"
tc37_exit=0
run_restore_component "$tc37_home" framework-config --from-last-update --apply 2>/dev/null || tc37_exit=$?
chmod 0755 "$tc37_home/.config/artix-hypr-remix"
(( tc37_exit != 0 )) && pass "file restore fails when target is read-only (exit $tc37_exit)" || fail "restore succeeded"
tc37_after="$(cat "$tc37_home/.config/artix-hypr-remix/framework.json" 2>/dev/null || echo "MISSING")"
[[ "$tc37_after" == "$tc37_before" ]] && pass "original file preserved after failure" || fail "file changed: $tc37_after"

echo ""
echo "=== TC38: Directory restore — transactional rollback ==="

tc38_home="$tmp_root/tc38"
mkdir -p "$tc38_home/.config/artix-hypr-remix/current/theme" "$tc38_home/.local/state/artix-hypr-remix/framework-backups/test-d-restore"
echo "original" > "$tc38_home/.config/artix-hypr-remix/current/theme/marker"
mkdir -p "$tc38_home/.local/state/artix-hypr-remix/framework-backups/test-d-restore/derived-theme-state"
cp -a "$tc38_home/.config/artix-hypr-remix/current" "$tc38_home/.local/state/artix-hypr-remix/framework-backups/test-d-restore/derived-theme-state/"
cat > "$tc38_home/.local/state/artix-hypr-remix/framework-backups/test-d-restore/manifest.txt" <<'MFEOF'
manifest_version=1
completed=true
previous_version=0.1.0
new_version=0.2.0
MFEOF
tc38_before="$(cat "$tc38_home/.config/artix-hypr-remix/current/theme/marker")"
# Make parent read-only so rm -rf fails
chmod 0555 "$tc38_home/.config/artix-hypr-remix"
tc38_exit=0
run_restore_component "$tc38_home" theme-state --from-last-update --apply 2>/dev/null || tc38_exit=$?
chmod 0755 "$tc38_home/.config/artix-hypr-remix"
(( tc38_exit != 0 )) && pass "directory restore fails when parent is read-only (exit $tc38_exit)" || fail "restore succeeded"
tc38_after="$(cat "$tc38_home/.config/artix-hypr-remix/current/theme/marker" 2>/dev/null || echo "MISSING")"
[[ "$tc38_after" == "$tc38_before" ]] && pass "original directory preserved after failure" || fail "directory changed"

echo ""
echo "=== TC39: Backup-ID — missing backup ==="

tc39_exit=0
run_restore_component "$tmp_root" framework-config --backup nonexistent-2026 2>/dev/null || tc39_exit=$?
(( tc39_exit != 0 )) && pass "missing backup rejected (exit $tc39_exit)" || fail "accepted missing backup"

echo ""
echo "=== TC40: Backup-ID — incomplete backup ==="

tc40_home="$tmp_root/tc40"
mkdir -p "$tc40_home/.local/state/artix-hypr-remix/framework-backups/incomplete-bk"
cat > "$tc40_home/.local/state/artix-hypr-remix/framework-backups/incomplete-bk/manifest.txt" <<'MFEOF'
manifest_version=1
completed=false
MFEOF
tc40_exit=0
run_restore_component "$tc40_home" framework-config --backup incomplete-bk 2>/dev/null || tc40_exit=$?
(( tc40_exit != 0 )) && pass "incomplete backup rejected (exit $tc40_exit)" || fail "accepted incomplete backup"

echo ""
echo "=== TC41: Dispatcher — exit code propagation ==="

tc41_home="$tmp_root/tc41"
mkdir -p "$tc41_home/.config/artix-hypr-remix/bin" "$tc41_home/.local/state"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc41_home/.config/"
tc41_exit=0
HOME="$tc41_home" XDG_CONFIG_HOME="$tc41_home/.config" XDG_STATE_HOME="$tc41_home/.local/state" XDG_CACHE_HOME="$tc41_home/.cache" XDG_DATA_HOME="$tc41_home/.local/share" AHR_FRAMEWORK_ROOT="$tc41_home/.config/artix-hypr-remix" AHR_LIB_PATH="$tc41_home/.config/artix-hypr-remix/bin/ahr-lib.sh" \
  "$tc41_home/.config/artix-hypr-remix/bin/ahr" restore-component --list > /dev/null 2>&1 || tc41_exit=$?
(( tc41_exit == 0 )) && pass "dispatcher --list exit 0" || fail "dispatcher --list exit $tc41_exit"

tc41_exit2=0
HOME="$tc41_home" XDG_CONFIG_HOME="$tc41_home/.config" XDG_STATE_HOME="$tc41_home/.local/state" XDG_CACHE_HOME="$tc41_home/.cache" XDG_DATA_HOME="$tc41_home/.local/share" AHR_FRAMEWORK_ROOT="$tc41_home/.config/artix-hypr-remix" AHR_LIB_PATH="$tc41_home/.config/artix-hypr-remix/bin/ahr-lib.sh" \
  "$tc41_home/.config/artix-hypr-remix/bin/ahr" restore-component nonexistent 2>/dev/null || tc41_exit2=$?
(( tc41_exit2 != 0 )) && pass "dispatcher unknown component nonzero (exit $tc41_exit2)" || fail "dispatcher succeeded"

echo ""
echo "=== TC42: Namespace snapshot format validation ==="

tc42_home="$tmp_root/tc42"
mkdir -p "$tc42_home/.config/artix-hypr-remix/bin" "$tc42_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc42_home/.config/"
tc42_setup=0
run_namespace_install "$tc42_home" --quiet 2>/dev/null || tc42_setup=$?
(( tc42_setup == 0 )) && pass "namespace snapshot setup succeeds" || fail "namespace snapshot setup failed (exit $tc42_setup)"
# Check that snapshot was created
tc42_snap="$tc42_home/.local/state/artix-hypr-remix/namespace-snapshots/current/namespace-manifest.txt"
[[ -f "$tc42_snap" ]] && pass "namespace snapshot created" || fail "snapshot missing"
if [[ -f "$tc42_snap" ]]; then
  grep -q '^format_version=1$' "$tc42_snap" && pass "snapshot has format_version=1" || fail "snapshot missing format_version"
  grep -q '^created_at=' "$tc42_snap" && pass "snapshot has created_at" || fail "snapshot missing created_at"
  grep -q '^framework_root=' "$tc42_snap" && pass "snapshot has framework_root" || fail "snapshot missing framework_root"
  grep -q '^local_bin=' "$tc42_snap" && pass "snapshot has local_bin" || fail "snapshot missing local_bin"
  grep -q '^link_name=ahr$' "$tc42_snap" && pass "snapshot has link_name=ahr" || fail "snapshot missing ahr link"
  grep -q '^link_target=' "$tc42_snap" && pass "snapshot has link_target" || fail "snapshot missing link_target"
fi

echo ""
echo "=== TC43: Namespace restore — malformed manifest ==="

tc43_home="$tmp_root/tc43"
mkdir -p "$tc43_home/.config/artix-hypr-remix/bin" "$tc43_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc43_home/.config/"
tc43_backup="$tc43_home/.local/state/artix-hypr-remix/framework-backups/test-bad-manifest"
mkdir -p "$tc43_backup"
cat > "$tc43_backup/manifest.txt" <<'MFEOF'
manifest_version=1
completed=true
previous_version=0.1.0
new_version=0.2.0
MFEOF
echo "not a valid manifest" > "$tc43_backup/derived-namespace-links"
tc43_exit=0
run_restore_component "$tc43_home" namespace-links --from-last-update --apply 2>/dev/null || tc43_exit=$?
(( tc43_exit != 0 )) && pass "rejects malformed manifest (exit $tc43_exit)" || fail "accepted malformed manifest"

echo ""
echo "=== TC44: Component shape validation ==="

tc44_home="$tmp_root/tc44"
mkdir -p "$tc44_home/.local/state/artix-hypr-remix/framework-backups/test-shape"
echo "manifest_version=1" > "$tc44_home/.local/state/artix-hypr-remix/framework-backups/test-shape/manifest.txt"
echo "completed=true" >> "$tc44_home/.local/state/artix-hypr-remix/framework-backups/test-shape/manifest.txt"
# Create a directory where a file is expected
mkdir -p "$tc44_home/.local/state/artix-hypr-remix/framework-backups/test-shape/derived-framework-config"
tc44_exit=0
run_restore_component "$tc44_home" framework-config --backup test-shape --apply 2>/dev/null || tc44_exit=$?
(( tc44_exit != 0 )) && pass "rejects directory as file component (exit $tc44_exit)" || fail "accepted directory as file"

echo ""
echo "=== TC45: Restore-component — list shows rollback-only ==="

tc45_list="$(run_restore_component "$tmp_root" --list 2>&1)"
echo "$tc45_list" | grep -q 'migration-state.*rollback-only' && pass "migration-state labeled rollback-only" || fail "rollback-only label missing"

echo ""
echo "=== TC46: Namespace restore — link removed after snapshot ==="

tc46_home="$tmp_root/tc46"
mkdir -p "$tc46_home/.config/artix-hypr-remix/bin" "$tc46_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc46_home/.config/"
tc46_setup=0
run_namespace_install "$tc46_home" --quiet 2>/dev/null || tc46_setup=$?
(( tc46_setup == 0 )) && pass "namespace removed-link setup succeeds" || fail "namespace removed-link setup failed (exit $tc46_setup)"
# Create a backup with namespace manifest
tc46_backup="$tc46_home/.local/state/artix-hypr-remix/framework-backups/test-ns-removed"
mkdir -p "$tc46_backup"
printf "manifest_version=1\ncompleted=true\nprevious_version=0.1.0\nnew_version=0.2.0\n" > "$tc46_backup/manifest.txt"
tc46_fw="$tc46_home/.config/artix-hypr-remix"
printf 'ahr-doctor\t%s/bin/ahr-doctor\n' "$tc46_fw" > "$tc46_backup/derived-namespace-links"
# Remove a link
rm -f "$tc46_home/.local/bin/ahr-doctor"
tc46_exit=0
run_restore_component "$tc46_home" namespace-links --backup test-ns-removed --apply 2>/dev/null || tc46_exit=$?
(( tc46_exit == 0 )) && pass "restores removed link" || fail "restore failed (exit $tc46_exit)"
[[ -L "$tc46_home/.local/bin/ahr-doctor" ]] && pass "link recreated after restore" || fail "link not recreated"

echo ""
echo "=== TC47: Namespace restore — link added after snapshot ==="

tc47_home="$tmp_root/tc47"
mkdir -p "$tc47_home/.config/artix-hypr-remix/bin" "$tc47_home/.local/bin"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc47_home/.config/"
tc47_setup=0
run_namespace_install "$tc47_home" --quiet 2>/dev/null || tc47_setup=$?
(( tc47_setup == 0 )) && pass "namespace extra-link setup succeeds" || fail "namespace extra-link setup failed (exit $tc47_setup)"
# Create a backup with namespace manifest
tc47_backup="$tc47_home/.local/state/artix-hypr-remix/framework-backups/test-ns-added"
mkdir -p "$tc47_backup"
printf "manifest_version=1\ncompleted=true\nprevious_version=0.1.0\nnew_version=0.2.0\n" > "$tc47_backup/manifest.txt"
tc47_fw="$tc47_home/.config/artix-hypr-remix"
printf 'ahr-doctor\t%s/bin/ahr-doctor\n' "$tc47_fw" > "$tc47_backup/derived-namespace-links"
# Add a link that wasn't in the snapshot
ln -s "/usr/bin/true" "$tc47_home/.local/bin/custom-tool"
tc47_exit=0
run_restore_component "$tc47_home" namespace-links --backup test-ns-added --apply 2>/dev/null || tc47_exit=$?
(( tc47_exit == 0 )) && pass "restore succeeds with extra link present" || fail "restore failed (exit $tc47_exit)"
tc47_custom="$(readlink "$tc47_home/.local/bin/custom-tool" 2>/dev/null || echo "MISSING")"
[[ "$tc47_custom" == "/usr/bin/true" ]] && pass "unrelated extra link preserved" || fail "extra link modified"

echo ""
echo "=== TC48: Staged dependency command/library modes ==="

tc48_current_home="$tmp_root/tc48_current"
tc48_current_repo="$(create_current_tree_repo "$tmp_root/tc48_current_repo" "0.2.0")"
setup_installed_framework "$tc48_current_home" "file://$tc48_current_repo"
tc48_current_exit=0
run_ahr "$tc48_current_home" "$UPDATE_FRAMEWORK" --dry-run >/dev/null 2>&1 || tc48_current_exit=$?
(( tc48_current_exit == 0 )) && pass "current staged tree passes with repository modes" || fail "current staged tree rejected (exit $tc48_current_exit)"

tc48_success_home="$tmp_root/tc48_success"
tc48_success_repo="$(create_test_repo "$tmp_root/tc48_success_repo" "0.2.0")"
setup_installed_framework "$tc48_success_home" "file://$tc48_success_repo"
tc48_success_dry=0
run_ahr "$tc48_success_home" "$UPDATE_FRAMEWORK" --dry-run >/dev/null 2>&1 || tc48_success_dry=$?
(( tc48_success_dry == 0 )) && pass "readable non-executable library succeeds in dry-run" || fail "readable non-executable library rejected in dry-run (exit $tc48_success_dry)"
tc48_success_apply=0
run_ahr "$tc48_success_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc48_success_apply=$?
(( tc48_success_apply == 0 )) && pass "executable command succeeds in apply" || fail "apply rejected executable commands (exit $tc48_success_apply)"

tc48_missing_lib_home="$tmp_root/tc48_missing_lib"
tc48_missing_lib_repo="$(create_test_repo "$tmp_root/tc48_missing_lib_repo" "0.2.0")"
rm -f "$tc48_missing_lib_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-cache.sh"
commit_test_repo "$tc48_missing_lib_repo" "remove library"
setup_installed_framework "$tc48_missing_lib_home" "file://$tc48_missing_lib_repo"
tc48_missing_lib_dry=0
run_ahr "$tc48_missing_lib_home" "$UPDATE_FRAMEWORK" --dry-run >/dev/null 2>&1 || tc48_missing_lib_dry=$?
(( tc48_missing_lib_dry != 0 )) && pass "missing library fails dry-run" || fail "missing library accepted by dry-run"
tc48_missing_lib_apply=0
run_ahr "$tc48_missing_lib_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc48_missing_lib_apply=$?
(( tc48_missing_lib_apply != 0 )) && pass "missing library fails apply" || fail "missing library accepted by apply"
[[ ! -d "$tc48_missing_lib_home/.local/state/artix-hypr-remix/framework-backups" ]] && pass "missing library failure created no backups" || fail "backup created after missing library validation failure"
tc48_missing_lib_version="$(json_get "$tc48_missing_lib_home/.config/artix-hypr-remix/framework.json" version)"
[[ "$tc48_missing_lib_version" == "0.1.0" ]] && pass "missing library failure did not mutate installed framework" || fail "installed framework mutated to $tc48_missing_lib_version"

tc48_missing_cmd_home="$tmp_root/tc48_missing_cmd"
tc48_missing_cmd_repo="$(create_test_repo "$tmp_root/tc48_missing_cmd_repo" "0.2.0")"
rm -f "$tc48_missing_cmd_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-update"
commit_test_repo "$tc48_missing_cmd_repo" "remove command"
setup_installed_framework "$tc48_missing_cmd_home" "file://$tc48_missing_cmd_repo"
tc48_missing_cmd_dry=0
run_ahr "$tc48_missing_cmd_home" "$UPDATE_FRAMEWORK" --dry-run >/dev/null 2>&1 || tc48_missing_cmd_dry=$?
(( tc48_missing_cmd_dry != 0 )) && pass "missing executable command fails dry-run" || fail "missing executable command accepted by dry-run"
tc48_missing_cmd_apply=0
run_ahr "$tc48_missing_cmd_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc48_missing_cmd_apply=$?
(( tc48_missing_cmd_apply != 0 )) && pass "missing executable command fails apply" || fail "missing executable command accepted by apply"
[[ ! -d "$tc48_missing_cmd_home/.local/state/artix-hypr-remix/framework-backups" ]] && pass "missing command failure created no backups" || fail "backup created after missing command validation failure"
tc48_missing_cmd_version="$(json_get "$tc48_missing_cmd_home/.config/artix-hypr-remix/framework.json" version)"
[[ "$tc48_missing_cmd_version" == "0.1.0" ]] && pass "missing command failure did not mutate installed framework" || fail "installed framework mutated to $tc48_missing_cmd_version"

tc48_nonexec_home="$tmp_root/tc48_nonexec"
tc48_nonexec_repo="$(create_test_repo "$tmp_root/tc48_nonexec_repo" "0.2.0")"
chmod 0644 "$tc48_nonexec_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-update"
commit_test_repo "$tc48_nonexec_repo" "make command non-executable"
setup_installed_framework "$tc48_nonexec_home" "file://$tc48_nonexec_repo"
tc48_nonexec_dry=0
run_ahr "$tc48_nonexec_home" "$UPDATE_FRAMEWORK" --dry-run >/dev/null 2>&1 || tc48_nonexec_dry=$?
(( tc48_nonexec_dry != 0 )) && pass "non-executable command fails dry-run" || fail "non-executable command accepted by dry-run"
tc48_nonexec_apply=0
run_ahr "$tc48_nonexec_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc48_nonexec_apply=$?
(( tc48_nonexec_apply != 0 )) && pass "non-executable command fails apply" || fail "non-executable command accepted by apply"
[[ ! -d "$tc48_nonexec_home/.local/state/artix-hypr-remix/framework-backups" ]] && pass "non-executable command failure created no backups" || fail "backup created after non-executable command validation failure"

tc48_unreadable_home="$tmp_root/tc48_unreadable"
tc48_unreadable_staged="$tmp_root/tc48_unreadable_staged"
mkdir -p "$tc48_unreadable_staged"
cp -a "$tc48_success_repo/artix-hypr-remix/config/artix-hypr-remix/." "$tc48_unreadable_staged/"
chmod 000 "$tc48_unreadable_staged/bin/ahr-cache.sh"
tc48_unreadable_exit=0
run_direct_staged_validation "$tc48_unreadable_home" "$tc48_unreadable_staged" "0.2.0" "testcommit" "stable" >/dev/null 2>&1 || tc48_unreadable_exit=$?
chmod 0644 "$tc48_unreadable_staged/bin/ahr-cache.sh" 2>/dev/null || true
(( tc48_unreadable_exit != 0 )) && pass "unreadable library fails direct staged validation" || fail "unreadable library accepted"

echo ""
echo "=== TC49: Backup failure is fatal for real writers ==="

tc49_hook="$REPO_ROOT/config/artix-hypr-remix/hooks/theme-set.d/30-vscode-theme.sh"

tc49_code_home="$tmp_root/tc49_code"
tc49_code_fakebin="$tc49_code_home/fakebin"
mkdir -p "$tc49_code_fakebin" "$tc49_code_home/.config/Code/User"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tc49_code_fakebin/code"
chmod +x "$tc49_code_fakebin/code"
printf '{"keep":"yes","workbench.colorTheme":"Old"}\n' > "$tc49_code_home/.config/Code/User/settings.json"
cp "$tc49_code_home/.config/Code/User/settings.json" "$tc49_code_home/original-settings.json"
printf 'blocked\n' > "$tc49_code_home/state-file"
tc49_code_exit=0
HOME="$tc49_code_home" XDG_STATE_HOME="$tc49_code_home/state-file" XDG_CONFIG_HOME="$tc49_code_home/.config" \
  PATH="$tc49_code_fakebin:$PATH" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
  AHR_THEME_LIB_PATH="$FRAMEWORK_BIN/ahr-theme-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$tc49_hook" >/dev/null 2>&1 || tc49_code_exit=$?
(( tc49_code_exit != 0 )) && pass "VS Code writer returns nonzero on backup failure" || fail "VS Code writer succeeded after backup failure"
cmp -s "$tc49_code_home/.config/Code/User/settings.json" "$tc49_code_home/original-settings.json" && pass "VS Code settings unchanged after backup failure" || fail "VS Code settings mutated after backup failure"
[[ ! -e "$tc49_code_home/.config/Code/User/settings.json.tmp" ]] && pass "VS Code replacement temp not installed" || fail "VS Code replacement temp left behind"

tc49_cursor_home="$tmp_root/tc49_cursor"
tc49_cursor_fakebin="$tc49_cursor_home/fakebin"
mkdir -p "$tc49_cursor_fakebin" "$tc49_cursor_home/.config/Cursor/User"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tc49_cursor_fakebin/cursor"
chmod +x "$tc49_cursor_fakebin/cursor"
printf '{"keep":"cursor","workbench.colorTheme":"Old"}\n' > "$tc49_cursor_home/.config/Cursor/User/settings.json"
cp "$tc49_cursor_home/.config/Cursor/User/settings.json" "$tc49_cursor_home/original-settings.json"
printf 'blocked\n' > "$tc49_cursor_home/state-file"
tc49_cursor_exit=0
HOME="$tc49_cursor_home" XDG_STATE_HOME="$tc49_cursor_home/state-file" XDG_CONFIG_HOME="$tc49_cursor_home/.config" \
  PATH="$tc49_cursor_fakebin:$PATH" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
  AHR_THEME_LIB_PATH="$FRAMEWORK_BIN/ahr-theme-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$tc49_hook" >/dev/null 2>&1 || tc49_cursor_exit=$?
(( tc49_cursor_exit != 0 )) && pass "Cursor writer returns nonzero on backup failure" || fail "Cursor writer succeeded after backup failure"
cmp -s "$tc49_cursor_home/.config/Cursor/User/settings.json" "$tc49_cursor_home/original-settings.json" && pass "Cursor settings unchanged after backup failure" || fail "Cursor settings mutated after backup failure"
[[ ! -e "$tc49_cursor_home/.config/Cursor/User/settings.json.tmp" ]] && pass "Cursor replacement temp not installed" || fail "Cursor replacement temp left behind"

tc49_font_home="$tmp_root/tc49_font"
mkdir -p "$tc49_font_home/.config/fontconfig"
printf '<fontconfig>original</fontconfig>\n' > "$tc49_font_home/.config/fontconfig/fonts.conf"
cp "$tc49_font_home/.config/fontconfig/fonts.conf" "$tc49_font_home/original-fonts.conf"
printf 'blocked\n' > "$tc49_font_home/state-file"
tc49_font_exit=0
HOME="$tc49_font_home" XDG_STATE_HOME="$tc49_font_home/state-file" XDG_CONFIG_HOME="$tc49_font_home/.config" \
  AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" AHR_THEME_LIB_PATH="$FRAMEWORK_BIN/ahr-theme-lib.sh" \
  AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash -c 'source "$AHR_THEME_LIB_PATH"; ahr_theme_deploy_fontconfig' >/dev/null 2>&1 || tc49_font_exit=$?
(( tc49_font_exit != 0 )) && pass "Fontconfig writer returns nonzero on backup failure" || fail "Fontconfig writer succeeded after backup failure"
cmp -s "$tc49_font_home/.config/fontconfig/fonts.conf" "$tc49_font_home/original-fonts.conf" && pass "Fontconfig unchanged after backup failure" || fail "Fontconfig mutated after backup failure"

tc49_opencode_home="$tmp_root/tc49_opencode"
tc49_opencode_fakebin="$tc49_opencode_home/fakebin"
mkdir -p "$tc49_opencode_fakebin" "$tc49_opencode_home/.config/opencode"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tc49_opencode_fakebin/opencode"
chmod +x "$tc49_opencode_fakebin/opencode"
printf '{"keep":"opencode","theme":"Old"}\n' > "$tc49_opencode_home/.config/opencode/opencode.jsonc"
cp "$tc49_opencode_home/.config/opencode/opencode.jsonc" "$tc49_opencode_home/original-opencode.jsonc"
printf 'blocked\n' > "$tc49_opencode_home/state-file"
tc49_opencode_exit=0
HOME="$tc49_opencode_home" XDG_STATE_HOME="$tc49_opencode_home/state-file" XDG_CONFIG_HOME="$tc49_opencode_home/.config" \
  PATH="$tc49_opencode_fakebin:$PATH" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
  AHR_THEME_LIB_PATH="$FRAMEWORK_BIN/ahr-theme-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$tc49_hook" >/dev/null 2>&1 || tc49_opencode_exit=$?
(( tc49_opencode_exit != 0 )) && pass "OpenCode writer returns nonzero on backup failure" || fail "OpenCode writer succeeded after backup failure"
cmp -s "$tc49_opencode_home/.config/opencode/opencode.jsonc" "$tc49_opencode_home/original-opencode.jsonc" && pass "OpenCode settings unchanged after backup failure" || fail "OpenCode settings mutated after backup failure"
[[ ! -e "$tc49_opencode_home/.config/opencode/opencode.jsonc.tmp" ]] && pass "OpenCode replacement temp not installed" || fail "OpenCode replacement temp left behind"

tc49_foot_home="$tmp_root/tc49_foot"
tc49_foot_fakebin="$tc49_foot_home/fakebin"
mkdir -p "$tc49_foot_fakebin" "$tc49_foot_home/.config/foot"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tc49_foot_fakebin/foot"
chmod +x "$tc49_foot_fakebin/foot"
printf '[main]\nkeep=yes\n' > "$tc49_foot_home/.config/foot/foot.ini"
cp "$tc49_foot_home/.config/foot/foot.ini" "$tc49_foot_home/original-foot.ini"
printf 'blocked\n' > "$tc49_foot_home/state-file"
tc49_foot_exit=0
HOME="$tc49_foot_home" XDG_STATE_HOME="$tc49_foot_home/state-file" XDG_CONFIG_HOME="$tc49_foot_home/.config" \
  PATH="$tc49_foot_fakebin:$PATH" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
  AHR_THEME_LIB_PATH="$FRAMEWORK_BIN/ahr-theme-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$REPO_ROOT/config/artix-hypr-remix/hooks/theme-set.d/10-foot-theme.sh" >/dev/null 2>&1 || tc49_foot_exit=$?
(( tc49_foot_exit != 0 )) && pass "Foot writer returns nonzero on backup failure" || fail "Foot writer succeeded after backup failure"
cmp -s "$tc49_foot_home/.config/foot/foot.ini" "$tc49_foot_home/original-foot.ini" && pass "Foot config unchanged after backup failure" || fail "Foot config mutated after backup failure"

tc49_chromium_home="$tmp_root/tc49_chromium"
tc49_chromium_fakebin="$tc49_chromium_home/fakebin"
mkdir -p "$tc49_chromium_fakebin" "$tc49_chromium_home/.config/chromium/Default"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tc49_chromium_fakebin/chromium"
chmod +x "$tc49_chromium_fakebin/chromium"
printf '{"keep":"chromium","browser":{"theme":{"color_scheme":2}}}\n' > "$tc49_chromium_home/.config/chromium/Default/Preferences"
cp "$tc49_chromium_home/.config/chromium/Default/Preferences" "$tc49_chromium_home/original-Preferences"
printf 'blocked\n' > "$tc49_chromium_home/state-file"
tc49_chromium_exit=0
HOME="$tc49_chromium_home" XDG_STATE_HOME="$tc49_chromium_home/state-file" XDG_CONFIG_HOME="$tc49_chromium_home/.config" \
  PATH="$tc49_chromium_fakebin:$PATH" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" \
  AHR_THEME_LIB_PATH="$FRAMEWORK_BIN/ahr-theme-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$REPO_ROOT/config/artix-hypr-remix/hooks/theme-set.d/20-chromium-theme.sh" >/dev/null 2>&1 || tc49_chromium_exit=$?
(( tc49_chromium_exit != 0 )) && pass "Chromium writer returns nonzero on backup failure" || fail "Chromium writer succeeded after backup failure"
cmp -s "$tc49_chromium_home/.config/chromium/Default/Preferences" "$tc49_chromium_home/original-Preferences" && pass "Chromium preferences unchanged after backup failure" || fail "Chromium preferences mutated after backup failure"
[[ ! -e "$tc49_chromium_home/.config/chromium/Default/Preferences.tmp" ]] && pass "Chromium replacement temp not installed" || fail "Chromium replacement temp left behind"

tc49_editor_home="$tmp_root/tc49_editor"
tc49_editor_fakebin="$tc49_editor_home/fakebin"
mkdir -p "$tc49_editor_fakebin" "$tc49_editor_home/.config/artix-hypr-remix"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tc49_editor_fakebin/hx"
chmod +x "$tc49_editor_fakebin/hx"
printf 'export EDITOR=old\nexport KEEP=yes\n' > "$tc49_editor_home/.config/artix-hypr-remix/env"
cp "$tc49_editor_home/.config/artix-hypr-remix/env" "$tc49_editor_home/original-env"
printf 'blocked\n' > "$tc49_editor_home/state-file"
tc49_editor_exit=0
HOME="$tc49_editor_home" XDG_STATE_HOME="$tc49_editor_home/state-file" XDG_CONFIG_HOME="$tc49_editor_home/.config" \
  PATH="$tc49_editor_fakebin:$PATH" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$FRAMEWORK_BIN/ahr-default-editor" helix >/dev/null 2>&1 || tc49_editor_exit=$?
(( tc49_editor_exit != 0 )) && pass "editor preference writer returns nonzero on backup failure" || fail "editor preference writer succeeded after backup failure"
cmp -s "$tc49_editor_home/.config/artix-hypr-remix/env" "$tc49_editor_home/original-env" && pass "editor preference unchanged after backup failure" || fail "editor preference mutated after backup failure"

tc49_terminal_home="$tmp_root/tc49_terminal"
mkdir -p "$tc49_terminal_home/.config"
printf 'Old.desktop\n# keep\n' > "$tc49_terminal_home/.config/xdg-terminals.list"
cp "$tc49_terminal_home/.config/xdg-terminals.list" "$tc49_terminal_home/original-terminals.list"
printf 'blocked\n' > "$tc49_terminal_home/state-file"
tc49_terminal_exit=0
HOME="$tc49_terminal_home" XDG_STATE_HOME="$tc49_terminal_home/state-file" XDG_CONFIG_HOME="$tc49_terminal_home/.config" \
  AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" AHR_BACKUP_HELPER_PATH="$FRAMEWORK_BIN/ahr-backup-helper.sh" \
  bash "$FRAMEWORK_BIN/ahr-default-terminal" foot >/dev/null 2>&1 || tc49_terminal_exit=$?
(( tc49_terminal_exit != 0 )) && pass "terminal preference writer returns nonzero on backup failure" || fail "terminal preference writer succeeded after backup failure"
cmp -s "$tc49_terminal_home/.config/xdg-terminals.list" "$tc49_terminal_home/original-terminals.list" && pass "terminal preference unchanged after backup failure" || fail "terminal preference mutated after backup failure"

echo ""
echo "=== TC50: Backup helper collision-proof names ==="

tc50_home="$tmp_root/tc50"
tc50_fakebin="$tc50_home/fakebin"
tc50_backup_root="$tc50_home/backups"
mkdir -p "$tc50_fakebin" "$tc50_home/srcdir"
printf '#!/usr/bin/env bash\nprintf "20260802-120000\\n"\n' > "$tc50_fakebin/date"
chmod +x "$tc50_fakebin/date"

tc50_file="$tc50_home/source.txt"
tc50_paths=()
PATH="$tc50_fakebin:$PATH" HOME="$tc50_home" XDG_STATE_HOME="$tc50_home/.local/state" \
  bash -s -- "$FRAMEWORK_BIN/ahr-backup-helper.sh" "$tc50_file" "$tc50_backup_root" "$tc50_home/file-paths" <<'EOF'
set -euo pipefail
source "$1"
file="$2"
backup_root="$3"
paths_file="$4"
: > "$paths_file"
for content in first second third; do
  printf '%s\n' "$content" > "$file"
  ahr_backup_before_edit "$file" "$backup_root"
  printf '%s\n' "$AHR_BACKUP_PATH" >> "$paths_file"
done
EOF
mapfile -t tc50_paths < "$tc50_home/file-paths"
tc50_unique="$(printf '%s\n' "${tc50_paths[@]}" | sort -u | wc -l)"
(( ${#tc50_paths[@]} == 3 && tc50_unique == 3 )) && pass "file backups use three distinct paths for one timestamp" || fail "file backup paths not unique"
[[ "$(cat "${tc50_paths[0]}")" == "first" ]] && pass "first file backup preserved first original" || fail "first file backup overwritten"
[[ "$(cat "${tc50_paths[1]}")" == "second" && "$(cat "${tc50_paths[2]}")" == "third" ]] && pass "later file backups preserve pre-edit states" || fail "later file backups contain wrong data"

tc50_dir="$tc50_home/source-dir"
mkdir -p "$tc50_dir"
PATH="$tc50_fakebin:$PATH" HOME="$tc50_home" XDG_STATE_HOME="$tc50_home/.local/state" \
  bash -s -- "$FRAMEWORK_BIN/ahr-backup-helper.sh" "$tc50_dir" "$tc50_backup_root" "$tc50_home/dir-paths" <<'EOF'
set -euo pipefail
source "$1"
dir="$2"
backup_root="$3"
paths_file="$4"
: > "$paths_file"
for content in alpha beta gamma; do
  printf '%s\n' "$content" > "$dir/value.txt"
  ahr_backup_dir_before_edit "$dir" "$backup_root"
  printf '%s\n' "$AHR_BACKUP_DIR" >> "$paths_file"
done
EOF
mapfile -t tc50_dir_paths < "$tc50_home/dir-paths"
tc50_dir_unique="$(printf '%s\n' "${tc50_dir_paths[@]}" | sort -u | wc -l)"
(( ${#tc50_dir_paths[@]} == 3 && tc50_dir_unique == 3 )) && pass "directory backups use three distinct paths for one timestamp" || fail "directory backup paths not unique"
[[ "$(cat "${tc50_dir_paths[0]}/value.txt")" == "alpha" ]] && pass "first directory backup preserved first original" || fail "first directory backup overwritten"
[[ "$(cat "${tc50_dir_paths[1]}/value.txt")" == "beta" && "$(cat "${tc50_dir_paths[2]}/value.txt")" == "gamma" ]] && pass "later directory backups preserve pre-edit states" || fail "later directory backups contain wrong data"

echo ""
echo "=== TC51: Component manifest records absence and required failures ==="

manifest_component_count() {
  local manifest="$1" component="$2"
  grep -cx "component=$component" "$manifest" 2>/dev/null || true
}

manifest_component_field() {
  local manifest="$1" component="$2" field="$3"
  awk -v comp="$component" -v field="$field" '
    $0 == "component=" comp { inrec=1; next }
    inrec && $0 == "---" { inrec=0; next }
    inrec && index($0, field "=") == 1 { print substr($0, length(field) + 2); exit }
  ' "$manifest"
}

tc51_optional_home="$tmp_root/tc51_optional"
tc51_optional_repo="$(create_test_repo "$tmp_root/tc51_optional_repo" "0.2.0")"
setup_installed_framework "$tc51_optional_home" "file://$tc51_optional_repo"
mkdir -p "$tc51_optional_home/.config/chromium/Default"
printf '{"keep":"chromium"}\n' > "$tc51_optional_home/.config/chromium/Default/Preferences"
tc51_optional_exit=0
run_ahr "$tc51_optional_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc51_optional_exit=$?
(( tc51_optional_exit == 0 )) && pass "component-manifest fixture apply succeeds" || fail "component-manifest fixture apply failed (exit $tc51_optional_exit)"
tc51_backup="$(find "$tc51_optional_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1)"
tc51_manifest="$tc51_backup/component-manifest.txt"
[[ -f "$tc51_manifest" ]] && pass "component-manifest exists" || fail "component-manifest missing"
for tc51_component in waybar-theme mako-theme terminal-theme fontconfig; do
  [[ "$(manifest_component_count "$tc51_manifest" "$tc51_component")" == "1" ]] && pass "$tc51_component has one manifest record" || fail "$tc51_component record count wrong"
  [[ "$(manifest_component_field "$tc51_manifest" "$tc51_component" snapshot_status)" == "absent" ]] && pass "$tc51_component records absent status" || fail "$tc51_component status not absent"
  [[ -z "$(manifest_component_field "$tc51_manifest" "$tc51_component" snapshot_path)" ]] && pass "$tc51_component absent record has no snapshot path" || fail "$tc51_component absent record claimed snapshot"
done
[[ "$(manifest_component_field "$tc51_manifest" chromium-theme snapshot_status)" == "unsupported" ]] && pass "unsupported structured component recorded" || fail "unsupported structured component not recorded"
tc51_record_count="$(grep -c '^component=' "$tc51_manifest")"
tc51_unique_count="$(grep '^component=' "$tc51_manifest" | sort -u | wc -l)"
(( tc51_record_count == tc51_unique_count && tc51_record_count == 14 )) && pass "component-manifest has one record per considered component" || fail "component-manifest duplicate or missing records ($tc51_record_count records, $tc51_unique_count unique)"
grep -q '^completed=true$' "$tc51_backup/manifest.txt" && pass "primary manifest complete after component manifest" || fail "primary manifest not complete"
tc51_rollback_exit=0
run_ahr "$tc51_optional_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc51_rollback_exit=$?
(( tc51_rollback_exit == 0 )) && pass "rollback accepts optional absent component records" || fail "rollback rejected optional absent records (exit $tc51_rollback_exit)"

for tc51_case in active-theme theme-state background-state; do
  tc51_home="$tmp_root/tc51_missing_$tc51_case"
  tc51_repo="$(create_test_repo "$tmp_root/tc51_repo_$tc51_case" "0.2.0")"
  setup_installed_framework "$tc51_home" "file://$tc51_repo"
  case "$tc51_case" in
    active-theme) rm -f "$tc51_home/.config/artix-hypr-remix/current/theme.name" ;;
    theme-state) rm -rf "$tc51_home/.config/artix-hypr-remix/current" ;;
    background-state) rm -f "$tc51_home/.config/artix-hypr-remix/current/background" ;;
  esac
  tc51_apply_exit=0
  run_ahr "$tc51_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc51_apply_exit=$?
  (( tc51_apply_exit != 0 )) && pass "missing required $tc51_case fails apply" || fail "missing required $tc51_case apply succeeded"
  tc51_version="$(json_get "$tc51_home/.config/artix-hypr-remix/framework.json" version)"
  [[ "$tc51_version" == "0.1.0" ]] && pass "missing required $tc51_case leaves installed version unchanged" || fail "missing required $tc51_case changed version to $tc51_version"
  tc51_req_backup="$(find "$tc51_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1)"
  [[ -n "$tc51_req_backup" ]] && pass "missing required $tc51_case preserves incomplete backup" || fail "missing required $tc51_case left no backup for diagnostics"
  tc51_req_manifest="$tc51_req_backup/component-manifest.txt"
  [[ "$(manifest_component_count "$tc51_req_manifest" "$tc51_case")" == "1" ]] && pass "missing required $tc51_case has one manifest record" || fail "missing required $tc51_case record count wrong"
  [[ "$(manifest_component_field "$tc51_req_manifest" "$tc51_case" required)" == "true" ]] && pass "missing required $tc51_case records required=true" || fail "missing required $tc51_case required flag wrong"
  [[ "$(manifest_component_field "$tc51_req_manifest" "$tc51_case" snapshot_status)" == "absent" ]] && pass "missing required $tc51_case records absent" || fail "missing required $tc51_case status wrong"
  if [[ -f "$tc51_req_backup/manifest.txt" ]] && grep -q '^completed=true$' "$tc51_req_backup/manifest.txt"; then
    fail "missing required $tc51_case marked backup complete"
  else
    pass "missing required $tc51_case backup is incomplete"
  fi
  tc51_tx_state="$(find "$tc51_home/.local/state/artix-hypr-remix/framework-transactions" -name state -type f 2>/dev/null | head -n1)"
  if [[ -n "$tc51_tx_state" ]] && ! grep -q '^activated_' "$tc51_tx_state" && ! grep -q '^phase=namespace_' "$tc51_tx_state" && ! grep -q '^phase=migration_' "$tc51_tx_state" && ! grep -q '^phase=health_check' "$tc51_tx_state"; then
    pass "missing required $tc51_case stops before activation"
  else
    fail "missing required $tc51_case reached activation or later phase"
  fi
  tc51_missing_rb_exit=0
  run_ahr "$tc51_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc51_missing_rb_exit=$?
  (( tc51_missing_rb_exit != 0 )) && pass "rollback rejects incomplete $tc51_case backup" || fail "rollback accepted incomplete $tc51_case backup"
done

# The focused association cases below use only deterministic fixture IDs and
# exact paths; they never rely on backup ordering or timestamp selection.
echo ""
echo "=== TC52: Primary manifest association validation ==="

manifest_exact_field() {
  local manifest="$1" key="$2"
  awk -v key="$key" 'index($0, key "=") == 1 { count++; value=substr($0, length(key) + 2) } END { if (count == 1) print value; else exit 1 }' "$manifest"
}

transaction_exact_field() {
  local state_file="$1" key="$2"
  awk -v key="$key" 'index($0, key "=") == 1 { count++; value=substr($0, length(key) + 2) } END { if (count == 1) print value; else exit 1 }' "$state_file"
}

tc52_home="$tmp_root/tc52"
tc52_repo="$(create_test_repo "$tmp_root/tc52_repo" "0.2.0")"
setup_installed_framework "$tc52_home" "file://$tc52_repo"
tc52_apply=0
run_ahr "$tc52_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc52_apply=$?
(( tc52_apply == 0 )) && pass "association fixture apply succeeds" || fail "association fixture apply failed (exit $tc52_apply)"
tc52_backup="$(find "$tc52_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
tc52_manifest="$tc52_backup/manifest.txt"
tc52_backup_id="$(manifest_exact_field "$tc52_manifest" backup_id 2>/dev/null || true)"
tc52_transaction_id="$(manifest_exact_field "$tc52_manifest" transaction_id 2>/dev/null || true)"
[[ -n "$tc52_backup_id" ]] && pass "successful backup has exactly one backup_id" || fail "successful backup backup_id is missing or duplicated"
[[ -n "$tc52_transaction_id" ]] && pass "successful backup has exactly one transaction_id" || fail "successful backup transaction_id is missing or duplicated"
[[ "$tc52_backup_id" == "$(basename "$tc52_backup")" ]] && pass "manifest backup_id matches backup directory" || fail "manifest backup_id does not match backup directory"
[[ -d "$tc52_home/.local/state/artix-hypr-remix/framework-transactions/$tc52_transaction_id" ]] && pass "manifest transaction_id matches transaction directory" || fail "manifest transaction_id does not match transaction directory"
tc52_txdir="$tc52_home/.local/state/artix-hypr-remix/framework-transactions/$tc52_transaction_id"
tc52_state="$tc52_txdir/state"
tc52_state_backup_id="$(transaction_exact_field "$tc52_state" backup_id 2>/dev/null || true)"
tc52_state_backup_path="$(transaction_exact_field "$tc52_state" backup_path 2>/dev/null || true)"
tc52_state_transaction_id="$(transaction_exact_field "$tc52_state" transaction_id 2>/dev/null || true)"
[[ "$tc52_state_backup_id" == "$tc52_backup_id" ]] && pass "terminal transaction retains exact backup_id" || fail "terminal transaction backup_id differs from manifest"
[[ "$tc52_state_backup_path" == "$tc52_backup" ]] && pass "terminal transaction retains exact backup_path" || fail "terminal transaction backup_path differs from backup"
[[ "$tc52_state_transaction_id" == "$tc52_transaction_id" ]] && pass "terminal transaction retains exact transaction_id" || fail "terminal transaction ID differs from manifest"
[[ "$(transaction_exact_field "$tc52_state" completion 2>/dev/null || true)" == "committed" && "$(transaction_exact_field "$tc52_state" phase 2>/dev/null || true)" == "complete" ]] && pass "terminal transaction is committed with association intact" || fail "terminal transaction was not committed with complete phase"

# Re-finalizing an already successful fixture may update only terminal timing;
# the immutable association must remain byte-for-byte equivalent.
tc52_refinalize_exit=0
HOME="$tc52_home" XDG_STATE_HOME="$tc52_home/.local/state" XDG_CACHE_HOME="$tc52_home/.cache" \
  AHR_FRAMEWORK_ROOT="$tc52_home/.config/artix-hypr-remix" \
  AHR_LIB_PATH="$tc52_home/.config/artix-hypr-remix/bin/ahr-lib.sh" \
  bash -s -- "$UPDATE_FRAMEWORK" "$tc52_txdir" <<'EOF' >/dev/null 2>&1 || tc52_refinalize_exit=$?
update_framework="$1"
txdir="$2"
set --
source <(sed -n '1,/^# ── JSON helpers/p' "$update_framework")
finalize_transaction "$txdir" committed complete
EOF
(( tc52_refinalize_exit == 0 )) && pass "terminal finalization accepts matching manifest association" || fail "terminal finalization rejected matching manifest association"
[[ "$(transaction_exact_field "$tc52_state" backup_id 2>/dev/null || true)" == "$tc52_state_backup_id" && "$(transaction_exact_field "$tc52_state" backup_path 2>/dev/null || true)" == "$tc52_state_backup_path" && "$(transaction_exact_field "$tc52_state" transaction_id 2>/dev/null || true)" == "$tc52_state_transaction_id" ]] && pass "terminal finalization cannot delete or change association" || fail "terminal finalization changed association"

# The reader must use the recorded association rather than a newer or
# unrelated backup directory. No timestamp or directory ordering is involved.
mkdir -p "$tc52_home/.local/state/artix-hypr-remix/framework-backups/unrelated-backup"
printf 'manifest_version=1\nbackup_id=unrelated-backup\ntransaction_id=tx-unrelated\n' > "$tc52_home/.local/state/artix-hypr-remix/framework-backups/unrelated-backup/manifest.txt"
[[ "$(transaction_exact_field "$tc52_state" backup_id 2>/dev/null || true)" == "$tc52_backup_id" && "$(transaction_exact_field "$tc52_state" transaction_id 2>/dev/null || true)" == "$tc52_transaction_id" ]] && pass "unrelated backup does not alter terminal transaction readback" || fail "unrelated backup changed terminal transaction readback"

# Validation evidence must capture the exact two artifacts before a caller's
# restoration handler removes Batch-created state.
tc52_evidence="$tmp_root/tc52-evidence"
tc52_evidence_exit=0
tc52_evidence_output="$(bash "$REPO_ROOT/scripts/preserve-framework-transaction-evidence.sh" \
  --state-root "$tc52_home/.local/state/artix-hypr-remix" \
  --transaction-id "$tc52_transaction_id" \
  --backup-id "$tc52_backup_id" \
  --apply-log "$tc52_home/.local/state/artix-hypr-remix/framework-update.log" \
  --output "$tc52_evidence" 2>&1)" || tc52_evidence_exit=$?
(( tc52_evidence_exit == 0 )) && pass "validation helper preserves exact transaction evidence" || fail "validation helper failed to preserve transaction evidence" "$tc52_evidence_output"
cmp -s "$tc52_state" "$tc52_evidence/transaction.state" && cmp -s "$tc52_manifest" "$tc52_evidence/manifest.txt" && grep -qx "transaction_id=$tc52_transaction_id" "$tc52_evidence/identity.txt" && grep -qx "backup_id=$tc52_backup_id" "$tc52_evidence/identity.txt" && pass "preserved evidence matches terminal transaction and manifest" || fail "preserved evidence did not match exact association"

# The structured writer rejects duplicate and malformed association fields;
# neither condition can be hidden by a terminal serialization pass.
tc52_duplicate_tx="$tmp_root/tc52-duplicate-tx"
cp -a "$tc52_txdir" "$tc52_duplicate_tx"
printf 'backup_id=%s\n' "$tc52_backup_id" >> "$tc52_duplicate_tx/state"
tc52_duplicate_exit=0
HOME="$tc52_home" XDG_STATE_HOME="$tc52_home/.local/state" XDG_CACHE_HOME="$tc52_home/.cache" \
  AHR_FRAMEWORK_ROOT="$tc52_home/.config/artix-hypr-remix" \
  AHR_LIB_PATH="$tc52_home/.config/artix-hypr-remix/bin/ahr-lib.sh" \
  bash -s -- "$UPDATE_FRAMEWORK" "$tc52_duplicate_tx" <<'EOF' >/dev/null 2>&1 || tc52_duplicate_exit=$?
update_framework="$1"
txdir="$2"
set --
source <(sed -n '1,/^# ── JSON helpers/p' "$update_framework")
write_transaction_state "$txdir" "phase=complete"
EOF
(( tc52_duplicate_exit != 0 )) && pass "duplicate transaction backup_id is rejected" || fail "duplicate transaction backup_id was accepted"
tc52_malformed_tx="$tmp_root/tc52-malformed-tx"
cp -a "$tc52_txdir" "$tc52_malformed_tx"
sed -i 's/^backup_id=.*/backup_id=bad\/path/' "$tc52_malformed_tx/state"
tc52_malformed_exit=0
HOME="$tc52_home" XDG_STATE_HOME="$tc52_home/.local/state" XDG_CACHE_HOME="$tc52_home/.cache" \
  AHR_FRAMEWORK_ROOT="$tc52_home/.config/artix-hypr-remix" \
  AHR_LIB_PATH="$tc52_home/.config/artix-hypr-remix/bin/ahr-lib.sh" \
  bash -s -- "$UPDATE_FRAMEWORK" "$tc52_malformed_tx" <<'EOF' >/dev/null 2>&1 || tc52_malformed_exit=$?
update_framework="$1"
txdir="$2"
set --
source <(sed -n '1,/^# ── JSON helpers/p' "$update_framework")
write_transaction_state "$txdir" "phase=complete"
EOF
(( tc52_malformed_exit != 0 )) && pass "malformed transaction backup_id is rejected" || fail "malformed transaction backup_id was accepted"

# Staged validation happens before backup/transaction creation. A failure at
# that point must not fabricate an association record.
tc52_prebackup_home="$tmp_root/tc52-prebackup"
tc52_prebackup_repo="$(create_test_repo "$tmp_root/tc52-prebackup-repo" "0.2.0")"
rm -f "$tc52_prebackup_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
commit_test_repo "$tc52_prebackup_repo" "missing staged doctor"
setup_installed_framework "$tc52_prebackup_home" "file://$tc52_prebackup_repo"
tc52_prebackup_exit=0
run_ahr "$tc52_prebackup_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc52_prebackup_exit=$?
(( tc52_prebackup_exit != 0 )) && pass "pre-backup staged validation fails" || fail "pre-backup staged validation unexpectedly succeeded"
if [[ -z "$(find "$tc52_prebackup_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]] && \
   [[ -z "$(find "$tc52_prebackup_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]]; then
  pass "failure before backup creates no fabricated association"
else
  fail "failure before backup created transaction or backup state"
fi

tc52_parser_dir="$tmp_root/tc52_parser"
mkdir -p "$tc52_parser_dir"
cat > "$tc52_parser_dir/good" <<'EOF'
manifest_version=1
backup_id=backup-A
transaction_id=tx-A
EOF
cat > "$tc52_parser_dir/legacy" <<'EOF'
manifest_version=1
EOF
for tc52_case in duplicate_backup duplicate_transaction malformed_backup malformed_transaction directory_mismatch malformed_key; do
  cp "$tc52_parser_dir/good" "$tc52_parser_dir/$tc52_case"
done
printf 'backup_id=backup-A\n' >> "$tc52_parser_dir/duplicate_backup"
printf 'transaction_id=tx-A\n' >> "$tc52_parser_dir/duplicate_transaction"
sed -i 's/^backup_id=.*/backup_id=bad\/path/' "$tc52_parser_dir/malformed_backup"
sed -i 's/^transaction_id=.*/transaction_id=not-a-transaction/' "$tc52_parser_dir/malformed_transaction"
sed -i 's/^backup_id=.*/backup_id=backup-B/' "$tc52_parser_dir/directory_mismatch"
sed -i 's/^backup_id=.*/backup_id broken/' "$tc52_parser_dir/malformed_key"
source "$FRAMEWORK_BIN/ahr-lib.sh"
ahr_parse_primary_manifest "$tc52_parser_dir/good" backup-A true && pass "strict parser accepts exact new-format association" || fail "strict parser rejected valid association"
ahr_parse_primary_manifest "$tc52_parser_dir/legacy" backup-A false && pass "legacy exact backup selection is accepted" || fail "legacy exact backup selection rejected"
ahr_parse_primary_manifest "$tc52_parser_dir/legacy" backup-A true && fail "legacy automatic association accepted" || pass "legacy automatic association rejected"
for tc52_case in duplicate_backup duplicate_transaction malformed_backup malformed_transaction directory_mismatch malformed_key; do
  ahr_parse_primary_manifest "$tc52_parser_dir/$tc52_case" backup-A true && fail "$tc52_case accepted" || pass "$tc52_case rejected"
done

# Existing failure fixtures cover each post-backup terminal path.  Their
# manifests and transaction states must retain the same two association IDs.
for tc52_failure in migration:"$tx_state_file" health:"$tc19_state" namespace:"$tc21_tx"; do
  tc52_label="${tc52_failure%%:*}"
  tc52_state="${tc52_failure#*:}"
  tc52_dir="$(dirname "$tc52_state")"
  tc52_backup_path="$(awk -F= '$1 == "backup_dir" { print substr($0, 12); exit }' "$tc52_state")"
  tc52_failure_manifest="$tc52_backup_path/manifest.txt"
  tc52_manifest_backup="$(manifest_exact_field "$tc52_failure_manifest" backup_id 2>/dev/null || true)"
  tc52_manifest_tx="$(manifest_exact_field "$tc52_failure_manifest" transaction_id 2>/dev/null || true)"
  [[ "$tc52_manifest_backup" == "$(basename "$tc52_backup_path")" && "$tc52_manifest_tx" == "$(basename "$tc52_dir")" ]] && pass "$tc52_label failure preserves manifest association IDs" || fail "$tc52_label failure changed manifest association IDs"
  [[ "$(transaction_exact_field "$tc52_state" backup_id 2>/dev/null || true)" == "$tc52_manifest_backup" && "$(transaction_exact_field "$tc52_state" transaction_id 2>/dev/null || true)" == "$tc52_manifest_tx" && "$(transaction_exact_field "$tc52_state" backup_path 2>/dev/null || true)" == "$tc52_backup_path" ]] && pass "$tc52_label failure preserves transaction association IDs and path" || fail "$tc52_label failure changed transaction association IDs or path"
done

echo ""
echo "=== TC53: Component status and required-unsupported behavior ==="

tc53_helper_backup="$tmp_root/tc53_helper_backup"
mkdir -p "$tc53_helper_backup"
tc53_helper_exit=0
bash -s -- "$FRAMEWORK_BIN/ahr-backup-helper.sh" "$tc53_helper_backup" <<'EOF' || tc53_helper_exit=$?
set -euo pipefail
source "$1"
ahr_snapshot_component required-structured /does/not/matter "$2" structured-file true framework unsupported
EOF
(( tc53_helper_exit != 0 )) && pass "required unsupported component fails snapshot" || fail "required unsupported component snapshot succeeded"
[[ "$(manifest_component_field "$tc53_helper_backup/component-manifest.txt" required-structured snapshot_status)" == "unsupported" ]] && pass "required unsupported component is recorded as unsupported" || fail "required unsupported component status wrong"

tc53_make_backup() {
  local home="$1" id="$2" status="$3"
  local backup="$home/.local/state/artix-hypr-remix/framework-backups/$id"
  mkdir -p "$home/.config/artix-hypr-remix/current/theme" "$backup/derived-theme-state/theme"
  printf 'live\n' > "$home/.config/artix-hypr-remix/current/theme/marker"
  printf 'saved\n' > "$backup/derived-theme-state/theme/marker"
  printf 'manifest_version=1\ncompleted=true\nbackup_id=%s\ntransaction_id=tx-%s\n' "$id" "$id" > "$backup/manifest.txt"
  if [[ "$status" == "present" ]]; then
    printf 'component=theme-state\nsnapshot_path=%s/snapshots/theme-state\nsnapshot_status=%s\n---\n' "$backup" "$status" > "$backup/component-manifest.txt"
  else
    printf 'component=theme-state\nsnapshot_path=\nsnapshot_status=%s\n---\n' "$status" > "$backup/component-manifest.txt"
  fi
}

tc53_present_home="$tmp_root/tc53_present"
tc53_make_backup "$tc53_present_home" component-present present
tc53_present_exit=0
run_restore_component "$tc53_present_home" theme-state --backup component-present --apply >/dev/null 2>&1 || tc53_present_exit=$?
if (( tc53_present_exit == 0 )) && [[ -f "$tc53_present_home/.config/artix-hypr-remix/current/theme/marker" ]] && [[ "$(cat "$tc53_present_home/.config/artix-hypr-remix/current/theme/marker")" == "saved" ]]; then
  pass "present component follows normal restore path"
else
  fail "present component restore failed"
fi

for tc53_status in absent unsupported failed unknown; do
  tc53_home="$tmp_root/tc53_$tc53_status"
  tc53_id="component-$tc53_status"
  tc53_make_backup "$tc53_home" "$tc53_id" "$tc53_status"
  tc53_output="$(run_restore_component "$tc53_home" theme-state --backup "$tc53_id" --apply 2>&1 || true)"
  [[ "$(cat "$tc53_home/.config/artix-hypr-remix/current/theme/marker")" == "live" ]] && pass "$tc53_status component is rejected before mutation" || fail "$tc53_status component mutated target"
  case "$tc53_status" in
    absent) grep -q 'was absent' <<<"$tc53_output" ;;
    unsupported) grep -q 'automatic restoration is unsupported' <<<"$tc53_output" ;;
    failed) grep -q 'no valid restorable snapshot' <<<"$tc53_output" ;;
    unknown) grep -q 'invalid component snapshot status' <<<"$tc53_output" ;;
  esac
  [[ $? == 0 ]] && pass "$tc53_status component reports distinct status" || fail "$tc53_status component status message missing"
done

echo ""
echo "=== TC54: Rollback uses exact failed-transaction backup ==="

tc54_home="$tmp_root/tc54"
tc54_repo="$(create_test_repo "$tmp_root/tc54_repo" "0.2.0")"
setup_installed_framework "$tc54_home" "file://$tc54_repo"
printf '#!/usr/bin/env bash\nexit 7\n' > "$tc54_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
chmod +x "$tc54_repo/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
(cd "$tc54_repo" && git add -A && git commit -q -m "failing doctor for association" >/dev/null)
run_ahr "$tc54_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || true
tc54_backup="$(find "$tc54_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
tc54_manifest="$tc54_backup/manifest.txt"
tc54_state="$(find "$tc54_home/.local/state/artix-hypr-remix/framework-transactions" -name state -type f -print -quit)"
cp "$tc54_manifest" "$tc54_manifest.saved"
cp "$tc54_state" "$tc54_state.saved"

# Each corrupt association must stop before rollback changes the installed
# framework.  Restore the isolated fixture record after every assertion.
sed -i 's/^transaction_id=.*/transaction_id=tx-other/' "$tc54_manifest"
tc54_bad_tx=0
run_ahr "$tc54_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc54_bad_tx=$?
if (( tc54_bad_tx != 0 )) && [[ "$(json_get "$tc54_home/.config/artix-hypr-remix/framework.json" version)" == "0.2.0" ]]; then
  pass "transaction/manifest transaction-ID mismatch rejected before mutation"
else
  fail "transaction-ID mismatch was not safely rejected"
fi
cp "$tc54_manifest.saved" "$tc54_manifest"

sed -i 's/^backup_id=.*/backup_id=backup-other/' "$tc54_manifest"
tc54_bad_backup=0
run_ahr "$tc54_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc54_bad_backup=$?
if (( tc54_bad_backup != 0 )) && [[ "$(json_get "$tc54_home/.config/artix-hypr-remix/framework.json" version)" == "0.2.0" ]]; then
  pass "backup-directory/manifest-ID mismatch rejected before mutation"
else
  fail "backup-directory mismatch was not safely rejected"
fi
cp "$tc54_manifest.saved" "$tc54_manifest"

sed -i 's/^backup_id=.*/backup_id=backup-other/' "$tc54_state"
tc54_bad_state=0
run_ahr "$tc54_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc54_bad_state=$?
if (( tc54_bad_state != 0 )) && [[ "$(json_get "$tc54_home/.config/artix-hypr-remix/framework.json" version)" == "0.2.0" ]]; then
  pass "transaction/manifest backup-ID mismatch rejected before mutation"
else
  fail "transaction backup-ID mismatch was not safely rejected"
fi
cp "$tc54_state.saved" "$tc54_state"

# An unrelated complete backup exists alongside the explicitly associated
# failed apply.  A test-only stat shim makes it appear newer without changing
# filesystem timestamps; its invalid payload proves it was not selected.
tc54_other="$tc54_home/.local/state/artix-hypr-remix/framework-backups/unrelated-backup"
cp -a "$tc54_backup" "$tc54_other"
sed -i 's/^backup_id=.*/backup_id=unrelated-backup/; s/^transaction_id=.*/transaction_id=tx-unrelated/' "$tc54_other/manifest.txt"
rm -rf "$tc54_other/docs"
tc54_fakebin="$tc54_home/fakebin"
mkdir -p "$tc54_fakebin"
cat > "$tc54_fakebin/stat" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do path="$arg"; done
case "$path" in
  *unrelated-backup*) printf '200\n' ;;
  *) printf '100\n' ;;
esac
EOF
chmod +x "$tc54_fakebin/stat"
tc54_rollback=0
PATH="$tc54_fakebin:$PATH" run_ahr "$tc54_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc54_rollback=$?
if (( tc54_rollback == 0 )) && [[ "$(json_get "$tc54_home/.config/artix-hypr-remix/framework.json" version)" == "0.1.0" ]]; then
  pass "exact recorded backup wins over unrelated backup"
else
  fail "rollback did not use exact failed-transaction backup"
fi

echo ""
echo "=== TC55: Restore selector and target roots ==="
tc55_home="$tmp_root/tc55"
tc55_fw="$tc55_home/.config/artix-hypr-remix"
tc55_backup="$tc55_home/.local/state/artix-hypr-remix/framework-backups/selector-fixture"
mkdir -p "$tc55_fw/current/theme" "$tc55_home/.local/bin" "$tc55_backup/snapshots" "$tmp_root/tc55-unrelated"
printf '{"version":"0.2.0"}\n' > "$tc55_fw/framework.json"
printf 'saved\n' > "$tc55_backup/derived-framework-config"
printf 'manifest_version=1\ncompleted=true\nbackup_id=selector-fixture\ntransaction_id=tx-selector-fixture\n' > "$tc55_backup/manifest.txt"
printf 'ahr\t%s/bin/ahr\n' "$tc55_fw" > "$tc55_backup/derived-namespace-links"
mkdir -p "$tc55_backup/snapshots/theme-state"
printf 'saved\n' > "$tc55_backup/snapshots/theme-state/value"
for tc55_component in active-theme waybar-theme mako-theme terminal-theme fontconfig; do printf 'saved\n' > "$tc55_backup/snapshots/$tc55_component"; done
ln -s target "$tc55_backup/snapshots/background-state"
printf 'component=theme-state\nsnapshot_path=%s/snapshots/theme-state\nsnapshot_status=present\n---\ncomponent=active-theme\nsnapshot_path=%s/snapshots/active-theme\nsnapshot_status=present\n---\ncomponent=background-state\nsnapshot_path=%s/snapshots/background-state\nsnapshot_status=present\n---\ncomponent=waybar-theme\nsnapshot_path=%s/snapshots/waybar-theme\nsnapshot_status=present\n---\ncomponent=mako-theme\nsnapshot_path=%s/snapshots/mako-theme\nsnapshot_status=present\n---\ncomponent=terminal-theme\nsnapshot_path=%s/snapshots/terminal-theme\nsnapshot_status=present\n---\ncomponent=fontconfig\nsnapshot_path=%s/snapshots/fontconfig\nsnapshot_status=present\n---\ncomponent=foot-theme\nsnapshot_path=\nsnapshot_status=absent\n---\ncomponent=chromium-theme\nsnapshot_path=\nsnapshot_status=unsupported\n---\n' "$tc55_backup" "$tc55_backup" "$tc55_backup" "$tc55_backup" "$tc55_backup" "$tc55_backup" "$tc55_backup" > "$tc55_backup/component-manifest.txt"
tc55_run() { (cd "$tmp_root/tc55-unrelated" && HOME="$tc55_home" XDG_CONFIG_HOME="$tc55_home/.config" XDG_STATE_HOME="$tc55_home/.local/state" AHR_FRAMEWORK_ROOT="$tc55_fw" AHR_LOCAL_BIN="$tc55_home/.local/bin" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" bash "$RESTORE_COMPONENT" "$@"); }
find "$tc55_fw" -xdev -printf '%y %m %s %p -> %l\n' | sort > "$tmp_root/tc55-before"
for tc55_component in framework-config namespace-links theme-state active-theme background-state waybar-theme mako-theme terminal-theme fontconfig; do tc55_out="$(tc55_run "$tc55_component" --backup selector-fixture 2>&1)"; grep -q "canonical=$tc55_component" <<<"$tc55_out" && pass "$tc55_component selector maps canonically" || fail "$tc55_component selector mapping failed"; done
tc55_waybar="$(tc55_run waybar-theme --backup selector-fixture 2>&1)"; grep -q "Target: $tc55_home/.config/waybar/style.css" <<<"$tc55_waybar" && pass "Waybar target uses XDG config root" || fail "Waybar target root incorrect"
tc55_mako="$(tc55_run mako-theme --backup selector-fixture 2>&1)"; grep -q "Target: $tc55_home/.config/mako/config" <<<"$tc55_mako" && pass "Mako target uses XDG config root" || fail "Mako target root incorrect"
tc55_terminal="$(tc55_run terminal-theme --backup selector-fixture 2>&1)"; grep -q "Target: $tc55_home/.config/ghostty/config" <<<"$tc55_terminal" && pass "terminal target uses XDG config root" || fail "terminal target root incorrect"
tc55_font="$(tc55_run fontconfig --backup selector-fixture 2>&1)"; grep -q "Target: $tc55_home/.config/fontconfig/fonts.conf" <<<"$tc55_font" && pass "Fontconfig target uses XDG config root" || fail "Fontconfig target root incorrect"
tc55_ns="$(tc55_run namespace-links --backup selector-fixture 2>&1)"; grep -q "Target: $tc55_home/.local/bin" <<<"$tc55_ns" && pass "namespace target uses local-bin root" || fail "namespace target root incorrect"
tc55_theme="$(tc55_run theme-state --backup selector-fixture 2>&1)"; grep -q "Target: $tc55_fw/current" <<<"$tc55_theme" && pass "theme-state dry-run uses framework root" || fail "theme-state target root incorrect"
find "$tc55_fw" -xdev -printf '%y %m %s %p -> %l\n' | sort > "$tmp_root/tc55-after"; diff -u "$tmp_root/tc55-before" "$tmp_root/tc55-after" && pass "dry-run from unrelated cwd is non-mutating" || fail "dry-run mutated framework"
tc55_absent="$(tc55_run foot-theme --backup selector-fixture 2>&1 || true)"; grep -q 'was absent' <<<"$tc55_absent" && pass "absent status remains distinct" || fail "absent status not reported"
tc55_unsupported="$(tc55_run chromium-theme --backup selector-fixture 2>&1 || true)"; grep -q 'automatic restoration is unsupported' <<<"$tc55_unsupported" && pass "unsupported status remains distinct" || fail "unsupported status not reported"
tc55_unknown=0; tc55_run no-such-component --backup selector-fixture >/dev/null 2>&1 || tc55_unknown=$?; (( tc55_unknown != 0 )) && pass "unknown public component is rejected" || fail "unknown public component accepted"
printf 'component=theme-state\nsnapshot_path=%s/snapshots/theme-state\nsnapshot_status=present\n---\n' "$tc55_backup" >> "$tc55_backup/component-manifest.txt"
tc55_duplicate=0; tc55_run theme-state --backup selector-fixture >/dev/null 2>&1 || tc55_duplicate=$?; (( tc55_duplicate != 0 )) && pass "duplicate canonical manifest record is rejected" || fail "duplicate canonical record accepted"

echo ""
echo "=== TC56: Historical namespace TSV restore parser ==="

tc56_home="$tmp_root/tc56"
tc56_fw="$tc56_home/.config/artix-hypr-remix"
tc56_local="$tc56_home/.local/bin"
mkdir -p "$tc56_fw/bin" "$tc56_local"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc56_home/.config/"

tc56_make_backup() {
  local id="$1"
  local backup="$tc56_home/.local/state/artix-hypr-remix/framework-backups/$id"
  mkdir -p "$backup"
  printf 'manifest_version=1\ncompleted=true\nbackup_id=%s\ntransaction_id=tx-%s\n' "$id" "$id" > "$backup/manifest.txt"
  printf '%s' "$backup"
}

# This uses the production schema and structurally matches the live 107-record
# backup using the same canonical inventory as namespace-install.sh.
source "$FRAMEWORK_BIN/ahr-lib.sh"
tc56_backup="$(tc56_make_backup live-tsv)"
tc56_records=0
declare -a tc56_names=()
: > "$tc56_backup/derived-namespace-links"
for tc56_name in "${AHR_NAMESPACE_COMMANDS[@]}"; do
  (( tc56_records < 107 )) || break
  [[ -f "$tc56_fw/bin/$tc56_name" ]] || continue
  printf '%s\t%s/bin/%s\n' "$tc56_name" "$tc56_fw" "$tc56_name" >> "$tc56_backup/derived-namespace-links"
  tc56_names+=("$tc56_name")
  ((tc56_records+=1))
done
for tc56_alias in "${AHR_NAMESPACE_ALIASES[@]}"; do
  (( tc56_records < 107 )) || break
  tc56_name="${tc56_alias%%:*}"
  tc56_alias_target="${tc56_alias##*:}"
  printf '%s\t%s/%s\n' "$tc56_name" "$tc56_local" "$tc56_alias_target" >> "$tc56_backup/derived-namespace-links"
  tc56_names+=("$tc56_name")
  ((tc56_records+=1))
done
(( tc56_records == 107 )) || fail "canonical inventory did not provide 107 records"
ln -s "$tc56_fw/bin/ahr-doctor" "$tc56_local/ahr"
printf 'user data\n' > "$tc56_local/unrelated-regular"
ln -s /usr/bin/true "$tc56_local/unrelated-symlink"

tc56_plan_rc=0
tc56_plan_output="$(run_restore_component "$tc56_home" namespace-links --backup live-tsv 2>&1)" || tc56_plan_rc=$?
(( tc56_plan_rc == 0 )) && grep -q "ahr-update-framework -> $tc56_fw/bin/ahr-update-framework" <<<"$tc56_plan_output" && pass "107-record production TSV is accepted by dry-run" || fail "production TSV dry-run rejected" "$tc56_plan_output"
[[ "$(readlink "$tc56_local/ahr")" == "$tc56_fw/bin/ahr-doctor" ]] && pass "dry-run leaves changed managed link untouched" || fail "dry-run changed managed link"

tc56_apply_rc=0
run_restore_component "$tc56_home" namespace-links --backup live-tsv --apply >/dev/null 2>&1 || tc56_apply_rc=$?
if (( tc56_apply_rc == 0 )) && [[ "$(readlink "$tc56_local/ahr")" == "$tc56_fw/bin/ahr" ]] && [[ "$(readlink "$tc56_local/ahr-doctor")" == "$tc56_fw/bin/ahr-doctor" ]]; then
  pass "same production TSV is accepted by apply and restores exact targets"
else
  fail "production TSV apply did not restore exact targets"
fi
tc56_count=0
for tc56_name in "${tc56_names[@]}"; do
  [[ -L "$tc56_local/$tc56_name" ]] && ((tc56_count+=1))
done
(( tc56_count == 107 )) && pass "all 107 validated namespace records are restored" || fail "expected 107 restored links, got $tc56_count"
[[ "$(cat "$tc56_local/unrelated-regular")" == "user data" ]] && pass "unrelated regular namespace entry is preserved" || fail "unrelated regular namespace entry changed"
[[ "$(readlink "$tc56_local/unrelated-symlink")" == "/usr/bin/true" ]] && pass "unrelated symlink namespace entry is preserved" || fail "unrelated symlink namespace entry changed"

# The existing namespace ownership policy accepts only framework/local-bin
# absolute targets, so plan and apply must reject the same relative target.
tc56_relative="$(tc56_make_backup relative-target)"
printf 'ahr\tbin/ahr\n' > "$tc56_relative/derived-namespace-links"
tc56_relative_plan=0; run_restore_component "$tc56_home" namespace-links --backup relative-target >/dev/null 2>&1 || tc56_relative_plan=$?
tc56_relative_apply=0; run_restore_component "$tc56_home" namespace-links --backup relative-target --apply >/dev/null 2>&1 || tc56_relative_apply=$?
(( tc56_relative_plan != 0 && tc56_relative_apply != 0 )) && pass "relative targets follow the existing rejection policy in plan and apply" || fail "relative target policy diverged"

# Each invalid TSV form must be rejected by both entry points before the
# existing managed link is touched.
for tc56_case in empty-name empty-target extra-field duplicate slash dot dotdot malformed; do
  tc56_bad="$(tc56_make_backup "bad-$tc56_case")"
  case "$tc56_case" in
    empty-name) printf '\t%s/bin/ahr\n' "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
    empty-target) printf 'ahr\t\n' > "$tc56_bad/derived-namespace-links" ;;
    extra-field) printf 'ahr\t%s/bin/ahr\textra\n' "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
    duplicate) printf 'ahr\t%s/bin/ahr\nahr\t%s/bin/ahr-doctor\n' "$tc56_fw" "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
    slash) printf 'ahr/bad\t%s/bin/ahr\n' "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
    dot) printf '.\t%s/bin/ahr\n' "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
    dotdot) printf '..\t%s/bin/ahr\n' "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
    malformed) printf 'ahr %s/bin/ahr\n' "$tc56_fw" > "$tc56_bad/derived-namespace-links" ;;
  esac
  ln -sfn "$tc56_fw/bin/ahr-doctor" "$tc56_local/ahr"
  tc56_bad_plan=0; run_restore_component "$tc56_home" namespace-links --backup "bad-$tc56_case" >/dev/null 2>&1 || tc56_bad_plan=$?
  tc56_bad_apply=0; run_restore_component "$tc56_home" namespace-links --backup "bad-$tc56_case" --apply >/dev/null 2>&1 || tc56_bad_apply=$?
  if (( tc56_bad_plan != 0 && tc56_bad_apply != 0 )) && [[ "$(readlink "$tc56_local/ahr")" == "$tc56_fw/bin/ahr-doctor" ]]; then
    pass "$tc56_case TSV is rejected identically before mutation"
  else
    fail "$tc56_case TSV parser or atomicity failure"
  fi
done

tc56_atomic="$(tc56_make_backup malformed-among-many)"
printf 'ahr\t%s/bin/ahr\nahr-doctor\t%s/bin/ahr-doctor\nbad-record\nahr-update-framework\t%s/bin/ahr-update-framework\n' "$tc56_fw" "$tc56_fw" "$tc56_fw" > "$tc56_atomic/derived-namespace-links"
ln -sfn "$tc56_fw/bin/ahr-doctor" "$tc56_local/ahr"
ln -sfn "$tc56_fw/bin/ahr" "$tc56_local/ahr-doctor"
tc56_atomic_rc=0; run_restore_component "$tc56_home" namespace-links --backup malformed-among-many --apply >/dev/null 2>&1 || tc56_atomic_rc=$?
if (( tc56_atomic_rc != 0 )) && [[ "$(readlink "$tc56_local/ahr")" == "$tc56_fw/bin/ahr-doctor" ]] && [[ "$(readlink "$tc56_local/ahr-doctor")" == "$tc56_fw/bin/ahr" ]]; then
  pass "one malformed record prevents every namespace mutation"
else
  fail "malformed record produced partial namespace restoration"
fi

tc56_conflict="$(tc56_make_backup user-conflict)"
printf 'ahr\t%s/bin/ahr\n' "$tc56_fw" > "$tc56_conflict/derived-namespace-links"
rm -f "$tc56_local/ahr"
printf 'do not replace\n' > "$tc56_local/ahr"
tc56_conflict_rc=0; run_restore_component "$tc56_home" namespace-links --backup user-conflict --apply >/dev/null 2>&1 || tc56_conflict_rc=$?
if (( tc56_conflict_rc != 0 )) && [[ "$(cat "$tc56_local/ahr")" == "do not replace" ]]; then
  pass "user-owned conflicting namespace entry is not overwritten"
else
  fail "user-owned namespace conflict was not preserved"
fi
ln -sfn "$tc56_fw/bin/ahr" "$tc56_local/ahr-doctor"
tc56_many_conflict_rc=0; run_restore_component "$tc56_home" namespace-links --backup live-tsv --apply >/dev/null 2>&1 || tc56_many_conflict_rc=$?
if (( tc56_many_conflict_rc != 0 )) && [[ "$(readlink "$tc56_local/ahr-doctor")" == "$tc56_fw/bin/ahr" ]]; then
  pass "one regular conflict among 107 valid records prevents all mutation"
else
  fail "107-record conflict allowed partial namespace restoration"
fi

echo ""
echo "=== TC57: Stale canonical namespace slots are repairable ==="

tc57_home="$tmp_root/tc57"
tc57_fw="$tc57_home/.config/artix-hypr-remix"
tc57_local="$tc57_home/.local/bin"
mkdir -p "$tc57_home/.config" "$tc57_local"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc57_home/.config/"
tc57_make_backup() {
  local id="$1" backup="$tc57_home/.local/state/artix-hypr-remix/framework-backups/$1"
  mkdir -p "$backup"
  printf 'manifest_version=1\ncompleted=true\nbackup_id=%s\ntransaction_id=tx-%s\n' "$id" "$id" > "$backup/manifest.txt"
  printf '%s' "$backup"
}
tc57_backup="$(tc57_make_backup stale-link)"
printf 'ahr\t%s/bin/ahr\nahr-doctor\t%s/bin/ahr-doctor\n' "$tc57_fw" "$tc57_fw" > "$tc57_backup/derived-namespace-links"
ln -s /tmp/distinctive-non-ahr-target "$tc57_local/ahr"
ln -s /usr/bin/true "$tc57_local/unrelated-symlink"
printf 'unrelated\n' > "$tc57_local/unrelated-regular"
tc57_plan_rc=0
tc57_plan="$(run_restore_component "$tc57_home" namespace-links --backup stale-link 2>&1)" || tc57_plan_rc=$?
if (( tc57_plan_rc == 0 )) && grep -q 'ahr -> .*\[repairable-stale-managed\]' <<<"$tc57_plan"; then
  pass "dry-run classifies foreign-target managed slot as repairable"
else
  fail "dry-run did not classify foreign-target managed slot as repairable" "$tc57_plan"
fi
tc57_apply_rc=0; run_restore_component "$tc57_home" namespace-links --backup stale-link --apply >/dev/null 2>&1 || tc57_apply_rc=$?
if (( tc57_apply_rc == 0 )) && [[ "$(readlink "$tc57_local/ahr")" == "$tc57_fw/bin/ahr" ]] && [[ "$(readlink "$tc57_local/unrelated-symlink")" == /usr/bin/true ]] && [[ "$(cat "$tc57_local/unrelated-regular")" == unrelated ]]; then
  pass "foreign-target managed symlink restores exactly without touching neighbors"
else
  fail "foreign-target managed symlink restoration failed"
fi

ln -sfn "$tc57_fw/bin/ahr-doctor" "$tc57_local/ahr"
tc57_stale_rc=0; run_restore_component "$tc57_home" namespace-links --backup stale-link --apply >/dev/null 2>&1 || tc57_stale_rc=$?
if (( tc57_stale_rc == 0 )) && [[ "$(readlink "$tc57_local/ahr")" == "$tc57_fw/bin/ahr" ]]; then pass "stale AHR target restores successfully"; else fail "stale AHR target restore failed"; fi
ln -sfn "$tc57_fw/bin/missing-command" "$tc57_local/ahr"
tc57_broken_rc=0; run_restore_component "$tc57_home" namespace-links --backup stale-link --apply >/dev/null 2>&1 || tc57_broken_rc=$?
if (( tc57_broken_rc == 0 )) && [[ "$(readlink "$tc57_local/ahr")" == "$tc57_fw/bin/ahr" ]]; then pass "broken managed target restores successfully"; else fail "broken managed target restore failed"; fi
rm -f "$tc57_local/ahr-doctor"
tc57_absent_rc=0; run_restore_component "$tc57_home" namespace-links --backup stale-link --apply >/dev/null 2>&1 || tc57_absent_rc=$?
if (( tc57_absent_rc == 0 )) && [[ "$(readlink "$tc57_local/ahr-doctor")" == "$tc57_fw/bin/ahr-doctor" ]]; then pass "absent managed slot is recreated exactly"; else fail "absent managed slot was not recreated"; fi

tc57_unknown="$(tc57_make_backup unknown-name)"
printf 'ahr-not-inventory\t%s/bin/ahr\n' "$tc57_fw" > "$tc57_unknown/derived-namespace-links"
tc57_unknown_plan=0; run_restore_component "$tc57_home" namespace-links --backup unknown-name >/dev/null 2>&1 || tc57_unknown_plan=$?
tc57_unknown_apply=0; run_restore_component "$tc57_home" namespace-links --backup unknown-name --apply >/dev/null 2>&1 || tc57_unknown_apply=$?
(( tc57_unknown_plan != 0 && tc57_unknown_apply != 0 )) && pass "snapshot name outside canonical inventory is rejected consistently" || fail "non-canonical snapshot name was accepted"

tc57_conflict="$(tc57_make_backup managed-file-conflict)"
printf 'ahr\t%s/bin/ahr\nahr-doctor\t%s/bin/ahr-doctor\n' "$tc57_fw" "$tc57_fw" > "$tc57_conflict/derived-namespace-links"
rm -f "$tc57_local/ahr"
printf 'user-owned\n' > "$tc57_local/ahr"
ln -sfn "$tc57_fw/bin/ahr" "$tc57_local/ahr-doctor"
tc57_conflict_rc=0; run_restore_component "$tc57_home" namespace-links --backup managed-file-conflict --apply >/dev/null 2>&1 || tc57_conflict_rc=$?
if (( tc57_conflict_rc != 0 )) && [[ "$(cat "$tc57_local/ahr")" == user-owned ]] && [[ "$(readlink "$tc57_local/ahr-doctor")" == "$tc57_fw/bin/ahr" ]]; then
  pass "managed regular-file conflict is preserved before all mutation"
else
  fail "managed regular-file conflict was not safely rejected"
fi
rm -f "$tc57_local/ahr"
mkdir "$tc57_local/ahr"
tc57_directory_rc=0; run_restore_component "$tc57_home" namespace-links --backup managed-file-conflict --apply >/dev/null 2>&1 || tc57_directory_rc=$?
if (( tc57_directory_rc != 0 )) && [[ -d "$tc57_local/ahr" ]]; then pass "managed directory conflict is preserved"; else fail "managed directory conflict was not safely rejected"; fi

echo ""
echo "=== TC58: Controlled post-activation health fault ==="

tc58_normal_home="$tmp_root/tc58_normal"
tc58_normal_repo="$(create_test_repo "$tmp_root/tc58_normal_repo" "0.2.0")"
setup_installed_framework "$tc58_normal_home" "file://$tc58_normal_repo"
tc58_normal_exit=0
AHR_TEST_FAIL_HEALTH_CHECK= run_ahr "$tc58_normal_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc58_normal_exit=$?
if (( tc58_normal_exit == 0 )) && [[ "$(json_get "$tc58_normal_home/.config/artix-hypr-remix/framework.json" version)" == "0.2.0" ]]; then pass "unset health fault leaves successful apply unchanged"; else fail "unset health fault changed normal apply behavior"; fi

tc58_home="$tmp_root/tc58"
tc58_repo="$(create_test_repo "$tmp_root/tc58_repo" "0.2.0")"
setup_installed_framework "$tc58_home" "file://$tc58_repo"
tc58_staged="$tc58_repo/artix-hypr-remix/config/artix-hypr-remix"
cat > "$tc58_staged/bin/namespace-install.sh" <<'EOF'
#!/usr/bin/env bash
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/namespace-before-health.marker"
EOF
cat > "$tc58_staged/bin/migrate.sh" <<'EOF'
#!/usr/bin/env bash
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/migration-before-health.marker"
EOF
cat > "$tc58_staged/bin/ahr-doctor" <<'EOF'
#!/usr/bin/env bash
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/real-doctor-ran.marker"
printf 'real doctor passed\n'
exit 0
EOF
chmod +x "$tc58_staged/bin/namespace-install.sh" "$tc58_staged/bin/migrate.sh" "$tc58_staged/bin/ahr-doctor"
(cd "$tc58_repo" && git add -A && git commit -q -m "health fault fixture" >/dev/null)
tc58_staged_doctor_sum="$(sha256sum "$tc58_staged/bin/ahr-doctor" | awk '{print $1}')"

tc58_apply_exit=0
tc58_apply_output="$(AHR_TEST_FAIL_HEALTH_CHECK=1 run_ahr "$tc58_home" "$UPDATE_FRAMEWORK" --apply 2>&1)" || tc58_apply_exit=$?
(( tc58_apply_exit != 0 )) && pass "enabled health fault exits nonzero" || fail "enabled health fault exited zero"
grep -q 'real doctor passed' <<<"$tc58_apply_output" && pass "real doctor runs before injected failure" || fail "real doctor output missing before injected failure"
grep -q 'TEST FAULT: forcing post-activation health-check failure' <<<"$tc58_apply_output" && pass "injected health fault is clearly logged" || fail "injected health-fault log missing"

tc58_state="$(find "$tc58_home/.local/state/artix-hypr-remix/framework-transactions" -name state -type f -print -quit)"
tc58_txdir="$(dirname "$tc58_state")"
tc58_backup="$(awk -F= '$1 == "backup_path" { print substr($0, 13); exit }' "$tc58_state")"
tc58_manifest="$tc58_backup/manifest.txt"
[[ -f "$tc58_state" && -d "$tc58_backup" && -f "$tc58_manifest" ]] && pass "backup and transaction exist before injected health failure" || fail "injected health failure did not retain backup and transaction"
grep -q '^phase=health_check_failed$' "$tc58_state" && pass "injected failure uses health_check_failed phase" || fail "injected failure phase was not health_check_failed"
grep -q '^completion=health_check_failed$' "$tc58_state" && pass "injected failure uses health_check_failed completion" || fail "injected failure completion was not health_check_failed"
grep -q '^failure_reason=test_fault_forced_health_check_failure$' "$tc58_state" && pass "injected failure reason is distinguishable" || fail "injected failure reason was not distinguishable"
! grep -q '^completion=committed$' "$tc58_state" && pass "injected transaction is not committed" || fail "injected transaction was committed"

tc58_txid="$(awk -F= '$1 == "transaction_id" { print substr($0, 16); exit }' "$tc58_state")"
tc58_backup_id="$(awk -F= '$1 == "backup_id" { print substr($0, 11); exit }' "$tc58_state")"
tc58_manifest_txid="$(awk -F= '$1 == "transaction_id" { print substr($0, 16); exit }' "$tc58_manifest")"
tc58_manifest_backup_id="$(awk -F= '$1 == "backup_id" { print substr($0, 11); exit }' "$tc58_manifest")"
if [[ "$tc58_txid" == "$(basename "$tc58_txdir")" && "$tc58_backup_id" == "$(basename "$tc58_backup")" && "$tc58_txid" == "$tc58_manifest_txid" && "$tc58_backup_id" == "$tc58_manifest_backup_id" ]]; then pass "injected failure preserves exact transaction and backup provenance"; else fail "injected failure changed transaction or backup provenance"; fi

[[ "$(json_get "$tc58_home/.config/artix-hypr-remix/framework.json" version)" == "0.2.0" ]] && pass "activation completed before injected failure" || fail "activation did not complete before injected failure"
[[ -f "$tc58_home/.config/artix-hypr-remix/namespace-before-health.marker" ]] && pass "namespace completed before injected failure" || fail "namespace did not complete before injected failure"
[[ -f "$tc58_home/.config/artix-hypr-remix/migration-before-health.marker" ]] && pass "migration completed before injected failure" || fail "migration did not complete before injected failure"
[[ -f "$tc58_home/.config/artix-hypr-remix/real-doctor-ran.marker" ]] && pass "real doctor succeeded before updater fault" || fail "real doctor marker missing"
tc58_installed_doctor_sum="$(sha256sum "$tc58_home/.config/artix-hypr-remix/bin/ahr-doctor" | awk '{print $1}')"
[[ "$tc58_installed_doctor_sum" == "$tc58_staged_doctor_sum" ]] && pass "hook does not modify doctor executable" || fail "hook modified doctor executable"

tc58_tx_count_before_invalid="$(find "$tc58_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
tc58_backup_count_before_invalid="$(find "$tc58_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d | wc -l)"
tc58_invalid_exit=0
tc58_invalid_output="$(AHR_TEST_FAIL_HEALTH_CHECK=true run_ahr "$tc58_home" "$UPDATE_FRAMEWORK" --dry-run 2>&1)" || tc58_invalid_exit=$?
tc58_tx_count_after_invalid="$(find "$tc58_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
tc58_backup_count_after_invalid="$(find "$tc58_home/.local/state/artix-hypr-remix/framework-backups" -mindepth 1 -maxdepth 1 -type d | wc -l)"
if (( tc58_invalid_exit != 0 )) && grep -q "Invalid AHR_TEST_FAIL_HEALTH_CHECK value: expected exactly '1' when set" <<<"$tc58_invalid_output" && [[ "$tc58_tx_count_before_invalid" == "$tc58_tx_count_after_invalid" && "$tc58_backup_count_before_invalid" == "$tc58_backup_count_after_invalid" ]]; then pass "invalid health-fault value is rejected before mutation"; else fail "invalid health-fault value was not strictly rejected"; fi

# Existing --recover preserves a completed-but-unhealthy apply and directs its
# exact rollback. A deliberately invalid newer backup must not be selected.
cp "$tc58_state" "$tc58_state.before-recover"
tc58_unrelated="$tc58_home/.local/state/artix-hypr-remix/framework-backups/unrelated-newer"
cp -a "$tc58_backup" "$tc58_unrelated"
sed -i 's/^backup_id=.*/backup_id=unrelated-newer/; s/^transaction_id=.*/transaction_id=tx-unrelated-newer/' "$tc58_unrelated/manifest.txt"
rm -rf "$tc58_unrelated/docs"
tc58_recover_exit=0
tc58_recover_output="$(AHR_TEST_FAIL_HEALTH_CHECK= run_ahr "$tc58_home" "$UPDATE_FRAMEWORK" --recover 2>&1)" || tc58_recover_exit=$?
if (( tc58_recover_exit != 0 )) && grep -q 'Recovery does not erase this failure. Run: ahr update-framework --rollback' <<<"$tc58_recover_output" && cmp -s "$tc58_state.before-recover" "$tc58_state"; then pass "existing recovery path preserves and directs injected health failure"; else fail "recovery path did not preserve injected health failure"; fi
tc58_rollback_exit=0
AHR_TEST_FAIL_HEALTH_CHECK= run_ahr "$tc58_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc58_rollback_exit=$?
if (( tc58_rollback_exit == 0 )) && [[ "$(json_get "$tc58_home/.config/artix-hypr-remix/framework.json" version)" == "0.1.0" ]]; then pass "exact recorded backup resolves injected health failure over unrelated backup"; else fail "rollback did not use the injected transaction's exact backup"; fi
tc58_followup_exit=0
AHR_TEST_FAIL_HEALTH_CHECK= run_ahr "$tc58_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc58_followup_exit=$?
(( tc58_followup_exit == 0 )) && pass "later unset invocation does not inherit health fault" || fail "later unset invocation inherited health fault"

echo ""
echo "=== TC59: Controlled post-activation migration fault ==="

tc59_normal_home="$tmp_root/tc59_normal"
tc59_normal_repo="$(create_test_repo "$tmp_root/tc59_normal_repo" "0.2.0")"
setup_installed_framework "$tc59_normal_home" "file://$tc59_normal_repo"
tc59_normal_exit=0
AHR_TEST_FAIL_MIGRATION= run_ahr "$tc59_normal_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc59_normal_exit=$?
(( tc59_normal_exit == 0 )) && pass "unset migration fault leaves successful apply unchanged" || fail "unset migration fault changed normal apply behavior"

tc59_home="$tmp_root/tc59"
tc59_repo="$(create_test_repo "$tmp_root/tc59_repo" "0.2.0")"
setup_installed_framework "$tc59_home" "file://$tc59_repo"
tc59_staged="$tc59_repo/artix-hypr-remix/config/artix-hypr-remix"

# Use the real migration runner with its sole staged migration already marked
# applied. This proves the runner reaches its normal no-op result before the
# process-local updater fault is injected.
cp "$FRAMEWORK_BIN/migrate.sh" "$tc59_staged/bin/migrate.sh"
cat > "$tc59_staged/migrations/20260819-already-applied.sh" <<'EOF'
#!/usr/bin/env bash
touch "${AHR_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}/unexpected-migration-script-ran"
EOF
cat > "$tc59_staged/bin/namespace-install.sh" <<'EOF'
#!/usr/bin/env bash
touch "$HOME/namespace-before-migration.marker"
EOF
chmod +x "$tc59_staged/bin/migrate.sh" "$tc59_staged/migrations/20260819-already-applied.sh" "$tc59_staged/bin/namespace-install.sh"
mkdir -p "$tc59_home/.local/state/artix-hypr-remix/migrations/skipped"
touch "$tc59_home/.local/state/artix-hypr-remix/migrations/20260819-already-applied.sh"
(cd "$tc59_repo" && git add -A && git commit -q -m "already-applied migration fixture" >/dev/null)

tc59_marker_before="$(find "$tc59_home/.local/state/artix-hypr-remix/migrations" -type f -name '*.sh' -print0 | sort -z | xargs -0 -r sha256sum)"
tc59_skipped_before="$(find "$tc59_home/.local/state/artix-hypr-remix/migrations/skipped" -type f -name '*.sh' -print0 | sort -z | xargs -0 -r sha256sum)"
tc59_staged_migration_sum="$(sha256sum "$tc59_staged/migrations/20260819-already-applied.sh" | awk '{print $1}')"
tc59_apply_exit=0
tc59_apply_output="$(AHR_TEST_FAIL_MIGRATION=1 run_ahr "$tc59_home" "$UPDATE_FRAMEWORK" --apply 2>&1)" || tc59_apply_exit=$?
(( tc59_apply_exit != 0 )) && pass "enabled migration fault exits nonzero" || fail "enabled migration fault exited zero"
grep -q 'Migration status: total=1 applied=1 skipped=0 pending=0' <<<"$tc59_apply_output" && grep -q 'No pending migrations' <<<"$tc59_apply_output" && pass "already-applied migration runner completes no-op before fault" || fail "migration no-op was not observed before fault"
grep -q 'TEST FAULT: forcing migration failure' <<<"$tc59_apply_output" && pass "injected migration fault is clearly logged" || fail "injected migration-fault log missing"
grep -q 'Runtime smoke test passed.' <<<"$tc59_apply_output" && [[ -f "$tc59_home/namespace-before-migration.marker" ]] && pass "activation namespace and runtime smoke complete before migration fault" || fail "pre-migration lifecycle did not complete"
[[ ! -e "$tc59_home/.config/artix-hypr-remix/unexpected-migration-script-ran" ]] && pass "already-applied migration script was not rerun" || fail "already-applied migration script ran"

tc59_state="$(find "$tc59_home/.local/state/artix-hypr-remix/framework-transactions" -name state -type f -print -quit)"
tc59_txdir="$(dirname "$tc59_state")"
tc59_backup="$(awk -F= '$1 == "backup_path" { print substr($0, 13); exit }' "$tc59_state")"
tc59_manifest="$tc59_backup/manifest.txt"
grep -q '^phase=migration_failed$' "$tc59_state" && grep -q '^completion=migration_failed$' "$tc59_state" && pass "injected migration uses migration_failed state" || fail "injected migration state was not migration_failed"
grep -q '^failure_reason=test_fault_forced_migration_failure$' "$tc59_state" && pass "injected migration reason is distinguishable" || fail "injected migration reason was not distinguishable"
! grep -q '^completion=committed$' "$tc59_state" && pass "injected migration transaction is not committed" || fail "injected migration transaction was committed"
tc59_txid="$(awk -F= '$1 == "transaction_id" { print substr($0, 16); exit }' "$tc59_state")"
tc59_bid="$(awk -F= '$1 == "backup_id" { print substr($0, 11); exit }' "$tc59_state")"
tc59_mtxid="$(awk -F= '$1 == "transaction_id" { print substr($0, 16); exit }' "$tc59_manifest")"
tc59_mbid="$(awk -F= '$1 == "backup_id" { print substr($0, 11); exit }' "$tc59_manifest")"
if [[ "$tc59_txid" == "$(basename "$tc59_txdir")" && "$tc59_bid" == "$(basename "$tc59_backup")" && "$tc59_txid" == "$tc59_mtxid" && "$tc59_bid" == "$tc59_mbid" ]]; then pass "migration fault preserves exact transaction and backup provenance"; else fail "migration fault changed transaction or backup provenance"; fi
tc59_marker_after="$(find "$tc59_home/.local/state/artix-hypr-remix/migrations" -type f -name '*.sh' -print0 | sort -z | xargs -0 -r sha256sum)"
tc59_skipped_after="$(find "$tc59_home/.local/state/artix-hypr-remix/migrations/skipped" -type f -name '*.sh' -print0 | sort -z | xargs -0 -r sha256sum)"
[[ "$tc59_marker_before" == "$tc59_marker_after" && "$tc59_skipped_before" == "$tc59_skipped_after" ]] && pass "injection preserves applied and skipped migration markers" || fail "injection changed migration markers"
[[ "$(sha256sum "$tc59_home/.config/artix-hypr-remix/migrations/20260819-already-applied.sh" | awk '{print $1}')" == "$tc59_staged_migration_sum" ]] && pass "hook does not modify migration scripts" || fail "hook modified migration script"

tc59_count_before_invalid="$(find "$tc59_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
tc59_invalid_exit=0
tc59_invalid_output="$(AHR_TEST_FAIL_MIGRATION=true run_ahr "$tc59_home" "$UPDATE_FRAMEWORK" --dry-run 2>&1)" || tc59_invalid_exit=$?
tc59_count_after_invalid="$(find "$tc59_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
if (( tc59_invalid_exit != 0 )) && grep -q "Invalid AHR_TEST_FAIL_MIGRATION value: expected exactly '1' when set" <<<"$tc59_invalid_output" && [[ "$tc59_count_before_invalid" == "$tc59_count_after_invalid" ]]; then pass "invalid migration-fault value is rejected before mutation"; else fail "invalid migration-fault value was not strictly rejected"; fi

cp "$tc59_state" "$tc59_state.before-recover"
tc59_unrelated="$tc59_home/.local/state/artix-hypr-remix/framework-backups/unrelated-newer"
cp -a "$tc59_backup" "$tc59_unrelated"
sed -i 's/^backup_id=.*/backup_id=unrelated-newer/; s/^transaction_id=.*/transaction_id=tx-unrelated-newer/' "$tc59_unrelated/manifest.txt"
rm -rf "$tc59_unrelated/docs"
tc59_recover_exit=0
tc59_recover_output="$(AHR_TEST_FAIL_MIGRATION= run_ahr "$tc59_home" "$UPDATE_FRAMEWORK" --recover 2>&1)" || tc59_recover_exit=$?
if (( tc59_recover_exit != 0 )) && grep -q 'Recovery does not erase this failure. Run: ahr update-framework --rollback' <<<"$tc59_recover_output" && cmp -s "$tc59_state.before-recover" "$tc59_state"; then pass "recover preserves and directs injected migration failure"; else fail "recover did not preserve migration failure"; fi
tc59_rollback_exit=0
AHR_TEST_FAIL_MIGRATION= run_ahr "$tc59_home" "$UPDATE_FRAMEWORK" --rollback >/dev/null 2>&1 || tc59_rollback_exit=$?
if (( tc59_rollback_exit == 0 )) && [[ "$(json_get "$tc59_home/.config/artix-hypr-remix/framework.json" version)" == "0.1.0" ]] && [[ "$(find "$tc59_home/.local/state/artix-hypr-remix/migrations" -type f -name '*.sh' -print0 | sort -z | xargs -0 -r sha256sum)" == "$tc59_marker_before" ]]; then pass "exact rollback restores baseline and migration markers over unrelated backup"; else fail "rollback did not restore exact migration-failure backup"; fi
tc59_followup_exit=0
AHR_TEST_FAIL_MIGRATION= run_ahr "$tc59_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc59_followup_exit=$?
(( tc59_followup_exit == 0 )) && pass "later unset invocation does not inherit migration fault" || fail "later unset invocation inherited migration fault"

# ── Results ────────────────────────────────────────────────────────
echo ""
echo "=== TC60: Controlled post-activation namespace fault ==="
tc60_normal_home="$tmp_root/tc60_normal"; tc60_normal_repo="$(create_test_repo "$tmp_root/tc60_normal_repo" "0.2.0")"; setup_installed_framework "$tc60_normal_home" "file://$tc60_normal_repo"
tc60_normal_exit=0; AHR_TEST_FAIL_NAMESPACE_INSTALL= run_ahr "$tc60_normal_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc60_normal_exit=$?
(( tc60_normal_exit == 0 )) && pass "unset namespace fault leaves successful apply unchanged" || fail "unset namespace fault changed normal apply behavior"
tc60_home="$tmp_root/tc60"; tc60_repo="$(create_test_repo "$tmp_root/tc60_repo" "0.2.0")"; setup_installed_framework "$tc60_home" "file://$tc60_repo"; tc60_staged="$tc60_repo/artix-hypr-remix/config/artix-hypr-remix"; tc60_local="$tc60_home/.local/bin"; mkdir -p "$tc60_local"
ln -s "$tc60_home/.config/artix-hypr-remix/bin/ahr" "$tc60_local/ahr"; printf 'unrelated regular data\n' >"$tc60_local/unrelated-regular"; ln -s /usr/bin/true "$tc60_local/unrelated-symlink"; cp "$FRAMEWORK_BIN/namespace-install.sh" "$tc60_staged/bin/namespace-install.real.sh"
# The fixture begins with a minimal staged tree, so supply the canonical source
# inventory required by the unmodified production namespace installer.
mapfile -t tc60_commands < <(bash -c 'source "$1"; printf "%s\n" "${AHR_NAMESPACE_COMMANDS[@]}"' _ "$FRAMEWORK_BIN/ahr-lib.sh")
for tc60_command in "${tc60_commands[@]}"; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$tc60_staged/bin/$tc60_command"
  chmod +x "$tc60_staged/bin/$tc60_command"
done
cat > "$tc60_staged/bin/namespace-install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
bash "$HOME/.config/artix-hypr-remix/bin/namespace-install.real.sh" --quiet
ln -sfn "$HOME/.config/artix-hypr-remix/bin/ahr-update" "$HOME/.local/bin/ahr"
touch "$HOME/.config/artix-hypr-remix/real-namespace-success.marker"
printf 'real namespace installer succeeded\n'
EOF
cat > "$tc60_staged/bin/migrate.sh" <<'EOF'
#!/usr/bin/env bash
touch "$HOME/.config/artix-hypr-remix/migration-after-namespace.marker"
EOF
cat > "$tc60_staged/bin/ahr-doctor" <<'EOF'
#!/usr/bin/env bash
touch "$HOME/.config/artix-hypr-remix/doctor-after-namespace.marker"
exit 0
EOF
chmod +x "$tc60_staged/bin/namespace-install.sh" "$tc60_staged/bin/namespace-install.real.sh" "$tc60_staged/bin/migrate.sh" "$tc60_staged/bin/ahr-doctor"; (cd "$tc60_repo" && git add -A && git commit -q -m "namespace fault fixture" >/dev/null)
tc60_apply_exit=0; tc60_apply_output="$(AHR_TEST_FAIL_NAMESPACE_INSTALL=1 run_ahr "$tc60_home" "$UPDATE_FRAMEWORK" --apply 2>&1)" || tc60_apply_exit=$?
(( tc60_apply_exit != 0 )) && pass "enabled namespace fault exits nonzero" || fail "enabled namespace fault exited zero"
grep -q 'real namespace installer succeeded' <<<"$tc60_apply_output" && grep -q 'TEST FAULT: forcing namespace-install failure' <<<"$tc60_apply_output" && pass "real namespace install succeeds before injected fault" || fail "namespace success or fault evidence missing" "$tc60_apply_output"
[[ -f "$tc60_home/.config/artix-hypr-remix/real-namespace-success.marker" ]] && pass "real namespace installer completed before failure" || fail "real namespace installer did not complete"
[[ "$(readlink "$tc60_local/ahr")" == "$tc60_home/.config/artix-hypr-remix/bin/ahr-update" ]] && pass "injected failure retains namespace target B" || fail "namespace target B missing"
[[ "$(cat "$tc60_local/unrelated-regular")" == "unrelated regular data" && "$(readlink "$tc60_local/unrelated-symlink")" == "/usr/bin/true" ]] && pass "unrelated namespace entries remain unchanged" || fail "unrelated namespace entry changed"
! grep -q 'Running post-activation runtime smoke test...' <<<"$tc60_apply_output" && [[ ! -e "$tc60_home/.config/artix-hypr-remix/migration-after-namespace.marker" && ! -e "$tc60_home/.config/artix-hypr-remix/doctor-after-namespace.marker" ]] && pass "runtime smoke migrations and doctor do not run after namespace fault" || fail "namespace fault reached a successor phase"
tc60_state="$(find "$tc60_home/.local/state/artix-hypr-remix/framework-transactions" -name state -type f -print -quit)"; tc60_txdir="$(dirname "$tc60_state")"; tc60_backup="$(awk -F= '$1 == "backup_path" { print substr($0, 13); exit }' "$tc60_state")"; tc60_manifest="$tc60_backup/manifest.txt"
[[ -d "$tc60_backup" && -f "$tc60_manifest" ]] && pass "backup exists before injected namespace failure" || fail "namespace fault backup missing"
grep -q '^phase=namespace_failed$' "$tc60_state" && grep -q '^completion=namespace_failed$' "$tc60_state" && pass "injected namespace uses namespace_failed state" || fail "namespace fault state was not namespace_failed"
grep -q '^failure_reason=test_fault_forced_namespace_install_failure$' "$tc60_state" && pass "namespace fault reason is distinguishable" || fail "namespace fault reason missing"
! grep -q '^completion=committed$' "$tc60_state" && pass "injected namespace transaction is not committed" || fail "namespace transaction was committed"
tc60_txid="$(awk -F= '$1 == "transaction_id" { print substr($0, 16); exit }' "$tc60_state")"; tc60_bid="$(awk -F= '$1 == "backup_id" { print substr($0, 11); exit }' "$tc60_state")"; tc60_mtxid="$(awk -F= '$1 == "transaction_id" { print substr($0, 16); exit }' "$tc60_manifest")"; tc60_mbid="$(awk -F= '$1 == "backup_id" { print substr($0, 11); exit }' "$tc60_manifest")"
[[ "$tc60_txid" == "$(basename "$tc60_txdir")" && "$tc60_bid" == "$(basename "$tc60_backup")" && "$tc60_txid" == "$tc60_mtxid" && "$tc60_bid" == "$tc60_mbid" ]] && pass "namespace fault preserves exact transaction and backup provenance" || fail "namespace fault provenance changed"
[[ "$(json_get "$tc60_home/.config/artix-hypr-remix/framework.json" version)" == "0.2.0" ]] && pass "activation completed before namespace fault" || fail "activation did not complete"
tc60_tx_before_invalid="$(find "$tc60_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d | wc -l)"; tc60_invalid_exit=0; tc60_invalid_output="$(AHR_TEST_FAIL_NAMESPACE_INSTALL=true run_ahr "$tc60_home" "$UPDATE_FRAMEWORK" --dry-run 2>&1)" || tc60_invalid_exit=$?; tc60_tx_after_invalid="$(find "$tc60_home/.local/state/artix-hypr-remix/framework-transactions" -mindepth 1 -maxdepth 1 -type d | wc -l)"
if (( tc60_invalid_exit != 0 )) && grep -q "Invalid AHR_TEST_FAIL_NAMESPACE_INSTALL value: expected exactly '1' when set" <<<"$tc60_invalid_output" && [[ "$tc60_tx_before_invalid" == "$tc60_tx_after_invalid" ]]; then pass "invalid namespace-fault value is rejected before mutation"; else fail "invalid namespace-fault value was not strictly rejected"; fi
cp "$tc60_state" "$tc60_state.before-recover"; tc60_unrelated="$tc60_home/.local/state/artix-hypr-remix/framework-backups/unrelated-newer"; cp -a "$tc60_backup" "$tc60_unrelated"; sed -i 's/^backup_id=.*/backup_id=unrelated-newer/; s/^transaction_id=.*/transaction_id=tx-unrelated-newer/' "$tc60_unrelated/manifest.txt"; rm -rf "$tc60_unrelated/docs"
tc60_recover_exit=0; tc60_recover_output="$(AHR_TEST_FAIL_NAMESPACE_INSTALL= run_ahr "$tc60_home" "$UPDATE_FRAMEWORK" --recover 2>&1)" || tc60_recover_exit=$?
if (( tc60_recover_exit != 0 )) && grep -q 'Recovery does not erase this failure. Run: ahr update-framework --rollback' <<<"$tc60_recover_output" && cmp -s "$tc60_state.before-recover" "$tc60_state" && [[ "$(readlink "$tc60_local/ahr")" == "$tc60_home/.config/artix-hypr-remix/bin/ahr-update" ]]; then pass "recover preserves and directs injected namespace failure"; else fail "recover did not preserve namespace failure" "$tc60_recover_output"; fi
tc60_rollback_exit=0; tc60_rollback_output="$(AHR_TEST_FAIL_NAMESPACE_INSTALL= run_ahr "$tc60_home" "$UPDATE_FRAMEWORK" --rollback 2>&1)" || tc60_rollback_exit=$?
if (( tc60_rollback_exit == 0 )) && [[ "$(json_get "$tc60_home/.config/artix-hypr-remix/framework.json" version)" == "0.1.0" ]] && [[ "$(readlink "$tc60_local/ahr")" == "$tc60_home/.config/artix-hypr-remix/bin/ahr" ]] && [[ "$(cat "$tc60_local/unrelated-regular")" == "unrelated regular data" && "$(readlink "$tc60_local/unrelated-symlink")" == "/usr/bin/true" ]]; then pass "exact rollback restores namespace target A over unrelated backup"; else fail "rollback did not restore exact namespace baseline" "$tc60_rollback_output"; fi
grep -q '^phase=resolved_by_rollback$' "$tc60_state" && grep -q '^completion=resolved_by_rollback$' "$tc60_state" && grep -q "^transaction_id=$tc60_txid$" "$tc60_state" && grep -q "^backup_id=$tc60_bid$" "$tc60_state" && pass "namespace failure resolves with immutable provenance" || fail "namespace terminal provenance was not preserved"
tc60_followup_exit=0; AHR_TEST_FAIL_NAMESPACE_INSTALL= run_ahr "$tc60_home" "$UPDATE_FRAMEWORK" --apply >/dev/null 2>&1 || tc60_followup_exit=$?
(( tc60_followup_exit == 0 )) && pass "later unset invocation does not inherit namespace fault" || fail "later unset invocation inherited namespace fault"

echo ""
echo "========================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
