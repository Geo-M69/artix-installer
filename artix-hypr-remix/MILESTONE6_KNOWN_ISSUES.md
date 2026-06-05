# Known issues & troubleshooting (Milestone 6 draft)

This document collects the primary known issues, caveats, and recommended starting troubleshooting commands for the beta release.

Key known issues

- Real-host validation is limited. The project needs at least one validated host per GPU profile (intel, amd, nvidia) and one laptop snapshot.
- `greetd` mode: present but not exhaustively validated across greeter/autologin variants — test carefully before claiming broad support.
- Theme gallery and previews: rich theme gallery and previews are deferred to future work.
- Wallpaper / background symlink: `~/.config/artix-hypr-remix/current/background` is not created during install; `ahr repair` reports it as missing. Theme falls back to solid color until a background image is manually set or the symlink workflow is completed in a future update.
- `ahr repair --config` is detect-only at present and will not rewrite user-edited config automatically.
- Optional AUR tools (Walker/Elephant) are not required; absence triggers warnings in smoke checks but should not block base install.
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

If you hit a missing command dependency
- Re-run `./scripts/check-config-deps.sh` to get the mapping between required commands and package manifests.

If a first-run task fails in Hyprland
- Inspect user state: `~/.local/state/artix-hypr-remix/first-run.tasks`
- Re-run first-run hook: `~/.config/artix-hypr-remix/bin/first-run.sh` (as the target user) or reboot to run cleanly on next login.

Where to gather logs for a validation bundle
- `/var/log/artix-hypr-remix-install.log`
- `/var/lib/artix-hypr-remix/hardware-profile.json`
- `~/.local/state/artix-hypr-remix/` (migrations, first-run state)

Contact and reporting
- For inclusion in the beta validation matrix, attach validation bundles to the issue or release that created the beta tag and include host/gpu/startup-mode metadata.
