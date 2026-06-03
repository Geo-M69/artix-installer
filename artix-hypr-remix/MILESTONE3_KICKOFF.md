# Milestone 3 Kickoff Checklist (Hyprland Desktop Functionality)

This plan translates Milestone 3 from `ROADMAP.md` into actionable implementation and validation work.

## Current Baseline

- Milestone 2 is functionally green for development flow (VM validation pass).
- One Milestone 2 release-gate item remains: NVIDIA laptop validation log entry in `MILESTONE2_VALIDATION_MATRIX.md`.

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

- [ ] Validate `xdg-desktop-portal` + `xdg-desktop-portal-hyprland` process health.
- [ ] Validate PipeWire and WirePlumber active status in session.
- [ ] Validate screenshot and capture path end-to-end (`grim`, `slurp`, recorder path).

Exit criteria:
- Portal and audio/capture stack are stable immediately after first login.

### B2. Startup mode parity (`tty` and `greetd`)

- [ ] Run smoke in `tty` mode after fresh install.
- [ ] Run smoke in `greetd` mode (`greeter`).
- [ ] Run smoke in `greetd` mode (`autologin`).
- [ ] Compare environment-sensitive behavior (portal startup, keyring, auth prompts).

Exit criteria:
- No mode-specific regressions in daily desktop use paths.

## Workstream C: First-Login UX Coherence

### C1. Lock/idle/wallpaper/default apps

- [ ] Validate lock screen command and idle trigger behavior.
- [ ] Validate wallpaper backend selection and persistence.
- [ ] Validate browser/terminal/file-manager defaults and opening behavior.

Exit criteria:
- Fresh login feels complete and consistent, not partially configured.

### C2. Theme/font/icon/cursor coherence

- [ ] Validate theme assets present and active at first login.
- [ ] Validate fonts and icon theme fallback behavior.
- [ ] Validate cursor theme/size consistency across apps.

Exit criteria:
- No obvious theme/font/cursor mismatches on first session.

## Workstream D: Validation Tooling Upgrades

### D1. Extend smoke/doctor for Milestone 3 assertions

- [ ] Add checks for PipeWire/WirePlumber service/process readiness in user session context.
- [ ] Add checks for portal backend readiness beyond binary presence.
- [ ] Add checks for launcher fallback health and lock/idle command availability.

Exit criteria:
- `doctor.sh` and `post-install-smoke.sh` detect major Milestone 3 runtime breakages.

### D2. Add Milestone 3 run log template

- [ ] Add a per-host Milestone 3 log section (VM + real hardware).
- [ ] Track startup mode, failures, and mitigations.

Exit criteria:
- Repeatable evidence trail exists for Milestone 3 stabilization.

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
- Continue Milestone 3 development in parallel with hardware validation completion.
