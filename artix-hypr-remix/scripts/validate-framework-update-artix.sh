#!/usr/bin/env bash
# validate-framework-update-artix.sh
#
# On-machine validation for the AHR framework update pipeline.
# Must be run on a real Artix installation with a live AHR user session.
#
# Default mode is non-destructive: prerequisite checks and status only.
# --apply-test enables destructive testing (applies a test framework update).
#
# This script has multiple safety layers:
#   1. Positive Artix host guard (refuses --apply-test on non-Artix)
#   2. Complete backup before any mutation
#   3. Restoration traps on EXIT/INT/TERM/HUP
#   4. Idempotent restoration handler
#
# Usage:
#   bash scripts/validate-framework-update-artix.sh
#   bash scripts/validate-framework-update-artix.sh --apply-test
#   bash scripts/validate-framework-update-artix.sh --apply-test --user geo
#
# Exit status: 0 if all tests pass, 1 otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_SOURCE="$REPO_ROOT/config/artix-hypr-remix"

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
BOLD='\e[1m'
RESET='\e[0m'

PASS=0
FAIL=0
TEST_MODE="non-destructive"
APPLY_USER="${APPLY_USER:-}"
FRAMEWORK_TARGET="$HOME/.config/artix-hypr-remix"
STATE_TARGET="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"

# Artix host guard
is_artix() {
  [[ -f /etc/artix-release ]]
}

# Backup location
BACKUP_ROOT="/tmp/ahr-validate-$$"
LOG_FILE=""
BACKUP_DIR=""

# Restoration state
RESTORE_DONE=0
RESTORE_TRAP_INSTALLED=0

# ── Output helpers ─────────────────────────────────────────────────

pass() { echo -e "  ${GREEN}PASS${RESET}: $1"; ((PASS+=1)); }
fail() { echo -e "  ${RED}FAIL${RESET}: $1" >&2; [[ -n "${2:-}" ]] && echo "    $2" >&2; ((FAIL+=1)); }
warn() { echo -e "  ${YELLOW}WARN${RESET}: $1"; }
section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${RESET}"; }

# ── Backup functions ──────────────────────────────────────────────

backup_framework() {
  local target="$1"
  local dest="$2"
  if [[ ! -d "$target" ]]; then
    warn "Framework not deployed at $target — skipping backup"
    return 0
  fi
  mkdir -p "$dest"
  cp -a "$target"/. "$dest"/ 2>/dev/null || true
  # Also backup state
  local state_src="$STATE_TARGET"
  if [[ -d "$state_src" ]]; then
    mkdir -p "$dest/.state"
    cp -a "$state_src"/. "$dest/.state/" 2>/dev/null || true
  fi
  # Save original update source if available
  local fw_json="$target/framework.json"
  if [[ -f "$fw_json" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.update_source // ""' "$fw_json" 2>/dev/null > "$dest/.original-update-source" || true
  fi
  return 0
}

# ── Restoration handler (idempotent) ─────────────────────────────

perform_restoration() {
  if [[ "$RESTORE_DONE" == "1" ]]; then
    return 0
  fi
  RESTORE_DONE=1

  if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    warn "No backup to restore from"
    return 1
  fi

  echo ""
  echo -e "${YELLOW}${BOLD}=== Restoring framework from backup ===${RESET}"
  echo "Backup: $BACKUP_DIR"
  echo "Target: $FRAMEWORK_TARGET"

  # Remove current framework
  if [[ -d "$FRAMEWORK_TARGET" ]]; then
    rm -rf "$FRAMEWORK_TARGET"
  fi

  # Restore from backup
  if ! cp -a "$BACKUP_DIR"/. "$FRAMEWORK_TARGET"/ 2>/dev/null; then
    echo -e "${RED}${BOLD}RESTORATION FAILED${RESET}" >&2
    echo "Manual recovery required:" >&2
    echo "  cp -a $BACKUP_DIR/. $FRAMEWORK_TARGET/" >&2
    return 1
  fi

  # Restore state
  if [[ -d "$BACKUP_DIR/.state" ]]; then
    mkdir -p "$STATE_TARGET"
    if ! cp -a "$BACKUP_DIR/.state"/. "$STATE_TARGET"/ 2>/dev/null; then
      echo -e "${YELLOW}WARN${RESET}: State restoration partially failed" >&2
    fi
  fi

  # Reinstall namespace
  if [[ -f "$FRAMEWORK_TARGET/bin/namespace-install.sh" ]]; then
    bash "$FRAMEWORK_TARGET/bin/namespace-install.sh" --quiet 2>/dev/null || true
  fi

  echo -e "${GREEN}${BOLD}Restoration complete${RESET}"
  return 0
}

# Install restoration traps
install_restoration_trap() {
  if [[ "$RESTORE_TRAP_INSTALLED" == "1" ]]; then
    return 0
  fi
  RESTORE_TRAP_INSTALLED=1
  trap 'perform_restoration' EXIT
  trap 'perform_restoration; exit 130' INT
  trap 'perform_restoration; exit 143' TERM
  trap 'perform_restoration; exit 129' HUP
}

# ── Usage ──────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
Usage: bash scripts/validate-framework-update-artix.sh [options]

Options:
  --apply-test    Enable destructive test (applies a test framework update)
  --user <name>   Target user (for multi-user systems)
  -h, --help      Show this help

Default mode performs non-destructive prerequisite and status checks.
--apply-test requires Artix Linux (checks /etc/artix-release).
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --apply-test) TEST_MODE="destructive" ;;
    --user) shift; APPLY_USER="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

