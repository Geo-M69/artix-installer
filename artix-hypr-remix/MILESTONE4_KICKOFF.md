# Milestone 4 Kickoff Checklist (Omarchy-Like User Experience)

This plan translates Milestone 4 from `ROADMAP.md` into actionable parity, polish, and validation work.

## Current Baseline

- Milestone 3 desktop-functionality validation is complete.
- Core Hyprland session paths, launcher fallback, clipboard flow, theme state, wallpaper behavior, portals, audio, screenshots, and startup modes are validated for the current development flow.
- Artix Hypr Remix already has the foundation for Milestone 4: `ahr-menu`, `ahr-theme`, `ahr-update`, `ahr-migrate`, first-run tasks, command namespace aliases, and OpenRC-native session launchers.
- Milestone 4 should focus on user experience parity and intentional differences, not re-opening completed boot/session plumbing unless a parity gap exposes a real regression.

## Milestone 4 Goals (Roadmap Alignment)

From Milestone 4 in `ROADMAP.md`:

- Build a full parity table against Omarchy feature-by-feature.
- Mark each difference as required parity, Artix/OpenRC adaptation, optional polish, intentional difference, unsupported for now, or unknown.
- Port only the UX patterns that improve completeness without importing systemd assumptions.
- Make first login feel fully configured rather than "framework installed."

## Parity Classification Rules

- Required parity: expected for an Omarchy-equivalent daily desktop experience.
- Artix/OpenRC adaptation: same user outcome, different implementation because Artix does not use systemd.
- Optional polish: improves feel or completeness but should not block beta.
- Intentional difference: project choice that should be documented clearly.
- Unsupported for now: explicitly deferred from beta scope.
- Unknown: needs source audit, user testing, or design decision before classification.

## Source Audit Plan

- [x] Pin an Omarchy reference source date or commit for Milestone 4 comparison.
- [x] Audit Omarchy menus, keybindings, first-run/welcome behavior, themes, update UX, and app workflows.
- [x] Compare each reference behavior against current AHR commands/configs.
- [x] Record every gap in the parity table before implementing broad UX changes.

Pinned reference:

- Omarchy checkout: `../omarchy`
- Omarchy commit: `8075b8b0dcd870ae3853bee99259bb41e8759c3f`
- Omarchy describe: `v3.4.2-720-g8075b8b0`
- Detailed audit: `MILESTONE4_PARITY_AUDIT.md`

Exit criteria:

- The parity table is based on a concrete reference, not memory or vibes. Tiny goblin with a clipboard, but useful.

## Initial Parity Table

| Area | Classification | AHR Status | Milestone 4 Task |
| --- | --- | --- | --- |
| Hyprland core session | Required parity | Present | Keep validated Milestone 3 behavior stable. |
| OpenRC-native startup | Artix/OpenRC adaptation | Present | Document why `tty`/`greetd` replace Omarchy systemd/UWSM/SDDM assumptions. |
| Main desktop menu | Required parity | Partial | Add Omarchy-equivalent Learn, Trigger, Style, About, and safer System routes. |
| Keybinding discoverability | Required parity | Absent | Add `ahr-menu-keybindings` or a static/dynamic hybrid keybinding viewer. |
| First-run welcome | Required parity | Partial | Update welcome copy after keybinding help exists. |
| Theme workflow | Required parity | Partial | Improve Style menu theme/background actions; document previews/install/update as optional or deferred. |
| Defaults workflow | Required parity | Partial | Add or defer default editor support; keep browser/terminal defaults polished. |
| Update workflow | Required parity | Partial | Polish update prompts and add safe config/process restart actions. |
| Install/remove app workflows | Optional polish | Partial | Keep broad install/remove scope conservative and Artix-safe. |
| Web app workflow | Unsupported for now | Mostly absent | Defer unless beta scope intentionally expands. |
| Voice/assistant workflow | Optional polish | Partial | Keep Elephant/Voxtype optional and never required for base desktop success. |
| Repair/reapply workflow | Milestone 5 handoff | Mostly absent | Capture UX requirements now, implement mainly in Milestone 5. |

## Workstream A: Feature-By-Feature Parity

### A1. Reference parity audit

- [x] Create a full Omarchy comparison table from a pinned source reference.
- [x] Separate user-facing behavior from implementation details.
- [x] Mark systemd-specific features as Artix/OpenRC adaptations or unsupported.
- [x] Identify which gaps are beta blockers versus polish.

Exit criteria:

- Every major Omarchy-facing feature has a classification and an AHR status.

### A2. Command namespace coverage

- [x] Compare `omarchy-*` compatibility aliases against expected user-facing command names.
- [x] Add missing safe aliases only when they map cleanly to AHR behavior.
- [x] Document intentional alias omissions.

Exit criteria:

- Users coming from Omarchy can discover equivalent AHR commands without hidden systemd coupling.

Progress note:

- Safe aliases were expanded for top-level `omarchy`, app launcher, Bluetooth, Waybar toggle/restart, Mako restart, and notification dismiss behavior.
- Broader Omarchy commands remain intentionally omitted until AHR has native, OpenRC-safe implementations.

## Workstream B: First-Login Experience

### B1. Welcome and orientation flow

- [x] Replace or augment the current notification-only welcome task.
- [x] Add a clear "what now?" path for launcher, terminal, and keybindings.
- [x] Add clear orientation paths for theme, updates, and docs.
- [x] Ensure the welcome flow works without optional AUR extras.
- [x] Ensure the flow is not annoying on re-run or migration.

Exit criteria:

