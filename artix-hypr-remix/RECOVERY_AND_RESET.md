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
- Update log: `~/.local/state/artix-hypr-remix/update.log`
- Update status: `~/.local/state/artix-hypr-remix/update.status`
- Update run marker: `~/.local/state/artix-hypr-remix/update.run`
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
