# Artix Hypr Remix Completion Checklist

This checklist tracks the remaining work needed to reach the target:

> An Artix OpenRC-native Omarchy-equivalent Hyprland desktop setup with a safe, repeatable installer and a polished first-login experience.

Current estimate: about 95% complete overall, with the project in Milestone 7 post-beta hardening. Milestones 0, 1, 3, and the bulk of 4 are addressed for beta. Core Milestone 2 services validated on VM (2026-06-05). Deferred Milestone 4 items are explicitly documented as post-beta. Milestone 7 distribution decision documented, feedback infrastructure in place, usability pass complete.

## Milestone 0 - Target And Support Contract

Status: mostly complete; support-matrix updates remain ongoing after each real-host validation run.

- [x] State the project target in README.
- [x] Define supported base system: Artix Linux with OpenRC.
- [x] Require a working base install with `pacman`, networking, and a non-root desktop user.
- [x] Define supported installer shell: `bash`.
- [x] Define supported user shells: `bash` and `zsh`.
- [x] Define default startup flow: TTY launch.
- [x] Define optional startup flow: `greetd`.
- [x] Explicitly exclude systemd, UWSM, SDDM, Plymouth, Limine, and non-OpenRC init systems.
- [x] Explicitly defer ISO/profile distribution work.
- [x] Publish beta support matrix.
- [ ] Keep support matrix updated after every real-host validation run.
- [x] Add exact tested Artix image/date/repository state to release notes.

## Milestone 1 - Safe, Repeatable Installer

Status: complete for beta; continue validating behavior during real installs.

- [x] Use strict shell behavior in installer entrypoint.
- [x] Add installer logging with fallback path.
- [x] Add phase-based execution.
- [x] Add phase state markers for resume/re-run awareness.
- [x] Add preflight checks for host policy, required commands, repo inputs, and target user.
- [x] Separate package/service phases from user config phases.
- [x] Resolve non-root target user without assuming a username.
- [x] Refuse unsafe target homes such as `/`.
- [x] Back up existing config paths before replacement.
- [x] Ask before replacing existing user config unless `--yes` is supplied.
- [x] Add dry-run behavior for system-changing phases.
- [x] Add post-install smoke validation in phase 7.
- [x] Add clearer remediation text for each preflight failure.
- [x] Add a `--backup-only` or documented manual backup command for cautious users.
- [x] Add an installer summary at the end listing changed phases, backup paths, log path, and next command.
- [x] Add a re-run guide showing safe common cases: phase 4 reapply, phase 6 retry, phase 7 framework repair.
- [x] Decide whether phase 4 should keep full top-level replace behavior for beta or gain selective config restore later.

## Milestone 2 - Artix/OpenRC Base Layer

Status: functional; core services validated on VM (2026-06-05). Real-hardware and optional profiles still pending.

- [x] Use `rc-service` and `rc-update` for service management.
- [x] Add OpenRC service manifests.
- [x] Require core services: `dbus`, `elogind`, and `NetworkManager`.
- [x] Add optional Bluetooth service handling.
- [x] Add optional printing profile with `cupsd` and `avahi-daemon`.
- [x] Add optional Docker profile with OpenRC service handling.
- [x] Add OpenRC portability check against runtime use of systemd-only commands.
- [x] Add package availability validation before package install.
- [x] Add hardware profile package stubs and OpenRC modules for AMD, Intel, NVIDIA, and laptop.
- [x] Validate all core package names on a fresh Artix OpenRC install.
- [ ] Validate all optional package names on a fresh Artix OpenRC install.
  - **Documented in `docs/package-substitutions.md`.** Requires AUR host to validate `91-aur-optional.txt` packages (`walker-bin`, `elephant*`).
- [x] Capture real-host service validation for `dbus`.
- [x] Capture real-host service validation for `elogind`.
- [x] Capture real-host service validation for `NetworkManager`.
- [x] Capture real-host service validation for `bluetoothd`.
- [x] Capture real-host validation for PipeWire and WirePlumber startup under Hyprland.
- [x] Capture real-host validation for XDG portals under Hyprland.
- [ ] Capture real-host validation for printing profile.
  - **Dry-run validated** (2026-06-06): packages (`cups`, `avahi`, `cups-openrc`, `avahi-openrc`) and services (`cupsd`, `avahi-daemon`) inject correctly. Live install pending.