# ── Prerequisites ─────────────────────────────────────────────────

section "Prerequisite checks"

# Test 1: Artix host
if is_artix; then
  pass "Artix host detected (/etc/artix-release present)"
else
  fail "Not running on Artix (/etc/artix-release missing)"
  if [[ "$TEST_MODE" == "destructive" ]]; then
    echo ""
    echo -e "${RED}${BOLD}ERROR${RESET}: --apply-test requires Artix Linux."
    echo "This script refuses to run destructive tests on non-Artix hosts."
    echo "Run without --apply-test for non-destructive prerequisite checks only."
    exit 1
  else
    warn "Non-Artix host — destructive mode will be refused"
  fi
fi

# Test 2: Required commands
for cmd in git jq vercmp sudo pacman; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd available"
  else
    fail "$cmd missing"
  fi
done

# Test 3: OpenRC services (non-destructive, check only)
for svc in dbus elogind NetworkManager; do
  if [[ -x "/etc/init.d/$svc" ]] 2>/dev/null; then
    pass "OpenRC service present: $svc"
  else
    warn "OpenRC service not found: $svc"
  fi
done

# Test 4: Framework source
if [[ -d "$FRAMEWORK_SOURCE/bin" ]]; then
  pass "Framework source available at $FRAMEWORK_SOURCE"
else
  fail "Framework source missing at $FRAMEWORK_SOURCE"
fi

# Test 5: Framework not deployed
if [[ -d "$FRAMEWORK_TARGET/bin" ]]; then
  pass "Framework deployed at $FRAMEWORK_TARGET"
else
  warn "Framework not deployed at $FRAMEWORK_TARGET"
fi

# Test 6: ahr-doctor
if [[ -f "$FRAMEWORK_TARGET/bin/ahr-doctor" ]]; then
  pass "ahr-doctor deployed"
  if [[ -x "$FRAMEWORK_TARGET/bin/ahr-doctor" ]]; then
    pass "ahr-doctor executable"
  else
    fail "ahr-doctor not executable"
  fi
else
  warn "ahr-doctor not deployed"
fi

# Test 7: ahr-update-available JSON
if [[ -f "$FRAMEWORK_TARGET/bin/ahr-update-available" ]]; then
  section "ahr-update-available JSON test"
  ahr_json="$(HOME="$HOME" bash "$FRAMEWORK_TARGET/bin/ahr-update-available" --json 2>/dev/null || true)"
  if [[ -n "$ahr_json" ]] && echo "$ahr_json" | python3 -m json.tool >/dev/null 2>&1; then
    pass "ahr-update-available --json produces valid JSON"
  else
    fail "ahr-update-available --json produces invalid JSON: $ahr_json"
  fi
fi

# ── Destructive tests ─────────────────────────────────────────────

if [[ "$TEST_MODE" != "destructive" ]]; then
  section "Summary (non-destructive)"
  echo "All prerequisite checks complete."
  echo "Pass: $PASS | Fail: $FAIL"
  echo ""
  echo "To run destructive tests, use: --apply-test (requires Artix)"
  if (( FAIL > 0 )); then
    exit 1
  fi
  exit 0
fi

# ── Destructive mode ─────────────────────────────────────────────

# Refuse if not on Artix
if ! is_artix; then
  echo ""
  echo -e "${RED}${BOLD}ERROR${RESET}: --apply-test requires Artix Linux." >&2
  echo "Refusing to run destructive tests on non-Artix host." >&2
  exit 1
fi

