# Recovery And Reset Boundaries

This document defines what Artix Hypr Remix can safely repair and what it intentionally does not reset or uninstall.

## Safe Reapply Actions

These actions are supported as first-pass repair paths:

- Reinstall command namespace links with `ahr repair --namespace --apply`.
- Restore missing theme state with `ahr repair --theme --apply`.
- Check installed docs with `ahr repair --docs`.
- Inspect migration state with `ahr repair --migrations` and `ahr migrate --status`.
- Retry skipped migrations with `ahr migrate --retry-skipped` after reviewing logs.
- Inspect interrupted update state with `ahr repair --update-state`.
- Remove stale update run markers or mkdir-style lock directories with `ahr repair --update-state --apply` only when no active update PID is found.
- Detect core managed config presence with `ahr repair --config` (detect-only — see below).
- Inspect startup mode state with `ahr repair --startup`.
- View install state summary and log paths with `ahr status`.
- List config backups created by installer phase 4 with `ahr list-backups`.
- Collect a diagnostics bundle for sharing with `sudo ./scripts/collect-validation-bundle.sh`.

## Framework Update And Rollback

AHR supports safe framework updates with a documented rollback path:

- Preview a framework update without changes: `ahr update-framework --dry-run`
- Apply a framework update with backup: `ahr update-framework --apply`
- Rollback the last framework update: `ahr update-framework --rollback`
- Recover from an interrupted transaction: `ahr update-framework --recover`
- Apply framework updates through the general update command: `ahr update --framework`
- Restore a managed-derived component: `ahr restore-component <name> --from-last-update [--apply]`
- List supported components: `ahr restore-component --list`

An update whose migration or health check fails remains an unresolved
transaction and blocks another apply. Use `ahr update-framework --recover` to
inspect interrupted activation. For migration or health-check failures, review
the log and normally use `ahr update-framework --rollback`.

Framework updates create timestamped backups under
`~/.local/state/artix-hypr-remix/framework-backups/` before activation.  Each
backup contains the previous `bin/`, `migrations/`, `docs/`, `hooks/`,
`first-run.d/`, `default/`, `framework.json`, a snapshot of the migration
state directory, and a manifest with a completion marker.

### Non-Atomic Portions

Activation is the critical point: once framework files are replaced, the
system is running the new version.  The subsequent namespace install,
migration, and health check phases are sequential operations that run after
activation.  If any of these fail, the framework is already activated but may
be in a partially configured state.  The state file records the phase where
failure occurred so you can diagnose and recover.

### Backup Retention

Backups are retained manually.  There is no automatic cleanup.  Remove older
backups once the current framework version has been validated:

```bash
rm -rf ~/.local/state/artix-hypr-remix/framework-backups/<timestamp>/
```

### Missing or Corrupt Backup

If the backup directory is missing or the manifest is incomplete (missing the
`completed=true` marker), rollback cannot proceed.  The operation exits with
an error identifying the missing or corrupt backup.

Recovery options:

1. Re-apply the framework update: `ahr update-framework --apply`
2. As a last resort, re-run installer phase 7:
   `sudo ./install.sh --phase 7 --user <username> -y`

### Repeated Rollback

Rollback is limited to one level.  If the last action was already a rollback
(`action=rollback` in the state file), a second rollback is refused.  To move
to a different version after a rollback, apply a new update:

```bash
ahr update-framework --apply
```

### Migration Side Effects

Rollback restores migration marker state to what it was before the
rolled-back update.  Markers added by the update are removed; pre-existing
markers are preserved; skipped markers are restored from the snapshot.

However, rollback does not reverse arbitrary side effects of migrations.  If
a migration created files outside the migration state directory, modified
system configuration, or changed user settings, those changes persist after
rollback.  Only the marker files are managed.

### Concrete Recovery Commands

