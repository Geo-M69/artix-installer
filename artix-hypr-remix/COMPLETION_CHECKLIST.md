# Artix Hypr Remix Completion Checklist

This checklist tracks the remaining work needed to reach the target:

> An Artix OpenRC-native Omarchy-equivalent Hyprland desktop setup with a safe, repeatable installer and a polished first-login experience.

Current estimate: about 80% complete overall, with the project in Milestone 6 beta-readiness work. Milestone 1 is now addressed for beta; Milestone 0 has only the ongoing support-matrix update loop remaining.

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

Status: functional, but real-host validation is the main gap.

- [x] Use `rc-service` and `rc-update` for service management.
- [x] Add OpenRC service manifests.
- [x] Require core services: `dbus`, `elogind`, and `NetworkManager`.
- [x] Add optional Bluetooth service handling.
- [x] Add optional printing profile with `cupsd` and `avahi-daemon`.
- [x] Add optional Docker profile with OpenRC service handling.
- [x] Add OpenRC portability check against runtime use of systemd-only commands.
- [x] Add package availability validation before package install.
- [x] Add hardware profile package stubs and OpenRC modules for AMD, Intel, NVIDIA, and laptop.
- [ ] Validate all core package names on a fresh Artix OpenRC install.
- [ ] Validate all optional package names on a fresh Artix OpenRC install.
- [ ] Capture real-host service validation for `dbus`.
- [ ] Capture real-host service validation for `elogind`.
- [ ] Capture real-host service validation for `NetworkManager`.
- [ ] Capture real-host service validation for `bluetoothd`.
- [ ] Capture real-host validation for PipeWire and WirePlumber startup under Hyprland.
- [ ] Capture real-host validation for XDG portals under Hyprland.
- [ ] Capture real-host validation for printing profile.
- [ ] Capture real-host validation for Docker profile.
- [ ] Confirm Intel hardware profile packages and module behavior.
- [ ] Confirm AMD hardware profile packages and module behavior on non-VM hardware.
- [ ] Confirm NVIDIA hardware profile packages and module behavior.
- [ ] Confirm laptop battery/power package and service behavior.
- [ ] Document any Artix package substitutions versus Omarchy/Arch packages.

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
- [ ] Validate first login visually on a clean Artix host.
- [ ] Capture screenshots or expected-result images for first login, menu, Waybar, launcher, and theme state.
- [ ] Validate TTY startup on real hardware.
- [ ] Validate `greetd` greeter mode on real hardware.
- [ ] Validate `greetd` autologin mode on real hardware.
- [ ] Add fallback behavior or documentation for missing optional AUR tools such as Walker and Elephant.
- [ ] Decide whether screenshot command should always use the repo wrapper instead of inline Hyprland command.
- [ ] Validate lock/idle behavior after suspend/resume on laptop hardware.
- [ ] Validate default browser and terminal helpers with installed package set.
- [ ] Validate portal behavior with Flatpak apps.
- [ ] Validate clipboard history with text and image content.

## Milestone 4 - Omarchy-Like User Experience

Status: partially complete; this is the largest user-facing gap.

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
- [ ] Add or explicitly defer About/branding menu.
- [ ] Complete Setup menu for editing Hyprland, Hypridle, Hyprlock, Walker, Waybar, Mako, and AHR configs.
- [ ] Add default editor helper or document why it is intentionally omitted.
- [ ] Add OpenRC-safe System menu actions for logout, shutdown, suspend, hibernate, reboot, and lock.
- [ ] Add safer top-bar toggle parity, if current Waybar toggle is not enough.
- [ ] Decide whether night-light support belongs in beta.
- [ ] Decide whether gaps/layout/corners style toggles belong in beta.
- [ ] Decide whether capture menu needs OCR, color picker, audio recording, and webcam recording now or post-beta.
- [ ] Explicitly mark reminders as optional polish or implement lightweight notification timers.
- [ ] Explicitly mark transcode workflow as optional polish or implement a minimal safe command.
- [ ] Explicitly mark LocalSend/share workflow as optional polish or unsupported for beta.
- [ ] Keep broad install/remove menus intentionally narrow until package operations are tested.
- [ ] Keep web app installer unsupported for beta unless it becomes a release goal.
- [ ] Add user-facing expected-results screenshots or text for first login.
- [ ] Run one clean-install usability pass where the tester does not read the source docs first.