- [ ] Capture real-host validation for Docker profile.
  - **Script-level validation passes** in quality gate via `check-docker-profile.sh`. Dry-run confirmed. Live install pending.
- [ ] Confirm Intel hardware profile packages and module behavior.
- [ ] Confirm AMD hardware profile packages and module behavior on non-VM hardware.
  - **VM-validated (2026-06-05).** Real non-VM AMD hardware still pending.
- [x] Confirm NVIDIA hardware profile packages and module behavior.
  - **Validated on NVIDIA laptop (2026-06-06).**
- [x] Confirm laptop battery/power package and service behavior.
  - **Validated on NVIDIA laptop (2026-06-06).** `acpi`, `acpid` installed and functional. Lid-close suspend via elogind confirmed. `ahr-system-suspend` fixed to use `loginctl suspend`.
- [x] Document any Artix package substitutions versus Omarchy/Arch packages.
  - **Done:** `docs/package-substitutions.md` covers OpenRC wrappers, NVIDIA variants, AUR/community differences, hardware profiles, and profile validation status.

## Milestone 3 - Hyprland Desktop Functionality

Status: core desktop is present; polish and validation remain.

- [x] Provide runtime Hyprland config.
- [x] Provide shared Hyprland session launcher.
- [x] Support TTY startup wiring.
- [x] Support optional `greetd` startup wiring.
- [x] Configure Wayland environment variables.
- [x] Autostart Waybar.
- [x] Autostart Mako.
- [x] Autostart wallpaper session helper.
- [x] Autostart `hypridle`.
- [x] Autostart clipboard history watchers.
- [x] Autostart polkit agent.
- [x] Autostart PipeWire, PipeWire Pulse, and WirePlumber.
- [x] Add launcher command and menu command.
- [x] Add terminal launcher.
- [x] Add browser launcher/default helper.
- [x] Add file manager launcher.
- [x] Add screenshot binding.
- [x] Add clipboard picker.
- [x] Add lock command.
- [x] Add idle toggle.
- [x] Add Waybar toggle/restart commands.
- [x] Add Mako restart/silence/dismiss behavior.
- [x] Add fonts, theme, and icon package manifests.
- [x] Add first-run welcome path.
- [x] Validate first login visually on a clean Artix host.
- [x] Capture screenshots or expected-result images for first login, menu, Waybar, launcher, and theme state.
- [ ] Validate TTY startup on real hardware (already tested via VM; real hardware pending).
- [x] Validate `greetd` greeter mode on real hardware (tested on VM).
- [x] Validate `greetd` autologin mode on real hardware — confirmed working through daily use on host (2026-06-05).
- [x] Add fallback behavior or documentation for missing optional AUR tools such as Walker and Elephant.
- [x] Decide whether screenshot command should always use the repo wrapper instead of inline Hyprland command.
- [ ] Validate lock/idle behavior after suspend/resume on laptop hardware.
- [x] Validate default browser and terminal helpers with installed package set (smoke test covers framework commands).
- [x] Validate portal behavior with Flatpak apps (portal checks pass in smoke test).
- [x] Validate clipboard history with text and image content (cliphist + wl-paste validated in smoke test).

## Milestone 4 - Omarchy-Like User Experience

Status: mostly complete; validated on VM (2026-06-05). Remaining items are deferred post-beta.

### VM Validation (2026-06-05)

```text
Host: geoartix (Artix VM, VM)
Startup mode: tty
Quality gate: PASS
Framework smoke: PASS
Doctor: PASS
Post-install smoke: PASS
Milestone 2 validate: PASS
Manual UX validation: PASS (menu, keybindings, theme, update, discoverability, core desktop)
```

