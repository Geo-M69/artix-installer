# Artix Hypr Remix Roadmap

## Target

Artix Hypr Remix aims to deliver an Artix Linux, OpenRC-native, Omarchy-equivalent Hyprland desktop that feels complete on first login: safe to install, opinionated, polished, portable across supported Artix systems, and maintainable without relying on systemd-only behavior.

## Supported Base System

- Distribution: Artix Linux
- Init/service manager: OpenRC
- Starting point: a working Artix base install with `pacman`, networking, and a non-root desktop user already created
- Privilege model: installer phases 1-8 run as root via `sudo`, while phases 4-8 target a non-root desktop user
- Supported shells: installer uses `bash`; desktop user shell support should cover `bash` and `zsh`
- Supported login/session flow: TTY launch by default, optional `greetd` flow when explicitly selected
- GPU assumptions: Intel/AMD/NVIDIA are supported through package/profile detection, but hardware-specific paths still need real Artix validation

## Out Of Scope For Beta

- ISO/profile distribution work
- Non-OpenRC init systems
- A line-for-line Omarchy clone
- Unsupported display managers beyond TTY and `greetd`
- Broad hardware promises beyond tested Intel/AMD/NVIDIA desktop and laptop paths

## Current Status

The repo is beyond a raw installer scaffold. Milestone 1 is mostly in place, Milestone 2 is partially implemented, and Milestone 3 has a usable foundation but not yet a dependable beta finish. In practice, the project appears to be in **early Milestone 3 alpha**: the phased installer, backup behavior, logging, startup-mode switching, first-run framework, and maintenance commands exist, but several user-facing runtime paths still need cleanup and the Omarchy-equivalent polish pass is not complete.

## Gap Analysis

- Installer safety: strong progress, but post-install validation should cover more real desktop readiness, not just package/config structure.
- Artix/OpenRC base layer: OpenRC service handling exists, but package naming and service assumptions still need live Artix verification.
- Desktop functionality: Hyprland, Waybar, Mako, PipeWire, screenshots, clipboard, theming, first-run, and update hooks are present, but some defaults still depend on optional components or incomplete fallbacks.
- Omarchy-like UX: partial parity only. The repo has the framework for menus, themes, hooks, and update tooling, but it still lacks a documented parity table and some of the “finished desktop” behavior Omarchy ships.
- Release readiness: README is useful, but supported assumptions, known issues, beta scope, and release criteria are not yet stated clearly enough.

## Fastest Path To Beta

1. Make the default TTY install path fully self-consistent with only repo-managed core packages.
2. Validate and tighten the OpenRC/session stack on real Artix systems.
3. Close first-login polish gaps: launcher behavior, clipboard flow, lock/idle/reboot actions, notifications, wallpaper/theme defaults, and update UX.
4. Freeze a supported beta matrix and document what is intentionally unsupported.

## Critical Blockers

- Default runtime paths still referenced optional AUR components directly instead of using safe fallbacks.
- At least one runtime helper still contained `loginctl`/`systemctl` fallbacks, which conflicts with the OpenRC target.
- Omarchy parity is not yet documented feature-by-feature, so it is hard to tell what is intentionally different versus unfinished.
- Hardware package names and service assumptions need validation on real Artix installs before the project can claim reliable support.

## Omarchy Parity Snapshot

| Area | Status | Classification | Notes |
| --- | --- | --- | --- |
| Hyprland + Waybar + Mako core desktop | Present | Required parity | Core desktop stack exists and is already wired into installer phases. |
| TTY-first login flow | Present | Artix/OpenRC adaptation | Uses OpenRC-native startup instead of Omarchy's Arch/systemd assumptions. |
| `greetd` startup option | Present | Artix/OpenRC adaptation | Reasonable replacement for display-manager flow; still needs broader testing. |
| Theme engine + command namespace | Present | Optional polish | Good foundation, but needs more end-user polish validation. |
| Walker/Elephant assistant workflow | Partial | Optional polish | Supported, but should never be required for the base install to function. |
| Update + migration framework | Present | Required parity | Repo already has `ahr update`, `ahr migrate`, and hook wiring. |
| Web app / extended app workflow | Mostly absent | Unsupported for now | Not a beta blocker unless intentionally adopted. |
| ISO/distribution workflow | Absent | Unsupported for now | Explicitly defer until script installer is solid. |

