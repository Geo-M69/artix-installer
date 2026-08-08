# Artix Hypr Remix Quick Reference

This page is installed with the desktop framework and is meant as a first-login map.

## First Keys

- `Super + Space`: open the app launcher.
- `Super + Alt + Space`: open the AHR control menu.
- `Super + K`: show keybindings.
- `Super + Return`: open a terminal.
- `Super + Shift + Return`: open the default browser.
- `Super + Shift + F`: open files.
- `Super + Ctrl + L`: lock the session.
- `Print`: open screenshot picker (area/fullscreen/window).

## Menu Map

- `Applications`: open the app launcher.
- `Learn`: keybindings, command help, theme help, update help, theme asset notes, and this reference.
- `Trigger`: capture and toggle actions.
- `Style`: theme, wallpaper/background, Waybar, and Mako visual actions.
- `Setup`: audio, network, Bluetooth, defaults, and launcher service actions.
- `Install`: guarded package, Flatpak, Docker, and printing helpers.
- `Remove`: guarded package, Flatpak, Docker, and printing removal helpers.
- `Update`: system/AUR/Flatpak update and migration helpers.
- `System`: lock, logout, reboot, power off, terminal, screenshots, and recording.

## Themes

- List themes: `ahr theme list`
- Show current theme: `ahr theme current`
- Apply a theme: `ahr theme set nord`
- Cycle wallpaper/background: `ahr theme bg-next`
- Set a specific wallpaper/background: `ahr theme bg-set /path/to/image`
- Reapply current theme: `ahr theme refresh`

The `Style` menu exposes theme status, theme selection, background cycling, background path selection, and visual service restarts. Theme state is stored under `~/.config/artix-hypr-remix/current`; asset expectations are documented in the installed theme asset guide.

## Updates

- Check pending work: `ahr update-available`
- Machine-readable status: `ahr update-available --json`
- Run normal update: `ahr update`
- Include Flatpak apps: `ahr update --flatpak`
- Run migrations only: `ahr update --migrations-only`
- Preview actions: `ahr update --dry-run`

Update and migration state lives under `~/.local/state/artix-hypr-remix`.
Update logs live at `~/.local/state/artix-hypr-remix/update.log`.
Skipped migrations can be reviewed with `ahr migrate --status` and retried with `ahr migrate --retry-skipped`.

Framework backups created by current releases record both their backup ID and
the creating transaction ID. Recovery uses that exact association and refuses
to guess from timestamps or backup ordering. Older backups without association
metadata remain available only through an exact `ahr restore-component --backup
<id>` selection; they are not used for automatic transaction recovery.

## Health & Repair

- Show install state, logs, and backup hints: `ahr status`
- Check for fixable issues (safe, no changes): `ahr repair --dry-run`
- Full health report: `ahr doctor`
- Run idempotency checks: `scripts/check-first-run-idempotency.sh` (requires repo clone)
- List config backup snapshots: `ahr list-backups`

Repair actions require `--apply` and create timestamped backups before overwriting configs.

## Compatibility

Artix Hypr Remix provides an `ahr-*` command namespace and a small Omarchy-compatible alias layer. Omarchy commands are only aliased when they map to native OpenRC-safe behavior.

Use `ahr help` to see the current command list.