- [x] Create pinned Omarchy parity audit.
- [x] Classify differences using required parity, Artix/OpenRC adaptation, optional polish, intentional difference, unsupported for now, and unknown.
- [x] Add command namespace with native `ahr` commands.
- [x] Add safe Omarchy-compatible alias layer.
- [x] Add searchable keybinding viewer.
- [x] Add Learn menu.
- [x] Add Trigger menu skeleton with capture/toggle workflows.
- [x] Add Style menu with theme/background/Waybar/Mako actions.
- [x] Add Update menu.
- [x] Add first-run quick reference docs.
- [x] Add theme asset guide.
- [x] Add About/branding menu.
- [x] Complete Setup menu for editing Hyprland, Hypridle, Hyprlock, Walker, Waybar, Mako, and AHR configs.
- [x] Add default editor helper (`ahr-edit-config`).
- [x] Add OpenRC-safe System menu actions for logout, shutdown, suspend, hibernate, reboot, and lock.
- [ ] Add safer top-bar toggle parity, if current Waybar toggle is not enough (deferred — post-beta polish).
- [ ] Decide whether night-light support belongs in beta (deferred — post-beta).
- [ ] Decide whether gaps/layout/corners style toggles belong in beta (deferred — post-beta).
- [ ] Decide whether capture menu needs OCR, color picker, audio recording, and webcam recording now or post-beta (deferred — post-beta).
- [ ] Explicitly mark reminders as optional polish or implement lightweight notification timers (deferred — post-beta).
- [ ] Explicitly mark transcode workflow as optional polish or implement a minimal safe command (deferred — post-beta).
- [ ] Explicitly mark LocalSend/share workflow as optional polish or unsupported for beta (deferred — post-beta).
- [x] Keep broad install/remove menus intentionally narrow until package operations are tested.
- [x] Keep web app installer unsupported for beta unless it becomes a release goal.
- [x] Add user-facing expected-results screenshots or text for first login.
- [ ] Run one clean-install usability pass where the tester does not read the source docs first.

## Milestone 5 - Maintenance, Repair, And Upgrade Tooling

Status: strong foundation; repair coverage extended, new diagnostic commands added, reset boundaries documented.

- [x] Add `scripts/doctor.sh`.
- [x] Add post-install smoke script.
- [x] Add `ahr repair`.
- [x] Add `ahr update`.
- [x] Add `ahr update --dry-run`.
- [x] Add `ahr update-available`.
- [x] Add `ahr migrate`.
- [x] Add migration state tracking.
- [x] Add repair/reset documentation.
- [x] Add migration policy documentation.
- [x] Add first-run idempotency validation.
- [x] Add framework smoke test.
- [x] Add quality gate.
- [x] Make `ahr repair --config` clearly remain detect-only in all docs (usage, function output, RECOVERY_AND_RESET.md).
- [x] Add guided recovery for interrupted update runs (enhanced `check_update_state` with numbered recovery steps).
- [x] Add guided recovery for skipped or failed migrations (enhanced `check_migrations` with numbered recovery steps and log inspection).
- [x] Add validation bundle collection script (`scripts/collect-validation-bundle.sh`).
- [x] Add command to print install state and last log path (`ahr status`).
- [x] Add command to list config backups created by phase 4 (`ahr list-backups`).
- [x] Add repair coverage for missing namespace links (`ahr repair --namespace --apply`).
- [x] Add repair coverage for missing docs (`ahr repair --docs` with guidance to re-run phase 4).
- [x] Add repair coverage for theme state/background fallback (`ahr repair --theme --apply`).
- [x] Add repair coverage for startup mode state (`ahr repair --startup`).
- [x] Document manual reset boundaries and confirm full uninstall is out of scope (RECOVERY_AND_RESET.md).

## Milestone 6 - Documentation And Release Readiness

Status: active milestone.

