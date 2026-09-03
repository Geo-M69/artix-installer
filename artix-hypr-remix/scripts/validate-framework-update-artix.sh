#!/usr/bin/env bash
# On-machine validation for the AHR framework update pipeline.

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
NAMESPACE_TARGET="${AHR_LOCAL_BIN:-$HOME/.local/bin}"

BACKUP_ROOT="/tmp/ahr-validate-$$"
BACKUP_DIR=""
FRAMEWORK_BACKUP=""
STATE_BACKUP=""
NAMESPACE_BACKUP=""
METADATA_DIR=""
LOG_DIR=""
PREFLIGHT_LOG=""
APPLY_LOG=""
ROLLBACK_LOG=""
TEST_REMOTE=""
PRETEST_FRAMEWORK_PRESENT=false
PRETEST_STATE_PRESENT=false
PRETEST_NAMESPACE_PRESENT=false
RESTORE_DONE=0

pass() { echo -e "  ${GREEN}PASS${RESET}: $1"; ((PASS+=1)); }
fail() { echo -e "  ${RED}FAIL${RESET}: $1" >&2; [[ -n "${2:-}" ]] && echo "    $2" >&2; ((FAIL+=1)); }
warn() { echo -e "  ${YELLOW}WARN${RESET}: $1"; }
section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${RESET}"; }

is_artix() {
  [[ -f /etc/artix-release ]]
}

tree_digest() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    printf 'ABSENT\n'
    return 0
  fi
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
    -C "$root" -cf - . | sha256sum | awk '{print $1}'
}

copy_tree() {
  local source="$1" destination="$2"
  mkdir -p "$destination"
  cp -a "$source"/. "$destination"/
}

configure_artifacts() {
  BACKUP_DIR="$BACKUP_ROOT/backup-$(date +%s)"
  FRAMEWORK_BACKUP="$BACKUP_DIR/framework"
  STATE_BACKUP="$BACKUP_DIR/state"
  NAMESPACE_BACKUP="$BACKUP_DIR/namespace"
  METADATA_DIR="$BACKUP_DIR/metadata"
  LOG_DIR="$BACKUP_ROOT/logs"
  PREFLIGHT_LOG="$LOG_DIR/preflight.log"
  APPLY_LOG="$LOG_DIR/apply.log"
  ROLLBACK_LOG="$LOG_DIR/rollback.log"
  mkdir -p "$FRAMEWORK_BACKUP" "$STATE_BACKUP" "$NAMESPACE_BACKUP" "$METADATA_DIR" "$LOG_DIR"
}

backup_pretest_baseline() {
  [[ -n "$BACKUP_DIR" ]] || return 1

  if [[ -d "$FRAMEWORK_TARGET" ]]; then
    PRETEST_FRAMEWORK_PRESENT=true
    copy_tree "$FRAMEWORK_TARGET" "$FRAMEWORK_BACKUP"
  fi
  if [[ -d "$STATE_TARGET" ]]; then
    PRETEST_STATE_PRESENT=true
    copy_tree "$STATE_TARGET" "$STATE_BACKUP"
  fi
  if [[ -d "$NAMESPACE_TARGET" ]]; then
    PRETEST_NAMESPACE_PRESENT=true
    copy_tree "$NAMESPACE_TARGET" "$NAMESPACE_BACKUP"
  fi

  printf '%s\n' "$PRETEST_FRAMEWORK_PRESENT" > "$METADATA_DIR/framework-present"
  printf '%s\n' "$PRETEST_STATE_PRESENT" > "$METADATA_DIR/state-present"
  printf '%s\n' "$PRETEST_NAMESPACE_PRESENT" > "$METADATA_DIR/namespace-present"
  tree_digest "$FRAMEWORK_TARGET" > "$METADATA_DIR/framework.digest"
  tree_digest "$STATE_TARGET" > "$METADATA_DIR/state.digest"
  tree_digest "$NAMESPACE_TARGET" > "$METADATA_DIR/namespace.digest"
}

restore_tree() {
  local was_present="$1" source="$2" destination="$3"

  if [[ "$was_present" == "true" ]]; then
    rm -rf "$destination"
    mkdir -p "$destination"
    copy_tree "$source" "$destination"
  else
    rm -rf "$destination"
  fi
}

