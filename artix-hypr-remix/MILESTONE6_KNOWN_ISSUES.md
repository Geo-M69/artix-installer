# Known issues & troubleshooting (Milestone 6 draft)

This document collects the primary known issues, caveats, and recommended starting troubleshooting commands for the beta release.

Key known issues

- Real-host validation is limited. The project needs at least one validated host per GPU profile (intel, amd, nvidia) and one laptop snapshot.
- `greetd` mode: present but not exhaustively validated across greeter/autologin variants — test carefully before claiming broad support.
- Theme gallery and previews: rich theme gallery and previews are deferred to future work.
- Wallpaper / background symlink: `~/.config/artix-hypr-remix/current/background` is not created during install; `ahr repair` reports it as missing. Theme falls back to solid color until a background image is manually set or the symlink workflow is completed in a future update.
- `ahr repair --config` is detect-only at present and will not rewrite user-edited config automatically.
- Optional AUR tools (Walker, Elephant) are not required; absence triggers warnings in smoke checks but should not block base install. See "AUR tool fallback behavior" below.
- Post-install smoke checks are session-aware and will skip runtime-only assertions when a Hyprland session is not active.
- Package availability depends on live Artix repos and selected package profiles — unexpected package name differences may appear on some mirrors.

Quick troubleshooting commands

```bash
# Quality gate and smoke
./scripts/quality-gate.sh --no-aur
AHR_HOST_POLICY=vm ./scripts/smoke-framework.sh

# Check hardware snapshot
./scripts/check-hardware.sh /tmp/hardware-profile.json

# Doctor and repair
./scripts/doctor.sh --no-aur
ahr repair        # dry-run
ahr repair --apply

# Migration and update helpers
ahr migrate --status
ahr migrate --retry-skipped
ahr update --dry-run
```

---

## AUR tool fallback behavior

Some features rely on optional AUR packages that are not installed in a `--skip-aur` or no-AUR setup. Here is how each tool behaves when missing:

| AUR tool | Required by | Fallback behavior |
|----------|-------------|-------------------|
| `walker` (launcher) | `ahr-launch-apps`, `ahr-menu` | Falls back to `wofi` → `rofi` → shows a non-fatal error message |
| `walker` (clipboard) | `ahr-clipboard-picker` | Falls back to `wofi` → `rofi` for the picker dialog |
| `elephant` (clipboard manager) | Autostart in Hyprland | `ahr-optional-elephant` checks and skips silently if not installed; clipboard history still works via `cliphist` + `wl-paste` |
| `walker` (keybindings) | `ahr-menu-keybindings` | Falls back to printing keybindings to terminal instead of walker's dmenu |

**Bottom line:** The base desktop (Waybar, Mako, Hyprland, audio, screenshot, lock, idle, terminal, browser, file manager) works without any AUR packages. AUR tools only add convenience — launcher UI, graphical clipboard picker, Elephant clipboard UI/integration.

If you hit a missing command dependency
- Re-run `./scripts/check-config-deps.sh` to get the mapping between required commands and package manifests.

If a first-run task fails in Hyprland
- Inspect user state: `~/.local/state/artix-hypr-remix/first-run.tasks`
- Re-run first-run hook: `~/.config/artix-hypr-remix/bin/first-run.sh` (as the target user) or reboot to run cleanly on next login.

---

## Intentionally deferred features (post-beta)

The following Omarchy UX features are recognized as desirable but explicitly deferred until after the beta release:

| Feature | Reason |
|---------|--------|
| Night-light / wl-gammarelay toggles | Needs OpenRC service integration and testing |
| Gaps, layout, corners style toggles | Not critical for first beta; can be added as `ahr theme` sub-commands later |
| OCR, color picker, audio/webcam recording in capture menu | Each requires new tooling; scope is too broad for beta |
| Notification timers / reminders | Lightweight implementation possible, but not a beta blocker |
| Transcode workflow | Depends on ffmpeg or similar; use-case is narrow |
| LocalSend / share workflow | Needs network discovery; out of scope for beta |
| Top-bar toggle parity | Current Waybar toggle is sufficient for beta; additional parity tracked separately |

Where to gather logs for a validation bundle
- `/var/log/artix-hypr-remix-install.log`
- `/var/lib/artix-hypr-remix/hardware-profile.json`
- `~/.local/state/artix-hypr-remix/` (migrations, first-run state)

Contact and reporting
- For inclusion in the beta validation matrix, attach validation bundles to the issue or release that created the beta tag and include host/gpu/startup-mode metadata.