## Milestone 5 - Maintenance, Repair, And Upgrade Tooling

Status: strong foundation; needs recovery confidence.

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
- [ ] Make `ahr repair --config` either apply safe fixes or clearly remain detect-only in all docs.
- [ ] Add guided recovery for interrupted update runs.
- [ ] Add guided recovery for skipped or failed migrations.
- [ ] Add a validation bundle collection script.
- [ ] Add command to print install state and last log path.
- [ ] Add command to list config backups created by phase 4.
- [ ] Add repair coverage for missing namespace links.
- [ ] Add repair coverage for missing docs.
- [ ] Add repair coverage for theme state/background fallback.
- [ ] Add repair coverage for startup mode state.
- [ ] Decide whether a full uninstall is too risky; if so, document manual reset boundaries instead.

## Milestone 6 - Documentation And Release Readiness

Status: active milestone.

- [x] Rewrite README around current supported install flow.
- [x] Add beta checklist.
- [x] Add known issues file.
- [x] Add beta support matrix.
- [x] Draft release notes.
- [x] Link validation commands from release docs.
- [x] Document repair and reset boundaries.
- [ ] Add screenshots or expected-result artifacts under `docs/screenshots/` or a clearly documented alternative.
- [ ] Collect Intel real-host validation bundle.
- [ ] Collect AMD real-hardware validation bundle.
- [ ] Collect NVIDIA real-host validation bundle.
- [ ] Collect laptop validation bundle.
- [ ] Collect `greetd` greeter-mode validation bundle.
- [ ] Collect `greetd` autologin validation bundle.
- [ ] Confirm CI passes on the final beta branch.
- [ ] Review README for any stale milestone language.
- [ ] Review ROADMAP for current status consistency with Milestone 6.
- [ ] Review release notes for exact release date and version.
- [ ] Attach validation bundles to release assets.
- [ ] Tag beta release, for example `v0.1.0-beta1`.

## Milestone 7 - Optional Distribution Work

Status: intentionally deferred.

- [x] State that ISO/profile work is out of scope until the script installer is reliable.
- [ ] Decide whether the project should remain script-first after beta.
- [ ] Document what an Artix profile/ISO would need.
- [ ] Identify installer pieces that would need to become package/profile assets.
- [ ] Identify CI or VM automation needed before ISO work is safe.
- [ ] Do not start ISO implementation before beta installer validation is complete.

## Fastest Path To Usable Beta

- [ ] Run and archive one clean TTY install validation on fresh Artix OpenRC.
- [ ] Run and archive one `greetd` greeter validation on fresh Artix OpenRC.
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
- [ ] `greetd` support exists but is not exhaustively validated.
- [ ] First-login visual proof is missing.
- [ ] Some Omarchy required-parity workflows remain partial or intentionally narrower.

## Definition Of Done

- [ ] Fresh Artix OpenRC install completes through default installer path without manual repair.
- [ ] Re-running installer phases is safe and documented.
- [ ] No runtime path requires systemd.
- [ ] Required OpenRC services are enabled and validated through OpenRC-native commands.
- [ ] TTY startup works reliably.
- [ ] Optional `greetd` startup works reliably.
- [ ] First login opens a usable Hyprland desktop with Waybar, Mako, audio, portals, clipboard, screenshot, lock, idle, wallpaper, launcher, terminal, file manager, and browser defaults working.
- [ ] Optional AUR features improve the desktop but are not required for the base experience.
- [ ] Repair, update, migration, doctor, and smoke tools detect common drift.
- [ ] Known unsupported Omarchy features are explicit and intentional.
- [ ] README, support matrix, known issues, release notes, screenshots or expected results, and release checklist are complete.
- [ ] Real-host validation bundles exist for supported beta claims.
