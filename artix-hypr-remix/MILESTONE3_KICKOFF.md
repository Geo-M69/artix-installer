# Milestone 3 Kickoff Checklist (Hyprland Desktop Functionality)

This plan translates Milestone 3 from `ROADMAP.md` into actionable implementation and validation work.

## Current Baseline

- Milestone 2 is functionally green for development flow (VM validation pass).
- One Milestone 2 release-gate item remains: NVIDIA laptop validation log entry in `MILESTONE2_VALIDATION_MATRIX.md`.
- Milestone 3 desktop-functionality validation is complete and ready to hand off into Milestone 4 planning.

## Milestone 3 Goals (Roadmap Alignment)

From Milestone 3 in `ROADMAP.md`:
- Launcher and clipboard work with core packages even without optional AUR extras.
- Validate Hyprland launch, portal backend, PipeWire, WirePlumber, and screen capture.
- Tighten lock, idle, wallpaper, browser, terminal, file manager, and default app behavior.
- Ensure fonts/icons/cursor/theme are coherent at first login.
- Validate autostart ordering and environment variables in both `tty` and `greetd` modes.

## Workstream A: Core Runtime Without Optional AUR

### A1. Launcher fallback behavior

- [x] Confirm launcher path works when optional launchers are missing.
- [x] Ensure no autostart crash or hard-fail if optional launcher binaries are absent.
- [x] Ensure keybind-driven launcher command has a guaranteed core fallback.

Exit criteria:
- Base install launches apps successfully without optional AUR components.

### A2. Clipboard fallback behavior

- [x] Validate clipboard history path with core package set only.
- [x] Guard optional clipboard helpers behind presence checks.
- [x] Confirm keybinds still function with fallback pipeline.

Exit criteria:
- Copy/paste and clipboard history workflow is functional without optional AUR tools.

## Workstream B: Session Plumbing Validation

### B1. Hyprland + portal + media stack

- [x] Validate `xdg-desktop-portal` + `xdg-desktop-portal-hyprland` process health.
- [x] Validate PipeWire and WirePlumber active status in session.
- [x] Validate screenshot and capture path end-to-end (`grim`, `slurp`, recorder path).

Exit criteria:
- Portal and audio/capture stack are stable immediately after first login.

Progress note:
- `post-install-smoke.sh` passed with session runtime process checks (portal + media stack).
- Manual Milestone 3 validation confirmed screenshot/capture paths.

### B2. Startup mode parity (`tty` and `greetd`)

- [x] Run smoke in `tty` mode after fresh install.
- [x] Run smoke in `greetd` mode (`greeter`).
- [x] Run smoke in `greetd` mode (`autologin`).
- [x] Compare environment-sensitive behavior (portal startup, keyring, auth prompts).

Exit criteria:
- No mode-specific regressions in daily desktop use paths.

Progress note:
- Manual Milestone 3 validation confirmed `tty`, `greetd` greeter, and `greetd` autologin startup paths.

## Workstream C: First-Login UX Coherence

### C1. Lock/idle/wallpaper/default apps

- [x] Validate lock screen command and idle trigger behavior.
- [x] Validate wallpaper backend selection and persistence.
- [x] Validate browser/terminal/file-manager defaults and opening behavior.

Exit criteria:
- Fresh login feels complete and consistent, not partially configured.

Progress note:
- Runtime launchers now route through `ahr-*` wrappers, preferred terminal/file-manager/browser defaults are initialized on first run, and default-theme setup now seeds wallpaper state on fresh login.
- VM validation on `linux2024` (QEMU/KVM, `greetd` autologin) passed lock/idle, default-app launchers, wallpaper persistence, and theme-color wallpaper fallback.

### C2. Theme/font/icon/cursor coherence

- [x] Validate theme assets present and active at first login.
- [x] Validate fonts and icon theme fallback behavior.
- [x] Validate cursor theme/size consistency across apps.

