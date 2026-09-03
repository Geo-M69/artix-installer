#!/usr/bin/env bash
# Focused offline tests for the real-Artix framework-update validation harness.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HARNESS="$SCRIPT_DIR/validate-framework-update-artix.sh"

PASS=0
FAIL=0
TMP_ROOT="$(mktemp -d /tmp/ahr-harness-test-XXXXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() { echo "  PASS: $1"; ((PASS+=1)); }
fail() { echo "  FAIL: $1" >&2; [[ -n "${2:-}" ]] && echo "    $2" >&2; ((FAIL+=1)); }

export AHR_VALIDATE_HARNESS_LIB_ONLY=1
# shellcheck source=validate-framework-update-artix.sh
source "$HARNESS"
unset AHR_VALIDATE_HARNESS_LIB_ONLY

reset_context() {
  local name="$1"
  local root="$TMP_ROOT/$name"
  BACKUP_ROOT="$root/work"
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
  FRAMEWORK_TARGET="$root/installed-framework"
  STATE_TARGET="$root/state"
  NAMESPACE_TARGET="$root/local-bin"
  mkdir -p "$FRAMEWORK_TARGET" "$STATE_TARGET" "$NAMESPACE_TARGET"
  copy_tree "$REPO_ROOT/config/artix-hypr-remix" "$FRAMEWORK_TARGET"
  mkdir -p "$STATE_TARGET/namespace-snapshots/current"
  printf 'format_version=1\ncreated_at=baseline\n' > "$STATE_TARGET/namespace-snapshots/current/namespace-manifest.txt"
  printf 'baseline-state\n' > "$STATE_TARGET/sentinel"
  printf 'namespace baseline\n' > "$NAMESPACE_TARGET/sentinel"
}

run_temp_updater() {
  local mode="$1" output="$2"
  HOME="$TMP_ROOT/test-home" \
  XDG_STATE_HOME="$STATE_TARGET" \
  XDG_CACHE_HOME="$TMP_ROOT/cache" \
  AHR_FRAMEWORK_ROOT="$FRAMEWORK_TARGET" \
  AHR_LIB_PATH="$FRAMEWORK_TARGET/bin/ahr-lib.sh" \
  AHR_LOCAL_BIN="$NAMESPACE_TARGET" \
    bash "$FRAMEWORK_TARGET/bin/ahr-update-framework" "$mode" > "$output" 2>&1
}

echo "=== Valid generated candidate preflight ==="
reset_context valid
mkdir -p "$BACKUP_ROOT"
configure_artifacts
build_test_remote
if preflight_test_remote; then
  pass "complete generated candidate passes updater staged validation"
else
  fail "complete generated candidate failed updater staged validation" "$(<"$PREFLIGHT_LOG")"
fi

echo "=== Invalid generated candidate preflight ==="
reset_context invalid
mkdir -p "$BACKUP_ROOT"
configure_artifacts
build_test_remote
rm -f "$TEST_REMOTE/artix-hypr-remix/config/artix-hypr-remix/bin/ahr-doctor"
git -C "$TEST_REMOTE" add -A
git -C "$TEST_REMOTE" commit -q -m "invalidate staged doctor"
invalid_framework_before="$(tree_digest "$FRAMEWORK_TARGET")"
if preflight_test_remote; then
  fail "invalid generated candidate unexpectedly passed preflight"
else
  grep -q 'Missing required executable command: bin/ahr-doctor' "$PREFLIGHT_LOG" && pass "invalid candidate is rejected by staged validation" || fail "preflight did not retain staged-validation reason"
fi
[[ "$(tree_digest "$FRAMEWORK_TARGET")" == "$invalid_framework_before" ]] && pass "invalid preflight does not mutate the test framework" || fail "invalid preflight mutated the test framework"

