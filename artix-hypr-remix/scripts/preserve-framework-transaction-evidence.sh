#!/usr/bin/env bash
# Copy one exact framework-update transaction association into validation
# evidence before a destructive validator restores its original baseline.
# This helper never changes updater state, backups, or transactions.
set -euo pipefail

state_root=""
transaction_id=""
backup_id=""
apply_log=""
output_dir=""

usage() {
  cat <<'EOF'
Usage: preserve-framework-transaction-evidence.sh --state-root DIR \
  --transaction-id ID --backup-id ID --output DIR [--apply-log FILE]

Copies exactly these files when present:
  framework-transactions/TRANSACTION-ID/state
  framework-backups/BACKUP-ID/manifest.txt
  framework-backups/BACKUP-ID/component-manifest.txt
  apply log supplied with --apply-log

The source files are read only. The destination must not already exist.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --state-root) shift; state_root="${1:-}" ;;
    --transaction-id) shift; transaction_id="${1:-}" ;;
    --backup-id) shift; backup_id="${1:-}" ;;
    --apply-log) shift; apply_log="${1:-}" ;;
    --output) shift; output_dir="${1:-}" ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -n "$state_root" && -n "$transaction_id" && -n "$backup_id" && -n "$output_dir" ]] || {
  usage >&2
  exit 2
}
[[ "$transaction_id" =~ ^tx-[A-Za-z0-9._-]+$ && "$transaction_id" != *".."* ]] || {
  printf 'Invalid transaction ID\n' >&2
  exit 2
}
[[ "$backup_id" =~ ^[A-Za-z0-9._-]+$ && "$backup_id" != "." && "$backup_id" != ".." && "$backup_id" != *".."* ]] || {
  printf 'Invalid backup ID\n' >&2
  exit 2
}

tx_state="$state_root/framework-transactions/$transaction_id/state"
backup_dir="$state_root/framework-backups/$backup_id"
primary_manifest="$backup_dir/manifest.txt"
component_manifest="$backup_dir/component-manifest.txt"
[[ -f "$tx_state" && -f "$primary_manifest" ]] || {
  printf 'Exact transaction state or primary manifest is unavailable\n' >&2
  exit 1
}
[[ ! -e "$output_dir" ]] || {
  printf 'Evidence destination already exists: %s\n' "$output_dir" >&2
  exit 1
}

umask 077
mkdir -p "$output_dir"
cp -a "$tx_state" "$output_dir/transaction.state"
cp -a "$primary_manifest" "$output_dir/manifest.txt"
[[ ! -f "$component_manifest" ]] || cp -a "$component_manifest" "$output_dir/component-manifest.txt"
[[ -z "$apply_log" || ! -f "$apply_log" ]] || cp -a "$apply_log" "$output_dir/apply.log"
printf 'transaction_id=%s\nbackup_id=%s\n' "$transaction_id" "$backup_id" > "$output_dir/identity.txt"
printf 'evidence_dir=%s\n' "$output_dir"
