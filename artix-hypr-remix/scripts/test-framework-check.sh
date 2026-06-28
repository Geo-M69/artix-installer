#!/usr/bin/env bash
# Offline test for Phase 1 framework version checking.
#
# Creates a temporary local Git repository, sets up framework.json files
# at various versions, and runs ahr-update-framework --check and
# ahr-update-available --json against each scenario.
#
# Usage:
#   bash scripts/test-framework-check.sh
#
# Exit status: 0 if all tests pass, 1 otherwise.

set -Eeuo pipefail
# Avoid set -u errors from unset prompt hooks in non-interactive shells.
set +u 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_BIN="$REPO_ROOT/config/artix-hypr-remix/bin"
UPDATE_FRAMEWORK="$FRAMEWORK_BIN/ahr-update-framework"
UPDATE_AVAILABLE="$FRAMEWORK_BIN/ahr-update-available"

PASS=0
FAIL=0

# ── vercmp stub ────────────────────────────────────────────────────
# Real pacman vercmp prints negative/zero/positive to stdout and exits 0.
# This stub implements the same interface for the version strings used
# in this test suite.  It is injected into PATH during each test case.
VERCMP_STUB_DIR=""

create_vercmp_stub() {
  VERCMP_STUB_DIR="$(mktemp -d "/tmp/ahr-vercmp-stub-XXXXXXXX")"
  cat > "$VERCMP_STUB_DIR/vercmp" <<'VERCMP'
#!/usr/bin/env python3
"""Minimal vercmp stub matching pacman vercmp output convention."""
import sys, re

def parse(v):
    """Return (epoch, [version_parts], pre_release) suitable for comparison."""
    # Strip epoch if present
    epoch = 0
    if ':' in v:
        epoch, v = v.split(':', 1)
        epoch = int(epoch)
    # Split on '-' — everything after is pkgrel/pre-release
    parts = v.split('-', 1)
    ver_str = parts[0]
    pre = parts[1] if len(parts) > 1 else ''
    # Parse version into list of ints
    ver_parts = [int(x) for x in ver_str.split('.')] if ver_str else []
    return (epoch, ver_parts, pre)

a = parse(sys.argv[1])
b = parse(sys.argv[2])

# Compare epoch
if a[0] != b[0]:
    print(-1 if a[0] < b[0] else 1)
    sys.exit(0)

# Compare version number lists
va, vb = a[1], b[1]
# Pad to same length
max_len = max(len(va), len(vb))
va += [0] * (max_len - len(va))
vb += [0] * (max_len - len(vb))

for pa, pb in zip(va, vb):
    if pa != pb:
        print(-1 if pa < pb else 1)
        sys.exit(0)

# Version numbers equal — compare pkgrel (the part after '-').
# Pacman convention: if only one side has a pkgrel, they are equal.
# If both have pkgrel, compare them using rpmvercmp rules.
pre_a, pre_b = a[2], b[2]
if pre_a == pre_b:
    result = 0
elif not pre_a or not pre_b:
    # Only one side has pkgrel — they compare equal.
    result = 0
else:
    # Both have pkgrel — split into runs and compare.
    import re
    def relcmp(x, y):
        parts_x = re.findall(r'(\d+|[a-zA-Z]+)', x)
        parts_y = re.findall(r'(\d+|[a-zA-Z]+)', y)
        for i in range(max(len(parts_x), len(parts_y))):
            px = parts_x[i] if i < len(parts_x) else ''
            py = parts_y[i] if i < len(parts_y) else ''
            if px == py:
                continue
            # Numeric > alpha in rpmvercmp
            if px.isdigit() and not py.isdigit():
                return 1
            if not px.isdigit() and py.isdigit():
                return -1
            if px.isdigit() and py.isdigit():
                n, m = int(px), int(py)
                if n != m:
                    return -1 if n < m else 1
            return -1 if px < py else 1
        return 0
    result = relcmp(pre_a, pre_b)
print(result)
sys.exit(0)
VERCMP
  chmod +x "$VERCMP_STUB_DIR/vercmp"
}

destroy_vercmp_stub() {
  rm -rf "${VERCMP_STUB_DIR:-/tmp/nonexistent}"
}

# Inject stub into PATH during test setup
inject_vercmp_stub() {
  export PATH="$VERCMP_STUB_DIR:$PATH"
}

restore_path() {
  export PATH="${PATH#$VERCMP_STUB_DIR:}"
}

# Push a directory onto PATH for a scoped test, pop it afterward.
push_path() { export PATH="$1:$PATH"; }
pop_path()  { local d="$1"; export PATH="${PATH#$d:}"; }