echo "=== Pre-backup apply failure rollback gate ==="
set_update_source "$FRAMEWORK_TARGET/framework.json" "file://$TEST_REMOTE"
apply_failure_log="$BACKUP_ROOT/prebackup-apply.log"
prebackup_exit=0
run_temp_updater --apply "$apply_failure_log" || prebackup_exit=$?
(( prebackup_exit != 0 )) && pass "invalid staged apply fails before backup" || fail "invalid staged apply unexpectedly succeeded"
if valid_new_updater_rollback_target_exists; then
  fail "pre-backup failure fabricated a rollback target"
else
  pass "pre-backup failure leaves no rollback target, so rollback is gated off"
fi

echo "=== Existing backup does not satisfy the rollback gate ==="
reset_context existing-backup
mkdir -p "$BACKUP_ROOT"
configure_artifacts
mkdir -p "$STATE_TARGET/framework-backups/old-valid" "$STATE_TARGET/framework-transactions/tx-old"
cat > "$STATE_TARGET/framework-backups/old-valid/manifest.txt" <<'EOF'
manifest_version=1
backup_id=old-valid
transaction_id=tx-old
completed=true
EOF
cat > "$STATE_TARGET/framework-transactions/tx-old/state" <<EOF
backup_id=old-valid
backup_path=$STATE_TARGET/framework-backups/old-valid
EOF
backup_pretest_baseline
if valid_new_updater_rollback_target_exists; then
  fail "existing pre-test backup incorrectly satisfies the new rollback gate"
else
  pass "existing pre-test backup cannot trigger rollback after a new pre-backup failure"
fi

echo "=== Separate logs and exact restoration ==="
reset_context restore
mkdir -p "$BACKUP_ROOT"
configure_artifacts
[[ "$APPLY_LOG" != "$ROLLBACK_LOG" && "$APPLY_LOG" != "$PREFLIGHT_LOG" && "$ROLLBACK_LOG" != "$PREFLIGHT_LOG" ]] && pass "preflight, apply, and rollback logs have separate paths" || fail "harness log paths overlap"
backup_pretest_baseline
printf 'apply transcript\n' > "$APPLY_LOG"
printf 'rollback transcript\n' > "$ROLLBACK_LOG"
mkdir -p "$FRAMEWORK_TARGET/.state"
printf 'leaked metadata\n' > "$FRAMEWORK_TARGET/.original-update-source"
printf 'mutated framework\n' > "$FRAMEWORK_TARGET/mutated"
printf 'mutated state\n' > "$STATE_TARGET/sentinel"
printf 'new state residue\n' > "$STATE_TARGET/new-residue"
printf 'new namespace residue\n' > "$NAMESPACE_TARGET/new-residue"
printf 'format_version=1\ncreated_at=mutated\n' > "$STATE_TARGET/namespace-snapshots/current/namespace-manifest.txt"
if perform_restoration; then
  pass "outer restoration matches framework and state baseline"
else
  fail "outer restoration did not match baseline"
fi
[[ ! -e "$FRAMEWORK_TARGET/.state" && ! -e "$FRAMEWORK_TARGET/.original-update-source" && ! -e "$FRAMEWORK_TARGET/mutated" ]] && pass "harness metadata and synthetic framework residue do not leak" || fail "framework residue remained after restoration"
[[ ! -e "$STATE_TARGET/new-residue" ]] && pass "state restoration replaces rather than merges" || fail "state residue remained after restoration"
[[ ! -e "$NAMESPACE_TARGET/new-residue" && "$(<"$NAMESPACE_TARGET/sentinel")" == 'namespace baseline' ]] && pass "namespace links are restored by replacement" || fail "namespace residue remained after restoration"
grep -qx 'created_at=baseline' "$STATE_TARGET/namespace-snapshots/current/namespace-manifest.txt" && pass "namespace state is restored exactly without regeneration" || fail "namespace state was regenerated"
[[ "$(<"$APPLY_LOG")" == 'apply transcript' && "$(<"$ROLLBACK_LOG")" == 'rollback transcript' ]] && pass "separate logs retain their own transcripts" || fail "separate logs were overwritten"

echo ""
echo "Pass: $PASS | Fail: $FAIL"
(( FAIL == 0 ))
