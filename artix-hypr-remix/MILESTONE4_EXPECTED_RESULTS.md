# Milestone 4 Expected Results

This is the beta tester "what good looks like" checklist for the Omarchy-like UX pass.

## First Login

After install and reboot, a supported Artix OpenRC host should land in a usable Hyprland session through the selected startup mode:

- `tty`: login shell starts the shared AHR Hyprland session launcher.
- `greetd`: greeter or autologin starts the same shared AHR Hyprland session launcher.
- The first-run welcome notification appears once and points to `Super+Space`, `Super+K`, and `Super+Return`.
- First-run tasks are idempotent; rerunning first-run should not spam the user or corrupt state.

## Core Desktop

Expected visible/runtime behavior:

- Waybar is visible unless intentionally toggled off.
- Mako notifications work and can be silenced or restarted through the menu.
- Wallpaper/background state is present, even if the fallback is theme color instead of an image.
- The active theme is recorded under `~/.config/artix-hypr-remix/current`.
- Audio services are available through PipeWire and WirePlumber.
- Screenshot tooling can take an area capture.
- Screen recording can be toggled when the required runtime tools are installed.
- The lock path works through the configured lock helper.

## Discoverability

Expected user paths:

- `Super+Space` opens the AHR menu.
- `Super+K` opens keybinding help.
- `Super+Return` opens the default terminal.
- `Applications` opens the app launcher using the available backend.
- `Learn` exposes keybindings, quick reference, theme asset guide, command help, theme help, and update help.
- `Trigger` exposes capture and toggle actions.
- `Style` exposes theme status, theme set, background next, background path set, theme refresh, Waybar restart/toggle, and Mako restart.
- `Setup` focuses on audio, network, Bluetooth, default browser, default terminal, and launcher restart.
- `Update` explains system/AUR/Flatpak/migration scope before running update actions.

## Theme Workflow

Expected commands:

```bash
ahr theme list
ahr theme current
ahr theme set artix-dark
ahr theme bg-next
ahr theme bg-set /path/to/image
ahr theme refresh
```

Expected result:

- Theme selection persists across sessions.
- Background selection persists through `~/.config/artix-hypr-remix/current/background`.
- Omarchy-compatible theme directories are discoverable when present.
- Rich previews, theme gallery behavior, and theme install/update/remove are not Milestone 4 blockers.

## Update Workflow

Expected commands:

```bash
ahr update-available
ahr update-available --json
ahr update --dry-run
ahr update
ahr update --flatpak
ahr update --migrations-only
ahr migrate --status
ahr migrate --retry-skipped
```

Expected result:

- `ahr update-available` uses exit code `0` when work is pending and `1` when nothing is pending.
- Human output explains system package, AUR package, pending migration, and skipped migration counts.
- JSON output includes `system`, `aur`, `migrations`, `skipped_migrations`, `total`, and `pending`.
- Update logs are written under `~/.local/state/artix-hypr-remix/update.log`.

## Accepted Artix/OpenRC Differences

These are intentional and should not be treated as failed Omarchy parity:

- AHR uses OpenRC service control instead of systemd.
- AHR supports `tty` and optional `greetd`, not SDDM/UWSM/systemd session plumbing.
- AHR keeps Omarchy-compatible aliases only when the native AHR behavior is implemented and safe on Artix.
- Broad Omarchy install/remove categories are intentionally conservative in AHR.
- Web app, reminder, transcode, LocalSend share, rich theme gallery, and systemd-specific maintenance flows are deferred unless explicitly pulled into beta scope.

## Validation Notes

Recommended validation commands from `artix-hypr-remix/`:

```bash
./scripts/quality-gate.sh --no-aur
AHR_HOST_POLICY=any ./scripts/smoke-framework.sh
./scripts/post-install-smoke.sh --user <username>
```

Use real-session manual testing for menu, theme, wallpaper, notifications, Waybar, update prompts, and keybinding discoverability.