- First login feels intentionally configured, not merely bootstrapped.

### B2. Keybinding and menu discoverability

- [x] Add keybinding help to `ahr-menu`.
- [x] Add a menu path for opening docs or a local quick reference.
- [x] Validate keybinding labels match the actual Hyprland config.

Exit criteria:

- A new user can discover core actions without opening config files.

Progress note:

- Added `ahr-menu-keybindings`, `omarchy-menu-keybindings`, a Learn menu, `Super+K` keybinding help, an installed quick reference, and first-run welcome copy pointing to the new help path.

## Workstream C: Menu, Theme, And Update Polish

### C1. Menu UX pass

- [x] Audit `ahr-menu` category names, option order, prompts, and terminal handoff behavior.
- [x] Make destructive or privileged actions explain what they will do before running.
- [x] Keep `wofi`, Walker, `rofi`, and TTY menu backends behaviorally consistent.

Exit criteria:

- The menu feels like a coherent control center, not a pile of scripts wearing a trench coat.

Progress note:

- Added first-class `Trigger` and `Style` menus. Capture/toggle actions now live under `Trigger`; theme/background/Waybar/Mako visual actions now live under `Style`; setup is focused on devices, defaults, and launcher service actions.
- Install/remove/update/power routes now use clearer confirmation text or terminal preambles before privileged or destructive actions.

### C2. Theme UX pass

- [x] Validate theme list, current, set, refresh, background next, and background set workflows from menu and CLI.
- [x] Decide whether theme preview or richer metadata belongs in Milestone 4 or later.
- [x] Document theme asset expectations for AHR and Omarchy-compatible themes.

Progress note:

- Theme status, theme set, background next, background path set, refresh, and visual restarts are exposed from the `Style` menu. Richer previews, metadata, theme install/update/remove, and gallery behavior are intentionally deferred as optional polish beyond the beta-critical UX pass.

Exit criteria:

- Theme switching is understandable, persistent, and visibly complete.

### C3. Update UX pass

- [x] Polish update availability messaging for human-readable and JSON modes.
- [x] Make menu-driven update paths explain pacman/AUR/Flatpak/migration scope.
- [x] Add validation notes for interrupted updates and skipped migrations as Milestone 5 inputs.

Progress note:

- `ahr-update-available` now reports a clearer human summary while preserving the existing exit-status contract and JSON counters; JSON also includes a `pending` boolean for status consumers.
- Menu-driven update paths now describe package, AUR, Flatpak, migration, and hook scope before running.
- Milestone 5 repair/reapply inputs: interrupted update recovery should expose stale-lock/log guidance around `~/.local/state/artix-hypr-remix/update.log`; skipped migrations should remain visible through `ahr migrate --status` and gain a clearer guided repair/retry path.

Exit criteria:

- A normal user can tell whether updates are pending and what the update command will touch.

## Workstream D: Documentation And Beta Handoff

### D1. Expected first-login result

- [x] Add a concise expected-results section to README or a dedicated validation doc.
- [x] Include launcher, terminal, menu, Waybar, Mako, wallpaper, theme, update status, and keybinding help.
- [x] Document accepted Artix/OpenRC differences from Omarchy.

Progress note:

- Added `MILESTONE4_EXPECTED_RESULTS.md` as the tester-facing first-login and UX validation reference.

Exit criteria:

- Testers know what "good" looks like without asking the maintainer to narrate the desktop.

### D2. Milestone 5 handoff notes

- [x] Track repair/reapply UX needs discovered during Milestone 4.
- [x] Track docs gaps that belong to release readiness instead of UX parity.
- [x] Keep unsupported-for-now items explicit so they do not become ghost blockers.

Progress note:

- Added `MILESTONE5_HANDOFF.md` with repair/reapply, update/migration recovery, doctor/smoke, release-doc, and unsupported-item notes.

Exit criteria:

- Milestone 5 starts with concrete repair/maintenance requirements instead of fog.

## First Sprint (Suggested Order)

1. Pin Omarchy reference and fill the full parity table.
2. Audit `ahr-menu` against parity table categories.
3. Design the first-login welcome/keybinding help flow.
4. Polish update UX copy and menu prompts.
5. Add expected first-login results to docs.

## Validation Commands (Per Test Run)

From `artix-hypr-remix/`:

```bash
./scripts/quality-gate.sh
./scripts/doctor.sh
./scripts/post-install-smoke.sh --user <username>
./scripts/milestone3-validate.sh --user <username> --c1-result PASS --c2-result PASS
```

Manual Milestone 4 UX validation:

```text
Open main menu:
Open app launcher:
Open keybinding help:
Change theme:
Cycle wallpaper:
Check updates:
Run update dry-run:
Open terminal action from menu:
Confirm first-login welcome result:
```

## Milestone 4 Validation Log Template

```text
Host ID:
Date:
Environment: VM | bare metal
Startup mode:
Omarchy reference:
Menu result:
Welcome/keybinding result:
Theme result:
Update UX result:
Intentional differences reviewed:
Warnings:
Follow-ups:
```

## Definition Of Milestone 4 Done

- Full Omarchy parity table exists and every major feature is classified.
- Required parity gaps are closed or explicitly deferred with rationale.
- Artix/OpenRC adaptations are documented from the user perspective.
- First login provides a clear welcome/orientation path.
- Menu, theme, and update workflows feel coherent enough for beta testers.
- Unsupported-for-now features are documented and do not block beta.
- Milestone 5 repair/reapply requirements are captured.

Status: complete for the current Milestone 4 alpha scope.