## Milestones

### Milestone 0: Define the target and support contract

- Publish the target statement in README and release notes.
- Document the supported base install assumptions.
- State supported session flows (`tty`, `greetd`) and supported shell expectations.
- Publish an explicit beta support matrix and “unsupported for now” list.

### Milestone 1: Make the installer safe and repeatable

- Keep `set -euo pipefail`, explicit logging, and phase state markers as the baseline.
- Expand preflight checks to include desktop-user/home/path sanity and clearer remediation text.
- Keep root-level actions separate from user-level config deployment.
- Preserve backup-before-overwrite behavior and ensure re-runs remain safe.
- Extend post-install validation to cover functional desktop checks, not only config presence.
- Audit every destructive or stateful action for explicit user intent.

### Milestone 2: Complete the Artix/OpenRC base layer

- Validate every package manifest on real Artix repositories.
- Resolve Arch/Omarchy package names into confirmed Artix equivalents where needed.
- Confirm `dbus`, `elogind`, networking, Bluetooth, polkit, portals, and printing flows on real hosts.
- Validate `rc-update`/`rc-service` behavior for each declared service.
- Remove or guard any remaining systemd/logind-only runtime assumptions.
- Add service-specific checks to doctor/post-install validation.

### Milestone 3: Complete Hyprland desktop functionality

- Make launcher and clipboard flows work with core packages even when optional AUR extras are absent.
- Validate Hyprland launch, `xdg-desktop-portal-hyprland`, PipeWire, WirePlumber, and screen capture paths.
- Tighten lock, idle, wallpaper, browser, terminal, file manager, and default app behavior.
- Ensure fonts, icons, cursor, and theme state are coherent on first login.
- Validate autostart ordering and environment variables in both `tty` and `greetd` modes.

### Milestone 4: Match Omarchy-like user experience

- Build a full parity table against Omarchy feature-by-feature.
- Mark each difference as required parity, Artix/OpenRC adaptation, optional polish, intentional difference, unsupported for now, or unknown.
- Port only the UX patterns that improve completeness without importing systemd assumptions.
- Make first login feel fully configured rather than “framework installed.”

### Milestone 5: Maintenance, repair, and upgrades

- Strengthen `doctor`, `post-install-smoke`, `ahr update`, and `ahr migrate`.
- Add a repair/reapply workflow for config drift and partial installs.
- Add migration policy notes for future config format changes.
- Document safe rollback/reset expectations even if full uninstall remains unsupported.

### Milestone 6: Documentation and release readiness

- Rewrite README around supported starting point, install path, and validation workflow.
- Add known issues, compatibility notes, and troubleshooting.
- Add screenshots or a concise expected-results section.
- Publish a beta checklist and release checklist.

### Milestone 7: Optional future distribution work

- Decide whether to stay script-first or eventually ship an Artix profile/ISO.
- Document ISO requirements only after the script installer is reliable.

## Prioritized Task List

1. Remove optional/AUR-only assumptions from default runtime paths.
2. Remove remaining systemd/logind runtime fallbacks.
3. Validate phase 2 and phase 3 package/service manifests on real Artix systems.
4. Expand post-install smoke checks to assert launcher, portal, PipeWire, and lock-screen readiness.
5. Write the full Omarchy parity table.
6. Tighten README and release notes around supported assumptions and beta scope.

## Definition Of Done

- Default install works on a supported Artix OpenRC base system without manual post-fix steps.
- Re-running the installer is safe and does not destroy user config without backup.
- Required OpenRC services are enabled and verified through OpenRC-native tooling only.
- TTY startup works reliably; `greetd` mode also works when selected.
- First login starts a usable Hyprland session with launcher, notifications, audio, clipboard, screenshots, idle/lock, wallpaper, and Waybar functioning.
- Optional AUR integrations enhance the desktop but are never required for the base experience.
- Update, migration, doctor, and smoke tooling can detect and repair common drift.
- README, compatibility notes, known issues, and release checklist are present.