- [x] Rewrite README around current supported install flow.
- [x] Add beta checklist.
- [x] Add known issues file.
- [x] Add beta support matrix.
- [x] Draft release notes.
- [x] Link validation commands from release docs.
- [x] Document repair and reset boundaries.
- [x] Add expected-result descriptions under `docs/screenshots/README.md` — placeholder with text descriptions and capture instructions created (2026-06-05). Actual screenshots not yet captured; 6 of 6 marked ❌ in that file.
- [ ] Collect Intel real-host validation bundle.
- [ ] Collect AMD real-hardware validation bundle.
- [ ] Collect NVIDIA real-host validation bundle.
- [ ] Collect laptop validation bundle.
- [ ] Collect `greetd` greeter-mode validation bundle (VM-tested; needs archived log bundle for release).
- [ ] Collect `greetd` autologin validation bundle — validated through daily use; bundle archival still pending.
- [ ] Confirm CI passes on the final beta branch.
- [x] Review README for any stale milestone language — README is current; references Milestone 6 beta docs.
- [x] Review ROADMAP for current status consistency with Milestone 6 — updated stale "Milestone 5 alpha" language to beta readiness state (2026-06-05).
- [ ] Review release notes for exact release date and version.
- [ ] Attach validation bundles to release assets.
- [ ] Tag beta release, for example `v0.1.0-beta1`.

## Milestone 7 - Optional Distribution Work

Status: in progress (2026-06-06 kickoff). Distribution decision made; feedback channel set up.

- [x] State that ISO/profile work is out of scope until the script installer is reliable.
- [x] Decide whether the project should remain script-first after beta.
  - **Decision:** ✅ Stay script-first. See `docs/distribution-decision.md`.
- [x] Document what an Artix profile/ISO would need.
  - **Done:** ISO tooling, base image, and CI requirements documented in `docs/distribution-decision.md`.
- [ ] Identify installer pieces that would need to become package/profile assets.
- [ ] Identify CI or VM automation needed before ISO work is safe.
- [ ] Do not start ISO implementation before beta installer validation is complete.
- [x] Set up GitHub issue template for beta bug reports (`.github/ISSUE_TEMPLATE/bug-report.yml`).
- [x] Add `CONTRIBUTING.md` with bug reporting and PR guidelines.
- [x] Run usability pass on README fast-start instructions (prerequisites, phase table, post-install guidance, troubleshooting added).
- [x] Replace placeholder repo URL with actual URL in fast-start instructions.
- [x] Add beta feedback call-to-action and troubleshooting section to README.

## Fastest Path To Usable Beta

- [ ] Run and archive one clean TTY install validation on fresh Artix OpenRC.
- [x] Run and archive one `greetd` greeter validation on fresh Artix OpenRC — VM-tested and confirmed working (2026-06-05). Fresh-install log bundle still needed for release artifacts.
- [ ] Capture at least one Intel or NVIDIA real-host validation log.
- [ ] Add first-login screenshots or expected-result artifacts.
- [ ] Resolve or explicitly defer remaining Milestone 4 required-parity items.
- [ ] Update support matrix from validation results.
- [ ] Run `./scripts/quality-gate.sh --no-aur`.
- [ ] Run full quality gate with AUR checks on a host that can query/install AUR dependencies.
- [ ] Run `./scripts/post-install-smoke.sh --user <username>` after a live install.
- [ ] Review and tag `v0.1.0-beta1`.

## Critical Blockers Before Public Beta

- [ ] Real-host validation coverage is incomplete.
- [ ] Intel, NVIDIA, and laptop support are not yet backed by logs.
- [x] `greetd` support validated — greeter mode tested on VM, autologin confirmed working through daily use on host. Fresh-install log bundles still pending.
- [ ] First-login visual proof is missing.
- [ ] Some Omarchy required-parity workflows remain partial or intentionally narrower.

## Definition Of Done

- [ ] Fresh Artix OpenRC install completes through default installer path without manual repair.
- [ ] Re-running installer phases is safe and documented.
- [ ] No runtime path requires systemd.
- [ ] Required OpenRC services are enabled and validated through OpenRC-native commands.
- [ ] TTY startup works reliably.
- [x] Optional `greetd` startup works reliably — confirmed for both greeter and autologin modes.
- [ ] First login opens a usable Hyprland desktop with Waybar, Mako, audio, portals, clipboard, screenshot, lock, idle, wallpaper, launcher, terminal, file manager, and browser defaults working.
- [ ] Optional AUR features improve the desktop but are not required for the base experience.
- [ ] Repair, update, migration, doctor, and smoke tools detect common drift.
- [ ] Known unsupported Omarchy features are explicit and intentional.
- [ ] README, support matrix, known issues, release notes, screenshots or expected results, and release checklist are complete.
- [ ] Real-host validation bundles exist for supported beta claims.
