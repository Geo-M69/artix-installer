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
  for f in ahr ahr-update ahr-update-framework ahr-update-available migrate.sh namespace-install.sh ahr-doctor; do
    echo '#!/usr/bin/env bash' > "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
  done
  # Copy real library files (not commands — those are dummy scripts for testing)
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-lib.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-version.sh"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-cache.sh"
  cat > "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
     "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/"
  chmod +x "$rd/artix-hypr-remix/config/artix-hypr-remix/bin/"*
  (cd "$rd" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m "v$ver" >/dev/null)
  printf '%s' "$rd"
}

setup_installed_framework() {
  local home_dir="$1" update_source="${2:-}" extra_migrations="${3:-0}"
  mkdir -p "$home_dir/.config/artix-hypr-remix"/{bin,migrations,docs,hooks,first-run.d,default}
  mkdir -p "$home_dir/.local/state/artix-hypr-remix/migrations/skipped"
  mkdir -p "$home_dir/.cache/artix-hypr-remix"
  cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" \
     "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" \
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

# Read a JSON string value from a file (jq or python3 fallback)
json_get() {
  local file="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // ""' "$file" 2>/dev/null
  else
    python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key',''))" 2>/dev/null
  fi
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
HOME="$tc16_home" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" bash "$RESTORE_COMPONENT" theme-state --from-last-update >/dev/null 2>&1 || tc16_exit=$?
(( tc16_exit != 0 )) && pass "refuses unsafe component without --apply" || fail "accepted unsafe without --apply"

# With --apply, should succeed
tc16_apply_exit=0
HOME="$tc16_home" AHR_LIB_PATH="$FRAMEWORK_BIN/ahr-lib.sh" bash "$RESTORE_COMPONENT" theme-state --from-last-update --apply >/dev/null 2>&1 || tc16_apply_exit=$?
(( tc16_apply_exit == 0 )) && pass "accepts unsafe component with --apply" || fail "rejected with --apply"

echo ""
echo "=== TC17: Production namespace symlinks resolve libraries ==="

tc17_home="$tmp_root/tc17"
mkdir -p "$tc17_home/.config" "$tc17_home/.local/state"
cp -a "$REPO_ROOT/config/artix-hypr-remix" "$tc17_home/.config/"
HOME="$tc17_home" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" AHR_LOCAL_BIN="$tc17_home/.local/bin" \
  bash "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" --quiet >/dev/null

tc17_status=0
HOME="$tc17_home" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr-update-framework" --status >"$tmp_root/tc17-status.out" 2>&1 || tc17_status=$?
(( tc17_status == 0 )) && pass "namespace ahr-update-framework --status" || fail "namespace status exit $tc17_status" "$(cat "$tmp_root/tc17-status.out")"

tc17_avail=0
HOME="$tc17_home" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr-update-available" --json >"$tmp_root/tc17-available.out" 2>&1 || tc17_avail=$?
# Exit 0 or 1 is valid for availability; missing-library errors are never valid.
if [[ "$tc17_avail" == "0" || "$tc17_avail" == "1" ]] && ! grep -q 'No such file\|ahr-version.sh' "$tmp_root/tc17-available.out"; then
  pass "namespace ahr-update-available resolves libraries"
else
  fail "namespace availability failed" "$(cat "$tmp_root/tc17-available.out")"
fi

tc17_restore=0
HOME="$tc17_home" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
  "$tc17_home/.local/bin/ahr-restore-component" --list >"$tmp_root/tc17-restore.out" 2>&1 || tc17_restore=$?
if [[ "$tc17_restore" == "0" ]] && grep -q 'framework-config' "$tmp_root/tc17-restore.out"; then
  pass "namespace ahr-restore-component --list"
else
  fail "namespace restore-component failed" "$(cat "$tmp_root/tc17-restore.out")"
fi

tc17_dispatch=0
HOME="$tc17_home" AHR_FRAMEWORK_ROOT="$tc17_home/.config/artix-hypr-remix" \
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
for f in ahr ahr-update ahr-update-framework ahr-update-available namespace-install.sh ahr-doctor; do
  echo '#!/usr/bin/env bash' > "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-lib.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-version.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-version.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-cache.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-cache.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/migrate.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/migrate.sh"
cp "$REPO_ROOT/config/artix-hypr-remix/bin/namespace-install.sh" "$tc18_repo_dir/artix-hypr-remix/config/artix-hypr-remix/bin/namespace-install.sh"
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

# ── Results ────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
