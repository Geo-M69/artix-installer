# Milestone 5 Kickoff Checklist (Maintenance, Repair, And Upgrades)

Milestone 5 turns the Milestone 4 UX foundation into a desktop that can explain and repair common drift.

## Current Baseline

- Milestone 4 alpha is complete for the current scope.
- The desktop has a coherent Learn/Trigger/Style/Setup/Update menu structure.
- Theme, update, migration, command namespace, and first-run state all exist, but repair guidance is mostly manual.
- `doctor`, `post-install-smoke`, `ahr update`, and `ahr migrate` can detect problems, but they do not yet offer a guided repair path.

Primary handoff:

- `MILESTONE5_HANDOFF.md`

## Milestone 5 Goals

- Add safe repair/reapply workflows for common drift and partial installs.
- Improve update and migration recovery messaging.
- Make doctor/smoke checks suggest next actions, not only pass/fail state.
- Document rollback/reset expectations without promising full uninstall.
- Keep every repair action previewable before it changes files.

## Workstream A: Repair Entry Point

### A1. Initial `ahr repair` command

- [x] Add a user-facing `ahr repair` command.
- [x] Support dry-run by default and explicit `--apply` for changes.
- [x] Check command namespace links and rerun namespace install when applying.
- [x] Check theme state and reapply a safe default theme when applying.
- [x] Check installed docs, migration state, skipped migrations, and update lock hints.

Exit criteria:

- A user can run `ahr repair` to see what can be fixed and `ahr repair --apply` to perform safe first-pass repairs.

### A2. Repair coverage expansion

- [x] Add scoped repair modes if needed, such as `--namespace`, `--theme`, `--migrations`, or `--all`.
- [x] Add config drift checks that distinguish framework-managed files from user edits.
- [x] Preserve timestamp backups for any future config rewrite action.
- [x] Keep repair output short enough to act on.

Progress note:

- `ahr repair` now supports scoped checks: `--all`, `--namespace`, `--theme`, `--docs`, `--migrations`, `--update-state`, and `--config`.
- Config repair is detect-only for now: it checks core managed config files and reports existing phase-4 `.bak.<timestamp>` backups, but does not rewrite user config yet.
- Future config rewrite actions must preserve timestamp backups before replacing files.

Exit criteria:

- Repair handles common drift without becoming a disguised reinstall.

## Workstream B: Doctor And Smoke Guidance

### B1. Doctor suggestions

- [x] Make `doctor` suggest relevant `ahr repair` actions for known failures.
- [x] Keep host-policy behavior unchanged.
- [x] Avoid failing headless/SSH validation for runtime-session-only checks.

Progress note:

- `doctor` now suggests `ahr-repair` preview/apply commands when framework command deployment checks fail, while keeping host-policy and runtime-check behavior unchanged.

Exit criteria:

- A failed doctor run tells the user what to try next.

### B2. Post-install smoke readiness checks

- [x] Add checks for installed docs and keybinding/menu discoverability.
- [x] Add checks for command namespace repair suggestions when links are missing.
- [x] Keep session-process checks conditional.

Progress note:

- `post-install-smoke.sh` now checks the installed quick reference and theme asset guide, requires the menu/keybinding/repair commands, and points missing namespace/doc failures toward scoped `ahr repair` commands.

Exit criteria:

- Smoke failures point to a specific repair or validation path.

## Workstream C: Update And Migration Recovery

### C1. Interrupted update guidance

- [x] Explain stale lock conditions without asking users to blindly remove files.
- [x] Point users to `~/.local/state/artix-hypr-remix/update.log`.
- [x] Add a guided recovery path if a previous update was interrupted.

Progress note:

- `ahr update` now writes update run/status markers under `~/.local/state/artix-hypr-remix` and points failures or lock conflicts to `update.log` plus `ahr repair --update-state`.
- `ahr repair --update-state` detects failed update status, stale interrupted run markers, and stale mkdir-style lock directories; `--apply` only removes stale markers when no active PID is found.

Exit criteria:

- Update failures have visible, actionable recovery guidance.

### C2. Skipped migration UX

- [x] Improve skipped migration reporting.
- [x] Add retry guidance beyond `ahr migrate --retry-skipped`.
- [x] Document migration policy for future config format changes.

Progress note:

- Migration status now lists skipped migration names and prints retry/dry-run guidance. Retry runs explicitly announce skipped migrations as they re-enter the pending set.
- Added `MIGRATION_POLICY.md` with migration naming, state, safety, recovery, and future config-format rules.

Exit criteria:

- Skipped migrations are understandable and recoverable.

## Workstream D: Release Readiness Notes

### D1. Rollback/reset expectations

- [x] Document what AHR can safely reapply.
- [x] Document what AHR will not uninstall/reset automatically.
- [x] Document where backups, logs, and state live.

Progress note:

- Added `RECOVERY_AND_RESET.md` to define safe reapply actions, detect-only areas, non-goals, backup locations, logs/state, and suggested recovery order.

Exit criteria:

- Users know the support boundary before running repair commands.

### D2. Known issues and unsupported items

- [x] Keep unsupported Omarchy parity items visible in release-facing docs.
- [x] Add known issues and troubleshooting notes.
- [x] Add beta checklist inputs for Milestone 6.

Progress note:

- Added `BETA_READINESS.md` with support target, known caveats, unsupported-for-now items, troubleshooting commands, and Milestone 6 checklist inputs.

Exit criteria:

- Milestone 6 can focus on release packaging and docs polish, not rediscovering maintenance gaps.

## Validation Commands

From `artix-hypr-remix/`:

```bash
./scripts/quality-gate.sh --no-aur
AHR_HOST_POLICY=any ./scripts/smoke-framework.sh
```

Installed-command dry-run:

```bash
ahr repair
ahr repair --apply
```

## Definition Of Milestone 5 Done

- `ahr repair` exists and handles safe first-pass repairs.
- Doctor/smoke output points users toward repair actions when possible.
- Update and migration recovery paths are documented and actionable.
- Rollback/reset support boundaries are documented.
- Milestone 6 release-readiness inputs are explicit.

Status: complete for the current Milestone 5 alpha scope.