# Create a git wrapper that fails when --filter is passed (simulating
# an older git that doesn't support blobless clone), but passes other
# invocations through to the real git.
GIT_STUB_DIR=""
create_git_stub() {
  GIT_STUB_DIR="$(mktemp -d "/tmp/ahr-git-stub-XXXXXXXX")"
  local real_git
  real_git="$(command -v git)"
  cat > "$GIT_STUB_DIR/git" <<GITSTUB
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ "\$arg" == "--filter"* ]]; then
    exit 1
  fi
done
exec $real_git "\$@"
GITSTUB
  chmod +x "$GIT_STUB_DIR/git"
}

destroy_git_stub() {
  rm -rf "${GIT_STUB_DIR:-/tmp/nonexistent}"
}

setup_temp_home() {
  mktemp -d "/tmp/ahr-test-XXXXXXXX"
}

cleanup() {
  local dir="$1"
  rm -rf "$dir"
}

# Create a local git repository with a framework.json at the given version.
# Arguments:
#   $1 - parent directory for the repo
#   $2 - repo directory name
#   $3 - version string (e.g. "0.1.0")
#   $4 - channel (default: stable)
#   $5 - whether to include framework.json (true/false, default: true)
create_framework_repo() {
  local parent="$1"
  local name="$2"
  local version="$3"
  local channel="${4:-stable}"
  local include_json="${5:-true}"
  local repo_dir="$parent/$name"

  mkdir -p "$repo_dir/artix-hypr-remix/config/artix-hypr-remix"
  if [[ "$include_json" == "true" ]]; then
    cat > "$repo_dir/artix-hypr-remix/config/artix-hypr-remix/framework.json" <<EOF
{
  "version": "$version",
  "revision": null,
  "channel": "$channel",
  "update_source": "file://$repo_dir",
  "updated_at": null
}
EOF
  fi

  # Make a dummy file so git has something to commit even without framework.json
  touch "$repo_dir/artix-hypr-remix/.gitkeep"

  cd "$repo_dir"
  git init --quiet
  git config user.email "test@ahr.local"
  git config user.name "AHR Test"
  git add -A
  git commit -m "test: framework v$version" --quiet
  cd "$OLDPWD"

  printf '%s' "$repo_dir"
}

# Run a single test case.
# Arguments:
#   $1 - test label
#   $2 - expected result from ahr-update-framework --check (exit code 0=update, 1=no update)
#   $3 - expected framework field in ahr-update-available --json
#   $4 - local version for the installed framework.json
#   $5 - remote version for the git repo framework.json (or "missing" to omit it)
#   $6 - remote channel (optional, default: stable)
run_test() {
  local label="$1"
  local expected_check_exit="$2"
  local expected_avail_framework="$3"
  local local_version="$4"
  local remote_version="$5"
  local remote_channel="${6:-stable}"

  local test_home
  test_home="$(setup_temp_home)"
  local repo_dir=""

  printf '\n---[ %s ]---\n' "$label"

  # Create installed framework.json
  mkdir -p "$test_home/.config/artix-hypr-remix"
  cat > "$test_home/.config/artix-hypr-remix/framework.json" <<EOF
{
  "version": "$local_version",
  "revision": null,
  "channel": "stable",
  "update_source": "",
  "updated_at": "2026-06-28T00:00:00Z"
}
EOF

  if [[ "$remote_version" == "missing" ]]; then
    # Create repo without framework.json
    repo_dir="$(create_framework_repo "$test_home" "remote-repo" "0.0.0" "$remote_channel" false)"
  else
    repo_dir="$(create_framework_repo "$test_home" "remote-repo" "$remote_version" "$remote_channel")"
  fi

  # Update installed framework.json to point at the test repo
  cat > "$test_home/.config/artix-hypr-remix/framework.json" <<EOF
{
  "version": "$local_version",
  "revision": null,
  "channel": "stable",
  "update_source": "file://$repo_dir",
  "updated_at": "2026-06-28T00:00:00Z"
}
EOF

  export HOME="$test_home"
  export XDG_STATE_HOME="$test_home/.local/state"
  export AHR_LIB_PATH="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh"
  inject_vercmp_stub

  # Clear cache
  rm -f "$test_home/.local/state/artix-hypr-remix/framework-remote.cache" 2>/dev/null || true

  # Test 1: ahr-update-framework --check
  local check_exit=0
  local check_output=""
  check_output="$(bash "$UPDATE_FRAMEWORK" --check 2>&1)" || check_exit=$?

  if (( check_exit == expected_check_exit )); then
    printf '  CHECK: exit %d (expected %d) — PASS\n' "$check_exit" "$expected_check_exit"
    ((PASS+=1))
  else
    printf '  CHECK: exit %d (expected %d) — FAIL\n' "$check_exit" "$expected_check_exit"
    printf '    Output: %s\n' "$check_output"
    ((FAIL+=1))
  fi

  # Test 2: ahr-update-available --json
  local avail_json=""
  local avail_framework=""
  avail_json="$(bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"

  if command -v jq >/dev/null 2>&1; then
    avail_framework="$(printf '%s' "$avail_json" | jq -r '.framework' 2>/dev/null || echo 'parse-error')"
  else
    avail_framework="$(printf '%s' "$avail_json" | sed -n 's/.*"framework"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' | head -n1)"
  fi

  if [[ "$avail_framework" == "$expected_avail_framework" ]]; then
    printf '  AVAIL: framework=%s (expected %s) — PASS\n' "$avail_framework" "$expected_avail_framework"
    ((PASS+=1))
  else
    printf '  AVAIL: framework=%s (expected %s) — FAIL\n' "$avail_framework" "$expected_avail_framework"
    printf '    JSON: %s\n' "$avail_json"
    ((FAIL+=1))
  fi

  # Cleanup
  restore_path
  cleanup "$test_home"
  unset HOME XDG_STATE_HOME AHR_LIB_PATH
  cd "$REPO_ROOT"
}