verify_pretest_baseline() {
  local expected_framework expected_state expected_namespace actual_framework actual_state actual_namespace
  expected_framework="$(<"$METADATA_DIR/framework.digest")"
  expected_state="$(<"$METADATA_DIR/state.digest")"
  expected_namespace="$(<"$METADATA_DIR/namespace.digest")"
  actual_framework="$(tree_digest "$FRAMEWORK_TARGET")"
  actual_state="$(tree_digest "$STATE_TARGET")"
  actual_namespace="$(tree_digest "$NAMESPACE_TARGET")"

  [[ "$actual_framework" == "$expected_framework" ]] || return 1
  [[ "$actual_state" == "$expected_state" ]] || return 1
  [[ "$actual_namespace" == "$expected_namespace" ]] || return 1

  if [[ "$PRETEST_FRAMEWORK_PRESENT" == "true" ]]; then
    diff -qr "$FRAMEWORK_BACKUP" "$FRAMEWORK_TARGET" >/dev/null
  else
    [[ ! -e "$FRAMEWORK_TARGET" ]]
  fi
  if [[ "$PRETEST_NAMESPACE_PRESENT" == "true" ]]; then
    diff -qr "$NAMESPACE_BACKUP" "$NAMESPACE_TARGET" >/dev/null
  else
    [[ ! -e "$NAMESPACE_TARGET" ]]
  fi
  if [[ "$PRETEST_STATE_PRESENT" == "true" ]]; then
    diff -qr "$STATE_BACKUP" "$STATE_TARGET" >/dev/null
  else
    [[ ! -e "$STATE_TARGET" ]]
  fi

  [[ ! -e "$FRAMEWORK_TARGET/.state" ]]
  [[ ! -e "$FRAMEWORK_TARGET/.original-update-source" ]]
}

perform_restoration() {
  if [[ "$RESTORE_DONE" == "1" ]]; then
    return 0
  fi
  RESTORE_DONE=1

  if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    warn "No pre-test baseline is available for restoration"
    return 1
  fi

  echo ""
  echo -e "${YELLOW}${BOLD}=== Restoring pre-test framework and state ===${RESET}"
  echo "Backup: $BACKUP_DIR"

  restore_tree "$PRETEST_FRAMEWORK_PRESENT" "$FRAMEWORK_BACKUP" "$FRAMEWORK_TARGET" || return 1
  restore_tree "$PRETEST_STATE_PRESENT" "$STATE_BACKUP" "$STATE_TARGET" || return 1
  restore_tree "$PRETEST_NAMESPACE_PRESENT" "$NAMESPACE_BACKUP" "$NAMESPACE_TARGET" || return 1

  # Do not run namespace-install here: it regenerates namespace state and does
  # not prove the prior namespace was restored exactly.
  if ! verify_pretest_baseline; then
    echo -e "${RED}${BOLD}RESTORATION BASELINE MISMATCH${RESET}" >&2
    return 1
  fi

  echo -e "${GREEN}${BOLD}Restoration matches the pre-test baseline${RESET}"
  return 0
}

handle_exit() {
  local status=$?
  trap - EXIT
  if ! perform_restoration; then
    status=1
  fi
  exit "$status"
}

handle_signal() {
  local status="$1"
  perform_restoration || true
  exit "$status"
}

install_restoration_traps() {
  trap handle_exit EXIT
  trap 'handle_signal 130' INT
  trap 'handle_signal 143' TERM
  trap 'handle_signal 129' HUP
}

set_update_source() {
  local framework_json="$1" source="$2" tmp
  tmp="$(mktemp "${framework_json}.tmp.XXXXXX")"
  jq --arg source "$source" '.update_source = $source' "$framework_json" > "$tmp"
  mv -f "$tmp" "$framework_json"
}

build_test_remote() {
  TEST_REMOTE="$BACKUP_ROOT/test-remote"
  local candidate="$TEST_REMOTE/artix-hypr-remix/config/artix-hypr-remix"
  mkdir -p "$candidate"
  copy_tree "$FRAMEWORK_SOURCE" "$candidate"

  local metadata_tmp
  metadata_tmp="$(mktemp "$candidate/framework.json.tmp.XXXXXX")"
  jq --arg source "file://$TEST_REMOTE" \
    '.version = "99.99.99" | .revision = null | .channel = "stable" | .update_source = $source | .updated_at = null' \
    "$candidate/framework.json" > "$metadata_tmp"
  mv -f "$metadata_tmp" "$candidate/framework.json"

  git -C "$TEST_REMOTE" init -q
  git -C "$TEST_REMOTE" config user.email "ahr-validation@localhost"
  git -C "$TEST_REMOTE" config user.name "AHR validation"
  git -C "$TEST_REMOTE" add -A
  git -C "$TEST_REMOTE" commit -q -m "synthetic framework update"
}