Exit criteria:
- No obvious theme/font/cursor mismatches on first session.

## Workstream D: Validation Tooling Upgrades

### D1. Extend smoke/doctor for Milestone 3 assertions

- [x] Add checks for PipeWire/WirePlumber service/process readiness in user session context.
- [x] Add checks for portal backend readiness beyond binary presence.
- [x] Add checks for launcher fallback health and lock/idle command availability.

Exit criteria:
- `doctor.sh` and `post-install-smoke.sh` detect major Milestone 3 runtime breakages.

Progress note:
- `post-install-smoke.sh` now checks live session processes for portal/media/Waybar/Mako, validates deployed `ahr-*` runtime wrappers, probes default browser/terminal helpers, and validates wallpaper state/runtime.
- `doctor.sh` now checks deployed framework command executables for the resolved desktop user in addition to package/runtime dependencies.

### D2. Add Milestone 3 run log template

- [x] Add a per-host Milestone 3 log section (VM + real hardware).
- [x] Track startup mode, failures, and mitigations.

Exit criteria:
- Repeatable evidence trail exists for Milestone 3 stabilization.

## Milestone 3 Validation Log Template

```text
Host ID:
Date:
Environment: VM | bare metal
Startup mode:
Install command:
C1 result:
C2 result:
Session/runtime result:
Warnings:
Follow-ups:
```

## Milestone 3 Validation Log

### User-validated completion pass

- Date: 2026-06-04
- Environment: user-tested supported install paths
- Startup mode: `tty`, `greetd` / `greeter`, `greetd` / `autologin`
- C1 result: PASS
- C2 result: PASS
- Session/runtime result: PASS
- Capture result: PASS
- Warnings: none blocking Milestone 3 handoff
- Follow-ups: proceed to Milestone 4 Omarchy-like UX parity planning

### Host: linux2024 (QEMU/KVM)

- Date: 2026-06-04
- Environment: VM
- Startup mode: `greetd` / `autologin`
- Install command: `sudo ./install.sh --from-phase 3 --phase 8 --user geo --startup-mode greetd --greetd-mode autologin --hardware-mode auto --docker-profile on --printing-profile on --flatpak-profile all --dev-baseline on -y`
- C1 result: PASS
- C2 result: PASS
- Session/runtime result: PASS
- Warnings: `NetworkManager` remained inactive because the VM already had a default route outside NetworkManager; accepted by installer and smoke checks.
- Follow-ups:
  - Superseded by the user-validated completion pass above.

## First Sprint (Suggested Order)

1. A1 launcher fallback hardening
2. A2 clipboard fallback hardening
3. B1 portal + PipeWire/WirePlumber runtime validation
4. C1 lock/idle/wallpaper/default app behavior audit
5. D1 tooling checks for newly hardened paths

## Validation Commands (Per Test Run)

From `artix-hypr-remix/`:

```bash
./scripts/quality-gate.sh
./scripts/doctor.sh
./scripts/post-install-smoke.sh --user <username>
./scripts/milestone2-validate.sh --user <username>
./scripts/milestone3-validate.sh --user <username> --c1-result PASS --c2-result PASS
```

For startup mode testing:

```bash
sudo ./install.sh --phase 5 --user <username> --startup-mode tty
sudo ./install.sh --phase 5 --user <username> --startup-mode greetd --greetd-mode greeter
sudo ./install.sh --phase 5 --user <username> --startup-mode greetd --greetd-mode autologin
```

## Definition of Milestone 3 Done

- Core desktop paths work without optional AUR dependencies.
- Portal/audio/capture stack is reliable on first login.
- `tty` and `greetd` modes both validated and stable.
- First-login visual and behavioral coherence achieved.
- Tooling catches major regressions in Milestone 3 runtime paths.

## Notes

- Keep Milestone 2 release gate open only for pending NVIDIA laptop validation entry.
- Milestone 3 is complete; continue with Milestone 4 while hardware validation completion remains tracked separately.