# ── Test Suite ─────────────────────────────────────────────────────

printf '========================================\n'
printf '  Framework Check — Offline Test Suite\n'
printf '========================================\n'
printf 'Using framework bin: %s\n' "$FRAMEWORK_BIN"

# Prerequisites
if [[ ! -x "$UPDATE_FRAMEWORK" ]]; then
  printf 'FATAL: %s not found or not executable\n' "$UPDATE_FRAMEWORK" >&2
  exit 1
fi
if [[ ! -x "$UPDATE_AVAILABLE" ]]; then
  printf 'FATAL: %s not found or not executable\n' "$UPDATE_AVAILABLE" >&2
  exit 1
fi

# Create vercmp stub and inject into PATH for all test cases.
# This ensures real vercmp behaviour is exercised regardless of host.
create_vercmp_stub

# ── TC1: Same version → up to date ─────────────────────────────────
run_test \
  "Same version (0.1.0 = 0.1.0)" \
  1 \
  "current" \
  "0.1.0" \
  "0.1.0"

# ── TC2: Remote newer → update pending ────────────────────────────
run_test \
  "Remote newer (0.1.0 → 0.2.0)" \
  0 \
  "pending" \
  "0.1.0" \
  "0.2.0"

# ── TC3: Remote older → no downgrade ──────────────────────────────
run_test \
  "Remote older (0.2.0 → 0.1.0, no downgrade)" \
  1 \
  "current" \
  "0.2.0" \
  "0.1.0"

# ── TC4: Missing remote metadata → unavailable ────────────────────
run_test \
  "Missing remote framework.json" \
  1 \
  "unavailable" \
  "0.1.0" \
  "missing"

# ── TC5: Pre-release version ordering ─────────────────────────────
# Uses a version delta that both vercmp and string fallback agree on.
run_test \
  "Pre-release remote (0.1.0 → 0.2.0-rc1)" \
  0 \
  "pending" \
  "0.1.0" \
  "0.2.0-rc1"

# ── TC6: Complex version bump ──────────────────────────────────────
run_test \
  "Major bump (0.9.9 → 1.0.0)" \
  0 \
  "pending" \
  "0.9.9" \
  "1.0.0"

# ── TC7: Numeric segment ordering ────────────────────────────────
# vercmp compares 0.1.10 > 0.1.9 (numeric), while string comparison
# would say "0.1.10" < "0.1.9" (lexicographic). This exercises the
# vercmp path specifically.
run_test \
  "Numeric ordering (0.1.9 → 0.1.10, needs vercmp)" \
  0 \
  "pending" \
  "0.1.9" \
  "0.1.10"

# ── TC8: Failing clone → unavailable ────────────────────────────
printf '\n---[ Failing clone returns unavailable ]---\n'

tc8_home="$(setup_temp_home)"
mkdir -p "$tc8_home/.config/artix-hypr-remix"
cat > "$tc8_home/.config/artix-hypr-remix/framework.json" <<EOF
{
  "version": "0.1.0",
  "revision": null,
  "channel": "stable",
  "update_source": "file:///nonexistent-ahr-test-repo-$(date +%s)",
  "updated_at": "2026-06-28T00:00:00Z"
}
EOF

export HOME="$tc8_home"
export XDG_STATE_HOME="$tc8_home/.local/state"
export AHR_LIB_PATH="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh"
inject_vercmp_stub

rm -f "$tc8_home/.local/state/artix-hypr-remix/framework-remote.cache" 2>/dev/null || true