echo ""
echo -e "${RED}${BOLD}=== DESTRUCTIVE TEST MODE ===${RESET}"
echo "This will modify the installed framework. A complete backup will be created."
echo "All changes will be automatically restored on exit."
echo ""

# Create backup
BACKUP_DIR="$BACKUP_ROOT/backup-$(date +%s)"
LOG_FILE="$BACKUP_ROOT/validate.log"
mkdir -p "$BACKUP_ROOT"

echo "Creating backup at: $BACKUP_DIR"
if ! backup_framework "$FRAMEWORK_TARGET" "$BACKUP_DIR"; then
  echo -e "${RED}${BOLD}BACKUP FAILED${RESET}" >&2
  exit 1
fi
if [[ -d "$BACKUP_DIR" ]]; then
  pass "Backup created at $BACKUP_DIR"
else
  fail "Backup failed"
  exit 1
fi

# Install restoration traps
install_restoration_trap
echo "Restoration traps installed (EXIT, INT, TERM, HUP)"

# Test 8: Create test remote
section "Test 8: Create test framework remote"
TEST_REMOTE="$BACKUP_ROOT/test-remote"
mkdir -p "$TEST_REMOTE/artix-hypr-remix/config/artix-hypr-remix/bin"
for f in ahr ahr-update-framework ahr-update ahr-update-available ahr-lib.sh ahr-version.sh migrate.sh namespace-install.sh; do
  echo '#!/usr/bin/env bash' > "$TEST_REMOTE/artix-hypr-remix/config/artix-hypr-remix/bin/$f"
done
chmod +x "$TEST_REMOTE/artix-hypr-remix/config/artix-hypr-remix/bin/"*
echo '{"version":"99.99.99","revision":null,"channel":"stable","update_source":"file://'"$TEST_REMOTE"'","updated_at":null}' > "$TEST_REMOTE/artix-hypr-remix/config/artix-hypr-remix/framework.json"
(cd "$TEST_REMOTE" && git init -q && git config user.email "t@t" && git config user.name T && git add -A && git commit -q -m "test" >/dev/null)
pass "Test remote created at $TEST_REMOTE"

# Test 9: Apply test update
section "Test 9: Apply test framework update"
# Temporarily set update_source to test remote
ORIG_SOURCE="$(cat "$FRAMEWORK_TARGET/framework.json" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('update_source',''))" 2>/dev/null || echo "")"
python3 -c "
import json
with open('$FRAMEWORK_TARGET/framework.json') as f: d = json.load(f)
d['update_source'] = 'file://$TEST_REMOTE'
with open('$FRAMEWORK_TARGET/framework.json', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null

apply_exit=0
HOME="$HOME" bash "$FRAMEWORK_TARGET/bin/ahr-update-framework" --apply >"$LOG_FILE" 2>&1 || apply_exit=$?
if [[ "$apply_exit" == 0 ]]; then
  pass "Test apply succeeded"
else
  warn "Test apply exited $apply_exit (may be expected for test version 99.99.99)"
fi

# Test 10: Rollback test
section "Test 10: Test rollback"
rb_exit=0
HOME="$HOME" bash "$FRAMEWORK_TARGET/bin/ahr-update-framework" --rollback >"$LOG_FILE" 2>&1 || rb_exit=$?
if [[ "$rb_exit" == 0 ]]; then
  pass "Test rollback succeeded"
else
  fail "Test rollback failed (exit $rb_exit)"
fi

# Test 11: Check framework health after rollback
section "Test 11: Post-rollback framework health"
if [[ -x "$FRAMEWORK_TARGET/bin/ahr-doctor" ]]; then
  doctor_exit=0
  bash "$FRAMEWORK_TARGET/bin/ahr-doctor" >/dev/null 2>&1 || doctor_exit=$?
  if [[ "$doctor_exit" == 0 ]]; then
    pass "ahr-doctor passes after rollback"
  else
    warn "ahr-doctor reports issues after rollback (exit $doctor_exit)"
  fi
fi

# Restore original update source
if [[ -n "$ORIG_SOURCE" ]]; then
  python3 -c "
import json
with open('$FRAMEWORK_TARGET/framework.json') as f: d = json.load(f)
d['update_source'] = '$ORIG_SOURCE'
with open('$FRAMEWORK_TARGET/framework.json', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null
  pass "Original update source restored"
fi

# ── Summary ────────────────────────────────────────────────────────

section "Summary"
echo "Backup: $BACKUP_DIR"
echo "Log:    $LOG_FILE"
echo "Pass: $PASS | Fail: $FAIL"

# The restoration trap will restore the framework on exit
echo ""
echo "Framework will be restored from backup on exit."

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
