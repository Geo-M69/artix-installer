# Framework Update And Rollback

This document describes how AHR delivers and recovers from framework updates.

## Overview

AHR's framework is the set of scripts, migrations, docs, hooks, and metadata
that live under `~/.config/artix-hypr-remix/`. Framework updates deliver new
commands, migrations, and health checks without requiring a full reinstall.

Framework updates are independent of system package updates (pacman/AUR) and
Flatpak application updates. Each category is tracked and reported separately
by `ahr update-available`.

## Commands

| Command | Purpose |
|---------|---------|
| `--status` | Print installed framework metadata (default) |
| `--check` | Compare installed version against remote (read-only) |
| `--dry-run` | Discover and validate; stop before backup or activation |
| `--apply` | Fetch, stage, validate, backup, activate, migrate, health-check |
| `--rollback` | Restore the previous framework from the last backup |
| `--recover` | Recover from an interrupted apply or rollback transaction |

## Commit Pinning

Every dry-run and apply operation uses **one authoritative staged commit**:

1. Clone the update source once into a staging directory.
2. Resolve `git rev-parse HEAD` to get the exact commit.
3. Read `framework.json` from that checkout.
4. Validate the metadata (version, channel, declared revision).
5. Immediately before activation, verify the commit has not changed.
6. Activate that exact checkout.

A moving remote branch cannot alter the selected update after the commit is
resolved. The installed `framework.json` records the activated commit as
`revision`.

### Cache Contract

The status cache stores an atomic record containing timestamp, source, channel,
version, and commit. Cached version data cannot be paired with a different
commit. The cache is invalidated after every successful apply and rollback.

Apply and dry-run always use a fresh authoritative checkout. The status cache
is used only by `--check` and `ahr-update-available` for fast read-only queries.

## Transaction Model

All destructive operations use an exclusive transaction model with:

- **Collision-proof transaction ID**: Created with `mktemp -d` under
  `~/.local/state/artix-hypr-remix/framework-transactions/`. Never uses PID
  alone as the sole identifier.
- **Durable transaction state**: Each transaction has a `state` file with
  key=value records. No space-separated fields. Never sourced as shell. New
  apply transactions retain immutable `transaction_id`, `backup_id`, and
  `backup_path` fields through terminal commit, which is cross-checked against
  the primary backup manifest.
- **Per-target progress tracking**: Prepared and archived paths are recorded
  with exact paths in the transaction state.
- **Signal-aware restoration**: Traps on EXIT, INT, TERM, HUP perform
  reverse-order restoration from transaction archives.
- **Stale transaction policy**: At startup, incomplete transactions are
  detected. New apply/rollback refuses to start. The `--recover` command
  inspects and completes interrupted transactions.
- **Prevalidated rollback**: Rollback validates every required backup target
  before the first mutation. Missing targets cause failure with no modification.

## Apply Lifecycle

| Phase | Description |
|-------|-------------|
| `discovering` | Fetching remote version |
| `staged` | Clone pinned, validating staged framework |
| `backup_in_progress` | Creating collision-proof backup |
| `backup_complete` | Backup verified with manifest |
| `activation_in_progress` | Transaction active, archiving installed targets |
| `activated` | New targets activated, framework.json updated |
| `namespace` | Command namespace reinstalled |
| `migration` | Post-activation migrations running |
| `health_check` | ahr-doctor running |
| `complete` | All phases succeeded |
| `health_check_failed` | Health check reported issues (exit 1) |
| `migration_failed` | Migration failed (exit 1) |
| `failed` | Operation failed at this phase |
| `recovered` | Recovery completed by --recover |

### Controlled Validation Namespace Fault

For developer validation only, AHR_TEST_FAIL_NAMESPACE_INSTALL=1 makes an
--apply run enter the ordinary post-activation namespace_failed path. The
updater first runs the real production namespace installer and requires it to
succeed. It then forces only the updater's namespace decision to fail, logs
TEST FAULT: forcing namespace-install failure, and records
failure_reason=test_fault_forced_namespace_install_failure in the transaction.

The setting is process-local and is not written to namespace state, framework
configuration, backup manifests, migration state, or persistent defaults. It
accepts only the exact value 1; any other nonempty value is rejected before an
operation begins. This is not a normal user feature.