# Test CHECK: should fail (exit 1) because clone fails
tc8_check_exit=0
tc8_check_output="$(bash "$UPDATE_FRAMEWORK" --check 2>&1)" || tc8_check_exit=$?
if (( tc8_check_exit == 1 )); then
  printf '  CHECK: exit 1 (expected 1) — PASS\n'
  ((PASS+=1))
else
  printf '  CHECK: exit %d (expected 1) — FAIL\n' "$tc8_check_exit"
  printf '    Output: %s\n' "$tc8_check_output"
  ((FAIL+=1))
fi

# Test AVAIL: should show framework=unavailable
tc8_avail_json="$(bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"
tc8_avail_framework=""
if command -v jq >/dev/null 2>&1; then
  tc8_avail_framework="$(printf '%s' "$tc8_avail_json" | jq -r '.framework' 2>/dev/null || echo 'parse-error')"
else
  tc8_avail_framework="$(printf '%s' "$tc8_avail_json" | sed -n 's/.*"framework"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' | head -n1)"
fi

if [[ "$tc8_avail_framework" == "unavailable" ]]; then
  printf '  AVAIL: framework=unavailable (expected unavailable) — PASS\n'
  ((PASS+=1))
else
  printf '  AVAIL: framework=%s (expected unavailable) — FAIL\n' "$tc8_avail_framework"
  printf '    JSON: %s\n' "$tc8_avail_json"
  ((FAIL+=1))
fi

restore_path
cleanup "$tc8_home"
unset HOME XDG_STATE_HOME AHR_LIB_PATH
cd "$REPO_ROOT"

# ── TC9: Blobless fails, shallow fallback succeeds ────────────────
printf '\n---[ Blobless clone fails, shallow fallback succeeds ]---\n'

tc9_home="$(setup_temp_home)"

# Create a valid repo
tc9_repo_dir="$(create_framework_repo "$tc9_home" "tc9-repo" "0.2.0")"

mkdir -p "$tc9_home/.config/artix-hypr-remix"
cat > "$tc9_home/.config/artix-hypr-remix/framework.json" <<EOF
{
  "version": "0.1.0",
  "revision": null,
  "channel": "stable",
  "update_source": "file://$tc9_repo_dir",
  "updated_at": "2026-06-28T00:00:00Z"
}
EOF

export HOME="$tc9_home"
export XDG_STATE_HOME="$tc9_home/.local/state"
export AHR_LIB_PATH="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-lib.sh"
inject_vercmp_stub

# Create git stub that rejects --filter and inject into PATH
create_git_stub
push_path "$GIT_STUB_DIR"

rm -f "$tc9_home/.local/state/artix-hypr-remix/framework-remote.cache" 2>/dev/null || true

# Test CHECK: should succeed (exit 0) because shallow fallback works
tc9_check_exit=0
tc9_check_output="$(bash "$UPDATE_FRAMEWORK" --check 2>&1)" || tc9_check_exit=$?
if (( tc9_check_exit == 0 )); then
  printf '  CHECK: exit 0 (expected 0) — PASS\n'
  ((PASS+=1))
else
  printf '  CHECK: exit %d (expected 0) — FAIL\n' "$tc9_check_exit"
  printf '    Output: %s\n' "$tc9_check_output"
  ((FAIL+=1))
fi

# Clear cache so AVAIL exercises its own clone logic, not the cached result
# from the CHECK command above.
rm -f "$tc9_home/.local/state/artix-hypr-remix/framework-remote.cache" 2>/dev/null || true

# Test AVAIL: should show framework=pending
tc9_avail_json="$(bash "$UPDATE_AVAILABLE" --json 2>&1 || true)"
tc9_avail_framework=""
if command -v jq >/dev/null 2>&1; then
  tc9_avail_framework="$(printf '%s' "$tc9_avail_json" | jq -r '.framework' 2>/dev/null || echo 'parse-error')"
else
  tc9_avail_framework="$(printf '%s' "$tc9_avail_json" | sed -n 's/.*"framework"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' | head -n1)"
fi

if [[ "$tc9_avail_framework" == "pending" ]]; then
  printf '  AVAIL: framework=pending (expected pending) — PASS\n'
  ((PASS+=1))
else
  printf '  AVAIL: framework=%s (expected pending) — FAIL\n' "$tc9_avail_framework"
  printf '    JSON: %s\n' "$tc9_avail_json"
  ((FAIL+=1))
fi

pop_path "$GIT_STUB_DIR"
destroy_git_stub
restore_path
cleanup "$tc9_home"
unset HOME XDG_STATE_HOME AHR_LIB_PATH
cd "$REPO_ROOT"

# Clean up vercmp stub
destroy_vercmp_stub

# ── Results ────────────────────────────────────────────────────────
printf '\n========================================\n'
printf '  Results: %d passed, %d failed\n' "$PASS" "$FAIL"
printf '========================================\n'

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
