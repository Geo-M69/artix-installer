# Beta Readiness Notes

This document collects release-facing known issues, unsupported items, and Milestone 6 checklist inputs.

`v0.1.0-beta1` shipped as the first public beta on 2026-06-06. The raised beta
bar for a final/refresh beta now requires live-session proof, real screenshots,
and validation bundles that match the published support claims.

## Beta Support Target

The beta target is a script-installed Artix OpenRC Hyprland desktop with:

- Fresh or minimal Artix OpenRC base install.
- Non-root desktop user already created.
- TTY startup by default, optional `greetd`.
- Core desktop flow: Hyprland, Waybar, Mako, PipeWire, WirePlumber, screenshots, lock/idle, wallpaper/theme state, launcher, terminal, browser defaults, menu, update, migrate, and repair helpers.
- Raised-bar proof: fresh TTY and `greetd` validation bundles, laptop
  suspend/resume validation, portal screen sharing validation, real first-login
  screenshots, live post-install smoke output, and support-matrix claims backed
  by archived logs.

## Known Issues And Caveats

- Real hardware validation is still limited; Intel/AMD/NVIDIA paths need more host logs before support claims can be strong.
- `greetd` support exists, but raised-bar readiness requires fresh greeter and
  autologin validation bundles.
- Laptop suspend/resume and browser/Flatpak screen sharing need explicit
  live-session validation.
- `ahr repair --config` is detect-only and does not rewrite user config.
- Rich remote theme preview remains deferred; local theme install/update/remove
  and background/gallery flows exist but need live-session validation.
- Optional AUR tools such as Walker and Elephant enhance the desktop but are not required for base success.
- Optional AUR tools must be tested both installed and absent so fallback paths
  are proven.
- Some post-install smoke checks are session-aware and only validate process health when Hyprland is running.
- Package availability depends on the live Artix repositories and selected package profiles.

## Unsupported For Now

- systemd, UWSM, SDDM, Plymouth, Limine, and other systemd/Arch-specific Omarchy maintenance paths.
- Non-OpenRC init systems.
- Display managers other than `greetd`.
- Full uninstall/reset command.
- ISO/profile distribution work.
- Web app installer.
- Reminder, transcode, and LocalSend share workflows.
- Rich remote theme preview/catalog workflow.
- Broad install/remove menus for gaming, Windows, AI, development stacks, or security tools.
- Hardware-specific toggles that have not been validated on real Artix hardware.

## Troubleshooting Starting Points

- General health: `./scripts/doctor.sh --no-aur`
- Post-install state: `./scripts/post-install-smoke.sh --user <username>`
- Repair preview: `ahr repair`
- Safe repair apply: `ahr repair --apply`
- Update recovery: `ahr repair --update-state`
- Migration status: `ahr migrate --status`
- Migration retry: `ahr migrate --retry-skipped`
- Theme recovery: `ahr repair --theme --apply`
- Namespace recovery: `ahr repair --namespace --apply`

See `RECOVERY_AND_RESET.md` for repair boundaries before using broad repair or installer reapply commands.

## Milestone 6 Checklist Inputs

- Write release-oriented install docs around the supported Artix OpenRC starting point.
- Add a concise beta checklist that references `MILESTONE4_EXPECTED_RESULTS.md`.
- Add known issues and troubleshooting to README or release notes.
- Add screenshots or visual validation examples after the desktop visuals stabilize.
- Freeze a beta support matrix for startup mode, hardware class, and optional profiles.
- Document rollback/reset boundaries using `RECOVERY_AND_RESET.md`.
- Keep unsupported Omarchy parity items explicit in release notes.
- Capture real-host validation logs for Intel, AMD, NVIDIA, laptop, TTY, and `greetd` modes.
- Replace placeholder screenshots with real first-login/menu screenshots before
  the raised-bar beta refresh.
- Validate default app/MIME behavior, capture workflows, portal screen sharing,
  suspend/resume, theme persistence, and optional-AUR fallback behavior in a live
  Hyprland session.