The resulting namespace_failed apply is intentionally preserved for
inspection. Runtime smoke, migrations, and doctor are not reached. --recover
remains a non-mutating direction check that exits nonzero and directs the
exact-associated --rollback resolution path.

### Controlled Validation Health Fault

For developer validation only, `AHR_TEST_FAIL_HEALTH_CHECK=1` makes an
`--apply` run enter the ordinary post-activation `health_check_failed` path.
The updater still runs the real staged `ahr-doctor` first; it then forces only
the updater's health decision to fail, records `TEST FAULT: forcing
post-activation health-check failure`, and records the distinguishable
`failure_reason=test_fault_forced_health_check_failure` in the transaction.
The setting is process-local and is not written to framework configuration,
backup manifests, or persistent defaults. It accepts only the exact value
`1`; any other nonempty value is rejected before an operation begins.

This is not a normal user feature. A resulting `health_check_failed` apply is
intentionally preserved for inspection; `--recover` directs the documented
exact-associated `--rollback` resolution path.

### Controlled Validation Migration Fault

For developer validation only, `AHR_TEST_FAIL_MIGRATION=1` makes an `--apply`
run enter the ordinary post-activation `migration_failed` path. The updater
first runs normal migration processing, including a no-op result when every
migration is already marked applied. It then forces only the updater's
migration decision to fail, logs `TEST FAULT: forcing migration failure`, and
records `failure_reason=test_fault_forced_migration_failure` in the
transaction.

The setting is process-local and is not written to migration scripts, applied
or skipped markers, framework configuration, backup manifests, or persistent
defaults. It accepts only the exact value `1`; any other nonempty value is
rejected before an operation begins. This is not a normal user feature.

The resulting `migration_failed` apply is intentionally preserved for
inspection. `--recover` remains a non-mutating direction check that exits
nonzero and directs the exact-associated `--rollback` resolution path.

## Backup Contents

Each backup directory contains:

- `bin/`, `migrations/`, `docs/`, `hooks/`, `first-run.d/`, `default/`
- `framework.json`
- `migration-snapshot/applied/` — applied migration markers
- `migration-snapshot/skipped/` — skipped migration markers
- `derived-<component>/` — managed-derived component backups
- `manifest.txt` — backup manifest

### Manifest Format

```text
manifest_version=1
completed=true
previous_version=0.1.0
previous_revision=<sha|null>
new_version=0.2.0
staging_commit=<sha>
channel=stable
update_source=<url>
timestamp=YYYYMMDD-HHMMSS
backup_dir=<path>
targets=bin
targets=migrations
targets=docs
targets=hooks
targets=first-run.d
targets=default
managed_files=framework.json
derived_components=framework-config|framework.json|false|true
derived_components=namespace-links|namespace|false|true
derived_components=migration-markers|migrations|true|true
derived_components=theme-state|current|true|false
migration_snapshot=<path>
added_markers=<marker1|marker2>
```

The manifest uses one key per line with no space-separated fields. Values
are not sourced as shell code.

## Staged Validation

`validate_staged_framework()` checks:

- `framework.json` exists and is parseable
- `version` field present and valid format (`MAJOR.MINOR.PATCH[-prerelease]`)
- `channel` field present and in allowlist (`stable`, `beta`)
- Version matches discovered version
- Declared revision matches pinned commit (if both declared)
- All `FRAMEWORK_TARGETS` directories exist
- All `REQUIRED_STAGED_SCRIPTS` exist, are regular files, and are executable
- Recursive full-tree validation: no symlink escapes, no broken symlinks,
  no FIFOs, no sockets, no block/char devices
- All `.sh` files pass `bash -n`
- Extensionless executables with shell shebangs pass `bash -n`

## Migration State Restoration

Rollback restores both applied and skipped migration marker directories
**exactly** from the snapshot:

1. Validate the snapshot exists
2. Create a temporary restored directory
3. Populate it from the snapshot
4. Replace the current marker directory transactionally

This removes markers introduced after the snapshot while preserving all
pre-existing markers.

**Migration side effects are not automatically reversed.** A migration may
modify files outside the marker system. Rollback restores marker state but
does not undo those modifications.

## Managed-Derived Components

The following components are backed up and can be restored:

| Component | Path | Editable | Restore Safe |
|-----------|------|----------|--------------|
| `framework-config` | `framework.json` | No | Yes |
| `namespace-links` | AHR-owned links in `~/.local/bin/` | No | Yes |
| `migration-state` | `~/.local/state/artix-hypr-remix/migrations/` | Yes | Rollback only |
| `theme-state` | `current/` | Yes | Requires `--apply` |

### Restore Command

```bash
ahr restore-component --list
ahr restore-component <component> --from-last-update [--apply]
ahr restore-component <component> --backup <backup-id> [--apply]
```

The command:
- Lists supported components
- Defaults to dry-run (shows what would be restored)
- Requires `--apply` for actual restoration
- Validates the backup manifest
- Validates that the component exists in the backup
- Constrains restored paths to the component inventory
- Backs up the current component before replacement
- Restores only that component
- Reports every restored file
- Rejects unsupported components and path traversal

Each public selector maps to one explicit canonical backup component. The
dry-run prints that canonical name, backup ID, snapshot, absolute target,
shape, and policy. Targets are resolved from their declared ownership root:
framework state under `AHR_FRAMEWORK_ROOT`, user configuration under
`${XDG_CONFIG_HOME:-$HOME/.config}`, runtime state under
`${XDG_STATE_HOME:-$HOME/.local/state}`, and namespace links under
`AHR_LOCAL_BIN` (or `~/.local/bin`). Thus a restore command is independent of
the current working directory and never treats user configuration paths as
framework-relative.

`framework-config` is restored as a file. `theme-state` is restored as a
directory. `namespace-links` is a historical TSV snapshot of AHR-owned links,
not a fictional directory under the framework root. Each
`derived-namespace-links` record is exactly `name<TAB>target`; dry-run and
`--apply` validate that same complete snapshot before any namespace link is
changed. A snapshot name must also be in the canonical command/alias inventory.
For such a managed namespace slot, a symlink with a stale, broken, or foreign
current target is repairable; a regular file, directory, or special path still
rejects the complete restore before mutation. Migration state is restored exactly by
framework rollback under the migration lock; it is intentionally not offered
as a standalone component restore.

## Interrupted-Update Recovery

If an apply or rollback is interrupted (signal, crash, power loss):

1. The transaction state in `framework-transactions/tx-XXX/state` records
   the incomplete phase.
2. At startup, `check_incomplete_transactions()` detects this.
3. New apply/rollback refuses to start.
4. Run `ahr update-framework --recover` to complete or restore.

The `--recover` command:
- Inspects the incomplete transaction
- Validates all transaction paths
- Determines which targets were activated
- Restores archived targets in reverse activation order
- Removes prepared targets only after restoration succeeds
- Preserves logs and failure state
- Marks the transaction recovered after the installed framework is consistent
- Reinstalls or repairs the namespace where needed
- Runs a health check after recovery

## Signal Handling

During the activation transaction, traps are installed for:

- `EXIT` — normal exit
- `INT` — Ctrl+C
- `TERM` — termination
- `HUP` — hangup

The handler:
- Determines whether activation began
- Avoids recursive invocation
- Preserves the original exit or signal result
- Attempts reverse-order restoration of activated targets
- Never deletes the only valid archived target
- Retains transaction state if automatic restoration fails

## State File Paths

| File | Purpose |
|------|---------|
| `~/.local/state/artix-hypr-remix/framework-update.log` | Update and rollback log |
| `~/.local/state/artix-hypr-remix/framework-backups/` | Timestamped backup directories |
| `~/.local/state/artix-hypr-remix/framework-transactions/` | Per-transaction state (key=value, never sourced) |
| `~/.local/state/artix-hypr-remix/migrations/` | Applied migration markers |
| `~/.local/state/artix-hypr-remix/migrations/skipped/` | Skipped migration markers |
| `~/.cache/artix-hypr-remix/framework-remote.cache` | Version/commit cache |
| `~/.local/state/artix-hypr-remix/framework.lock` | Framework update lock |

## Transaction State Schema

Each transaction lives in `framework-transactions/tx-XXXXXXXX/state`. Records
are merged atomically: required keys must be present at all times. The
parser never evaluates state as shell and rejects duplicate keys, missing
required fields, multiline values, or unknown format versions.

Required keys:

| Key | Purpose |
|-----|---------|
| `format_version` | Always `1` |
| `txid` | Transaction directory name |
| `action` | `apply` or `rollback` |
| `pid` | Originating process |
| `target_version` | Selected framework version |
| `staging_commit` | Pinned Git commit |
| `backup_dir` | Backup used for rollback |
| `phase` | Current phase (see below) |
| `completion` | `in_progress`, `committed`, `rolled_back`, `recovered`, `abandoned`, or a failure marker |

Per-target keys (recorded as activation progresses):

| Key | Purpose |
|-----|---------|
| `prepared_<target>` | Temp directory holding the staged target |
| `archived_<target>` | Archived installed target before replacement |
| `activated_<target>` | `true` once the target has been moved into place |
| `current_target` | Last target in progress |

Failure and recovery keys:

| Key | Purpose |
|-----|---------|
| `added_markers` | Pipe-separated list of new migration markers |
| `migration_exit` | Last `migrate.sh` exit code |
| `doctor_exit` | Last `ahr-doctor` exit code |
| `failure_reason` | Short token describing the failure |
| `recovery_command` | Suggested next command |

Phases emitted: `created`, `backup_in_progress`, `snapshot_failed`, `activation_in_progress`,
`activation_complete`, `migration`, `migration_failed`, `health_check`,
`health_check_failed`, `rollback_in_progress`, `rolled_back`,
`recovery_failed`. A failed required snapshot is retained as
`phase=snapshot_failed`, `completion=failed`, with an incomplete primary
manifest (`completed=in_progress`); no framework activation has occurred.
`--recover` marks that pre-activation transaction recovered without rollback,
while `--rollback` rejects its incomplete backup. A failed migration or health
check leaves `completion=*_failed` so the next `apply` or `rollback` refuses
to start and `--recover` can inspect the state.

## Exit Codes

| Mode | Exit 0 | Exit 1 |
|------|--------|--------|
| `--status` | Success | No metadata |
| `--check` | Update available | Up to date, no update source, or check failed |
| `--dry-run` | Update available, valid | Up to date or validation failed |
| `--apply` | Success | Any phase failed (validation, backup, activation, migration, health check) |
| `--rollback` | Success | No backup, backup incomplete, or rollback failed |
| `--recover` | Recovery succeeded | No incomplete transaction or recovery failed |

A failed migration or health check leaves `completion=migration_failed` or
`completion=health_check_failed` in the transaction state. A subsequent
`--apply` or `--rollback` refuses to start while the failure is unresolved;
use `--recover` to inspect, or `ahr-update-framework --rollback` after
reviewing the log.

### Validation-only backup failure hook

`AHR_TEST_FAIL_BACKUP=1` is a process-local validation hook. It is never
persisted and accepts only the exact value `1`. After staging and ordinary
backup/snapshot work have completed, it forces the existing required-snapshot
failure path before the primary backup manifest is completed or any framework
activation begins. It logs `TEST FAULT: forcing backup failure` and records
`failure_reason=test_fault_forced_backup_failure`.

The hook does not select paths, components, commands, or exit codes, and does
not intentionally corrupt host files. It is intended only for containment and
recovery validation: the candidate framework must never activate, namespace
installation, runtime smoke, migrations, and doctor must not run, and the
retained incomplete backup must not be used for rollback. The ordinary
pre-activation recovery contract applies: `--recover` marks the failed
transaction recovered; `--rollback` rejects the incomplete backup.

## Version Format

```
MAJOR.MINOR.PATCH
MAJOR.MINOR.PATCH-prerelease
```

- Numeric components have no leading zeros (except literal `0`)
- Prerelease is dot-separated non-empty alphanumeric identifiers
- Numeric prerelease identifiers compare numerically
- Numeric identifiers sort before non-numeric
- A release sorts after its prereleases
- Empty or malformed versions are rejected before comparison

## Backup Retention

Backups are retained indefinitely. Manual cleanup:

```bash
rm -rf ~/.local/state/artix-hypr-remix/framework-backups/<timestamp>-<id>
```

## Fedora Development vs Artix Validation

The framework is developed and tested on Fedora using:

- Temporary `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`
- Local Git repositories
- Controlled test doubles for `ahr-doctor`

Artix validation requires:

- `/etc/artix-release` present
- Real `ahr-doctor` with Artix services
- OpenRC, pacman, vercmp
- Live AHR user environment

Use `scripts/validate-framework-update-artix.sh` for Artix validation.
The script refuses `--apply-test` on non-Artix hosts and installs
restoration traps before any mutation.