```bash
# Preview what an update would change
ahr update-framework --dry-run

# Apply a framework update (creates backup automatically)
ahr update-framework --apply

# Rollback the last framework update
ahr update-framework --rollback

# Check current framework version and last action
ahr update-framework --status

# Review update and rollback log
cat ~/.local/state/artix-hypr-remix/framework-update.log

# Inspect update state after failure
cat ~/.local/state/artix-hypr-remix/framework-update-state

# List available backups
ls ~/.local/state/artix-hypr-remix/framework-backups/

# Run health checks manually
ahr doctor

# Attempt automated repairs
ahr repair --dry-run
ahr repair --apply

# Reinstall command namespace only
ahr repair --namespace --apply

# Re-run installer phase 7 as last resort
sudo ./install.sh --phase 7 --user <username> -y
```

For full details, see `docs/FRAMEWORK_UPDATE.md`.

## Detect-Only Areas

These areas are intentionally detect-only and are not rewritten automatically:

- **Config drift detection** (`ahr repair --config`): Checks that key config files
  (Hyprland, Waybar, Mako) exist and reports previous backup timestamps. It will
  never rewrite user-edited config files. To restore source-deployed configs, use
  installer phase 4, which creates timestamped backups before replacing managed
  config roots:

  ```bash
  sudo ./install.sh --phase 4 --user <username> -y
  ```

- User-edited Hyprland, Waybar, Mako, terminal, shell, and app config files.
- Broad config drift where AHR cannot distinguish user preference from breakage.
- Hardware-specific service/module changes after install.
- Package-set changes outside the normal installer/update phases.

## Not A Full Reset Or Uninstall

AHR does not currently provide a full uninstall/reset command. Repair commands will not:

- Remove packages installed by pacman, AUR helpers, or Flatpak.
- Disable OpenRC services broadly.
- Delete user data.
- Remove user-created themes, backgrounds, browser profiles, shell history, project files, or app data.
- Restore every file under `~/.config` to repository defaults.
- Remove Omarchy-compatible aliases unless namespace behavior changes in a future migration.

## Backup Locations

Important backup patterns:

- Phase 4 config backups: `~/.config/<name>.bak.<timestamp>`
- Development baseline one-time backups: `~/.ssh/config.ahr-dev-baseline.bak`, `~/.gnupg/gpg.conf.ahr-dev-baseline.bak`, and `~/.gnupg/gpg-agent.conf.ahr-dev-baseline.bak`
- Installer phase markers: `/var/lib/artix-hypr-remix/install-state`

Do not delete backups until the repaired session has been validated.

## Logs And State

Important logs and state:

- Installer log: `/var/log/artix-hypr-remix-install.log`
- Installer fallback log: `/tmp/artix-hypr-remix-install.log`
- First-run state: `~/.local/state/artix-hypr-remix/first-run.*`
- Migration state: `~/.local/state/artix-hypr-remix/migrations`
- Migration log: `~/.local/state/artix-hypr-remix/migrations/migrate.log`
- Update log: `~/.local/state/artix-hypr-remix/framework-update.log`
- Update state: `~/.local/state/artix-hypr-remix/framework-update-state`
- Update lock: `~/.local/state/artix-hypr-remix/framework.lock` or `~/.local/state/artix-hypr-remix/.framework.lock/`
- Remote version cache: `~/.local/state/artix-hypr-remix/framework-remote.cache`
- Startup mode state: `~/.local/state/artix-hypr-remix/startup.mode`
- Current theme state: `~/.config/artix-hypr-remix/current`

## Suggested Recovery Order

1. Run `ahr status` to quickly check install state, log paths, and config backup count.
2. Run `ahr repair` as the desktop user and review the `FIX:` lines.
3. Run scoped repair commands first, such as `ahr repair --namespace --apply` or `ahr repair --theme --apply`.
4. Run `ahr migrate --status` and `ahr migrate --dry-run`.
5. Retry skipped migrations only after reviewing `migrate.log`. Use `ahr repair --migrations` for guided steps.
6. Use installer phase 4 only when source-deployed config files are missing or badly drifted.
7. Run `./scripts/post-install-smoke.sh --user <username>` after repair on a real host.
8. If sharing diagnostics, collect a bundle: `sudo ./scripts/collect-validation-bundle.sh`.