preflight_test_remote() {
  local preflight_root="$BACKUP_ROOT/preflight"
  local preflight_framework="$preflight_root/framework"
  local preflight_state="$preflight_root/state"
  local preflight_cache="$preflight_root/cache"

  rm -rf "$preflight_root"
  mkdir -p "$preflight_framework"
  copy_tree "$FRAMEWORK_TARGET" "$preflight_framework"
  set_update_source "$preflight_framework/framework.json" "file://$TEST_REMOTE"

  HOME="$preflight_root/home" \
  XDG_STATE_HOME="$preflight_state" \
  XDG_CACHE_HOME="$preflight_cache" \
  AHR_FRAMEWORK_ROOT="$preflight_framework" \
  AHR_LIB_PATH="$preflight_framework/bin/ahr-lib.sh" \
    bash "$preflight_framework/bin/ahr-update-framework" --dry-run > "$PREFLIGHT_LOG" 2>&1
}

valid_new_updater_rollback_target_exists() {
  local backup_root="$STATE_TARGET/framework-backups"
  local backup manifest backup_id transaction_id transaction_state transaction_backup transaction_backup_id
  [[ -d "$backup_root" ]] || return 1

  for backup in "$backup_root"/*; do
    [[ -d "$backup" ]] || continue
    # A prior completed backup is not evidence that this synthetic apply made
    # progress. Only a backup absent from the sealed pre-test state is eligible.
    [[ ! -e "$STATE_BACKUP/framework-backups/$(basename "$backup")" ]] || continue
    manifest="$backup/manifest.txt"
    [[ -f "$manifest" ]] || continue
    backup_id="$(awk -F= '$1 == "backup_id" { count++; value=$2 } END { if (count == 1) print value; else exit 1 }' "$manifest" 2>/dev/null)" || continue
    transaction_id="$(awk -F= '$1 == "transaction_id" { count++; value=$2 } END { if (count == 1) print value; else exit 1 }' "$manifest" 2>/dev/null)" || continue
    [[ "$backup_id" == "$(basename "$backup")" ]] || continue
    [[ -n "$transaction_id" ]] || continue
    grep -qx 'manifest_version=1' "$manifest" || continue
    grep -qx 'completed=true' "$manifest" || continue
    transaction_state="$STATE_TARGET/framework-transactions/$transaction_id/state"
    [[ -f "$transaction_state" ]] || continue
    transaction_backup="$(awk -F= '$1 == "backup_path" { count++; value=$2 } END { if (count == 1) print value; else exit 1 }' "$transaction_state" 2>/dev/null)" || continue
    transaction_backup_id="$(awk -F= '$1 == "backup_id" { count++; value=$2 } END { if (count == 1) print value; else exit 1 }' "$transaction_state" 2>/dev/null)" || continue
    [[ "$transaction_backup" == "$backup" && "$transaction_backup_id" == "$backup_id" ]] || continue
    return 0
  done
  return 1
}

run_updater() {
  local mode="$1" log_file="$2"
  HOME="$HOME" \
  XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}" \
  XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}" \
  AHR_FRAMEWORK_ROOT="$FRAMEWORK_TARGET" \
  AHR_LIB_PATH="$FRAMEWORK_TARGET/bin/ahr-lib.sh" \
  AHR_LOCAL_BIN="$NAMESPACE_TARGET" \
    bash "$FRAMEWORK_TARGET/bin/ahr-update-framework" "$mode" > "$log_file" 2>&1
}

if [[ "${AHR_VALIDATE_HARNESS_LIB_ONLY:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

usage() {
  cat <<'EOF'
Usage: bash scripts/validate-framework-update-artix.sh [options]

Options:
  --apply-test    Enable destructive test (applies a synthetic framework update)
  --user <name>   Require the command to run as this desktop user
  -h, --help      Show this help

Default mode performs non-destructive prerequisite checks.
--apply-test requires Artix Linux (checks /etc/artix-release).
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --apply-test) TEST_MODE="destructive" ;;
    --user) shift; APPLY_USER="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ -n "$APPLY_USER" && "$APPLY_USER" != "$(id -un)" ]]; then
  echo "Run this harness as the requested desktop user: $APPLY_USER" >&2
  exit 2
fi

section "Prerequisite checks"
if is_artix; then
  pass "Artix host detected (/etc/artix-release present)"
else
  fail "Not running on Artix (/etc/artix-release missing)"
  [[ "$TEST_MODE" == "destructive" ]] && exit 1
fi

for cmd in git jq vercmp sudo pacman; do
  command -v "$cmd" >/dev/null 2>&1 && pass "$cmd available" || fail "$cmd missing"
done
for svc in dbus elogind NetworkManager; do
  [[ -x "/etc/init.d/$svc" ]] && pass "OpenRC service present: $svc" || warn "OpenRC service not found: $svc"
done
[[ -d "$FRAMEWORK_SOURCE/bin" ]] && pass "Framework source available at $FRAMEWORK_SOURCE" || fail "Framework source missing at $FRAMEWORK_SOURCE"
[[ -d "$FRAMEWORK_TARGET/bin" ]] && pass "Framework deployed at $FRAMEWORK_TARGET" || fail "Framework not deployed at $FRAMEWORK_TARGET"
[[ -x "$FRAMEWORK_TARGET/bin/ahr-doctor" ]] && pass "ahr-doctor deployed and executable" || fail "ahr-doctor not deployed or executable"
if [[ -f "$FRAMEWORK_TARGET/bin/ahr-update-available" ]]; then
  section "ahr-update-available JSON test"
  ahr_json="$(HOME="$HOME" bash "$FRAMEWORK_TARGET/bin/ahr-update-available" --json 2>/dev/null || true)"
  if [[ -n "$ahr_json" ]] && echo "$ahr_json" | python3 -m json.tool >/dev/null 2>&1; then
    pass "ahr-update-available --json produces valid JSON"
  else
    fail "ahr-update-available --json produces invalid JSON: $ahr_json"
  fi
fi

if [[ "$TEST_MODE" != "destructive" ]]; then
  section "Summary (non-destructive)"
  echo "Pass: $PASS | Fail: $FAIL"
  (( FAIL == 0 ))
  exit $?
fi

is_artix || exit 1

section "Synthetic candidate preflight"
mkdir -p "$BACKUP_ROOT"
configure_artifacts
build_test_remote
if preflight_test_remote; then
  pass "Complete synthetic candidate passed staged validation before host mutation"
else
  fail "Synthetic candidate preflight failed; no live framework mutation was attempted" "See $PREFLIGHT_LOG"
  exit 1
fi

section "Destructive test mode"
backup_pretest_baseline
pass "Pre-test framework and state baseline saved at $BACKUP_DIR"
install_restoration_traps
set_update_source "$FRAMEWORK_TARGET/framework.json" "file://$TEST_REMOTE"

section "Apply synthetic framework update"
apply_exit=0
run_updater --apply "$APPLY_LOG" || apply_exit=$?
if (( apply_exit == 0 )); then
  pass "Synthetic apply succeeded"
else
  fail "Synthetic apply failed (exit $apply_exit)" "See $APPLY_LOG"
fi

section "Rollback synthetic framework update"
if valid_new_updater_rollback_target_exists; then
  rollback_exit=0
  run_updater --rollback "$ROLLBACK_LOG" || rollback_exit=$?
  (( rollback_exit == 0 )) && pass "Synthetic rollback succeeded" || fail "Synthetic rollback failed (exit $rollback_exit)" "See $ROLLBACK_LOG"
elif (( apply_exit == 0 )); then
  fail "Synthetic apply succeeded but did not create a valid updater rollback target"
else
  pass "Pre-backup apply failure created no valid rollback target; rollback was not invoked"
fi

if ! perform_restoration; then
  fail "Outer restoration failed baseline verification"
fi

section "Summary"
echo "Evidence root: $BACKUP_ROOT"
echo "Preflight log: $PREFLIGHT_LOG"
echo "Apply log: $APPLY_LOG"
echo "Rollback log: $ROLLBACK_LOG"
echo "Pass: $PASS | Fail: $FAIL"
(( FAIL == 0 ))
