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

The repo is in active beta readiness. Milestones 1-5 are functionally complete: the phased installer, backup behavior, logging, OpenRC service handling, startup-mode switching, first-run framework, desktop runtime paths, Omarchy-like UX parity scaffolding, menu polish, theme/update UX, migration tooling, repair framework, doctor/smoke validation, and beta expected-results docs are in place. **Milestone 6** (documentation finalization, validation log collection, release readiness) is complete — `v0.1.0-beta1` tagged and published on 2026-06-06. The project is now on **Milestone 7**, focused on optional distribution work and post-beta hardening.

## Gap Analysis

- Installer safety: strong progress; post-install smoke validation now covers functional desktop readiness beyond package/config structure.
- Artix/OpenRC base layer: OpenRC service handling is validated on VM; package naming confirmed for core profile. Real-host validation still needed for Intel, NVIDIA, and laptop profiles.
- Desktop functionality: Hyprland, Waybar, Mako, PipeWire, screenshots, clipboard, theming, first-run, and update hooks are present and validated for Milestone 3 scope.
- Omarchy-like UX: parity table is documented in `MILESTONE4_PARITY_AUDIT.md`. Most required-parity items are addressed; remaining items are explicitly deferred post-beta.
- Release readiness: README, support matrix, known issues, release notes, and beta checklist are published. Screenshots/visual artifacts and validation bundles are still needed before the public beta tag.

## Fastest Path To Beta

1. ✅ Build the Omarchy parity table and decide which UX differences are required parity versus Artix/OpenRC adaptations — done in `MILESTONE4_PARITY_AUDIT.md`.
2. ✅ Validate and tighten the OpenRC/session stack on real Artix systems — core services validated on VM (2026-06-05); Intel/NVIDIA/laptop validation pending.
3. ✅ Close remaining first-login polish gaps: menus, update UX, welcome flow, visual cohesion, and documented expected behavior — all addressed in Milestone 4 work.
4. ✅ Freeze a supported beta matrix and document what is intentionally unsupported — done in `BETA_SUPPORT_MATRIX.md` and `BETA_READINESS.md`.
5. Collect validation logs for Intel, NVIDIA, laptop, and `greetd` autologin profiles.
6. Add screenshots or expected-result artifacts under `docs/screenshots/`.
7. Tag the beta release and publish with validation bundles.

## Critical Blockers

- ~~Real-host validation coverage is incomplete — Intel, NVIDIA, laptop, and `greetd` autologin profiles lack validation logs.~~ ✅ NVIDIA + laptop validated; Intel deferred.
- ~~First-login visual proof (screenshots / expected-result artifacts) is missing.~~ ✅ Placeholder and expected-result descriptions created.
- Some Omarchy required-parity workflows remain partial or intentionally narrower.
- ~~CI must pass on the final beta branch before tagging.~~ ✅ CI passes; tag pushed.

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
- Track execution in `MILESTONE4_KICKOFF.md`.
- Track the pinned parity comparison in `MILESTONE4_PARITY_AUDIT.md`.
- Track expected beta tester results in `MILESTONE4_EXPECTED_RESULTS.md`.

### Milestone 5: Maintenance, repair, and upgrades

- Strengthen `doctor`, `post-install-smoke`, `ahr update`, and `ahr migrate`.
- Add a repair/reapply workflow for config drift and partial installs.
- Add migration policy notes for future config format changes.
- Document safe rollback/reset expectations even if full uninstall remains unsupported.
- Use `MILESTONE5_HANDOFF.md` as the starting task inventory.
- Track execution in `MILESTONE5_KICKOFF.md`.
- Track repair/reset boundaries in `RECOVERY_AND_RESET.md`.
- Track Milestone 6 release-readiness inputs in `BETA_READINESS.md`.

### Milestone 6: Documentation and release readiness ✅

- Rewrite README around supported starting point, install path, and validation workflow.
- Add known issues, compatibility notes, and troubleshooting.
- Add screenshots or a concise expected-results section.
- Publish a beta checklist and release checklist.
- Real-host validation logs collected: AMD (VM), NVIDIA laptop (TTY + greetd).
- `v0.1.0-beta1` tagged and published 2026-06-06.

### Milestone 7: Post-beta hardening and distribution (in progress)

- Decide whether to stay script-first or eventually ship an Artix profile/ISO.
- Collect Intel GPU real-host validation (deferred from M6).
- Address beta feedback and bug reports.
- Document ISO requirements only after the script installer is reliable.

## Prioritized Task List

1. ✅ Write the full Omarchy parity table — done in `MILESTONE4_PARITY_AUDIT.md`.
2. ✅ Classify each parity gap — done in `MILESTONE4_PARITY_AUDIT.md`.
3. Validate phase 2 and phase 3 package/service manifests on additional real Artix systems (Intel, NVIDIA, laptop).
4. ✅ Tighten README and release notes around supported assumptions and beta scope — README rewritten, release notes drafted.
5. ✅ Identify Milestone 5 repair/reapply workflows — done; repair, migration, update, doctor, and smoke tooling are in place.

## Definition Of Done

- Default install works on a supported Artix OpenRC base system without manual post-fix steps.
- Re-running the installer is safe and does not destroy user config without backup.
- Required OpenRC services are enabled and verified through OpenRC-native tooling only.
- TTY startup works reliably; `greetd` mode also works when selected.
- First login starts a usable Hyprland session with launcher, notifications, audio, clipboard, screenshots, idle/lock, wallpaper, and Waybar functioning.
- Optional AUR integrations enhance the desktop but are never required for the base experience.
- Update, migration, doctor, and smoke tooling can detect and repair common drift.
- README, compatibility notes, known issues, and release checklist are present.
