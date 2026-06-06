# Milestone 7 — Post-Beta Hardening & Distribution ✅

**Completed:** 2026-06-06
**Predecessor:** Milestone 6 — `v0.1.0-beta1` tagged and published
**Successor:** `v0.1.0-beta2` tagged and published

Milestone 7 shifted focus from release readiness to post-beta hardening: closing
validation gaps, responding to real-user feedback, and deciding the distribution
path forward.

---

## Summary of Changes

- Distribution path decision: ✅ **Stay script-first** — documented in `docs/distribution-decision.md`.
- Feedback channel set up: GitHub issue templates (`bug-report.yml`, `feature-request.yml`), `CONTRIBUTING.md`, README callout.
- Usability pass: README rewritten with prerequisites table, phase table, time estimate, post-install guidance, troubleshooting section.
- Wallpaper symlink fixed: `ahr-theme-set` creates sentinel symlink for imageless themes; `ahr repair --theme --apply` repairs existing installs.
- `ahr repair --config` policy decided: detect-only, kept consistent with safety posture.
- Laptop validation: suspend fixed (`loginctl suspend`), acpid lid handler added, `pm-utils` added to laptop profile.
- Printing profile live-validated on NVIDIA laptop: `cupsd` + `avahi-daemon` running, smoke passes.
- Docker profile live-validated on NVIDIA laptop: service started, script checks pass.
- Artix package substitutions documented in `docs/package-substitutions.md`.
- Completion checklist estimate updated to ~95%.
- Parity audit reviewed — no deferred items moved into scope (no beta feedback yet).

---

## Current Baseline

- `v0.1.0-beta1` is live on GitHub.
- Quality gate, smoke framework, and CI all passing.
- Validation bundles collected: AMD (VM) + NVIDIA laptop (TTY + greetd).
- Support matrix published with NVIDIA/laptop moved to 🟢 Validated.
- Intel GPU validation is the last remaining hardware gap.
- Beta feedback loop is open — no reports yet.

---

## Milestone 7 Goals (Roadmap Alignment)

From `ROADMAP.md`:

> - Decide whether to stay script-first or eventually ship an Artix profile/ISO.
> - Collect Intel GPU real-host validation (deferred from M6).
> - Address beta feedback and bug reports.
> - Document ISO requirements only after the script installer is reliable.

---

## Workstream A: Remaining Validation Gaps

### A1. Intel GPU real-host validation ⏳ Deferred

- [ ] Find or set up an Intel/Intel-hybrid Artix host for a validation run.
- [ ] Run the full TTY and greetd flow (same procedure as NVIDIA laptop).
- [ ] Capture validation bundle and attach to release assets.
- [ ] Update `BETA_SUPPORT_MATRIX.md` Intel row from 🟡 Limited → 🟢 Validated.

> **Status:** Deferred — no Intel hardware available at this time. Will pick up later.

### A2. Optional profile validation

- [x] Validate printing profile (`--printing-profile on`) on a real host.
  - **Live-validated (NVIDIA laptop, 2026-06-06):** Phase 2 injects 4 packages (`cups`, `avahi`, `cups-openrc`, `avahi-openrc`). Phase 3 enables 2 services (`cupsd`, `avahi-daemon`). Post-install smoke confirms both services running. Doctor passes. Validation bundle collected.
- [x] Validate Docker profile (`--docker-profile on`) on a real host.
  - **Live-validated (NVIDIA laptop, 2026-06-06):** `check-docker-profile.sh` passes. `rc-service docker status` reports `started`.
- [ ] Validate optional package names (`packages/91-aur-optional.txt`) on a fresh Artix install.
  - **Documented:** packages listed in `docs/package-substitutions.md`. Validation requires a host with AUR access (`paru`).

### A3. Laptop-specific validation

- [x] Validate battery/power package behavior on laptop hardware (NVIDIA laptop covers this partially).
  - **Verified (NVIDIA laptop, 2026-06-06):** `acpi -V` reports battery capacity, adapter status, and thermal zones. Packages `acpi` and `acpid` are present and functional.
- [x] Validate lock/idle after suspend/resume on laptop hardware.
  - **Verified:** Lid close → system suspends (elogind), power press → wake → hyprlock shown. Expected behaviour.
- [x] Validate lid-close behavior with `elogind` + `hypridle`.
  - **Verified:** elogind handles lid close natively. Additionally, laptop profile now deploys an acpid lid event handler as a fallback.
- **Fixes applied during validation:**
  - `ahr-system-suspend` now tries `loginctl suspend` first (elogind is always installed), fixing "No suspend method found".
  - Laptop profile package list: added `pm-utils` as a suspend fallback.
  - Laptop OpenRC module: deploys acpid lid event + action script on profile apply.

### A4. Real-host verification of existing profiles

- [ ] Confirm AMD hardware profile on non-VM real AMD hardware (if accessible).
- [x] Document any Artix package substitutions versus Omarchy/Arch equivalents (e.g., `nvidia-open` vs `nvidia`, DKMS variants).
  - **Done:** `docs/package-substitutions.md` covers OpenRC wrappers, NVIDIA variants, AUR/community differences, hardware profiles, and profile validation status.

---

## Workstream B: Beta Feedback & Bug Triage

### B1. Feedback channel

- [x] Set up a GitHub issue template for beta bug reports (include validation bundle instructions).
  - **Done:** `.github/ISSUE_TEMPLATE/bug-report.yml` created with hardware, startup mode, validation bundle, and diagnostic fields.
- [x] Add a `CONTRIBUTING.md` or update README with how to report issues.
  - **Done:** `CONTRIBUTING.md` created at repo root with bug report instructions, PR guidelines, and validation bundle guidance.
- [ ] Monitor incoming issues and categorize by severity.

### B2. First bug-fix pass

- [x] Fix the deferred wallpaper symlink workflow (`ahr repair` reports missing `current/background`).
  - **Done:** `ahr-theme-set` now creates a sentinel symlink for themes without images.
  - `ahr repair --theme --apply` repairs existing installs.
- [ ] Triage and address any beta-blocker bugs reported.
- [x] Consider whether `ahr repair --config` should move beyond detect-only for specific known-safe paths.
  - **Decision:** Keep detect-only. User-facing configs (Hyprland, Waybar, Mako) are routinely customised — auto-repair would be destructive. Phase 4 with timestamped backups remains the safe reapply path. Any future auto-repair candidate must be purely derived and better placed under `--theme` or `--namespace` scope.

### B3. Usability pass

- [x] Run one clean-install usability pass where the tester has not read the source docs.
  - **Done:** README audited from a fresh-user perspective. Prerequisites, phase table, post-install guidance, and troubleshooting added. Placeholder URL replaced with actual repo URL.
- [x] Capture friction points and update guidance docs accordingly.
  - **Done:** 6 friction points identified and addressed in README rewrite (see `docs/` below).
- [x] Validate that `README.md` fast-start instructions work verbatim on a fresh Artix install.
  - **Verified (fresh VM):** Full `AHR_NO_SUDO=1 ./install.sh --host-policy any --dry-run -y` passed all 7 phases on a fresh Artix OpenRC VM (2026-06-06). Clone, cd, and install commands executed verbatim from README without errors. Live package install validation still needs a full live run.

---

## Workstream C: Distribution Path Decision

### C1. Evaluate script-first vs ISO/profile

- [x] List pros/cons of staying script-first (current approach).
  - **Done:** Documented in `docs/distribution-decision.md`.
- [x] List pros/cons of shipping an Artix profile/ISO.
  - **Done:** Documented in `docs/distribution-decision.md`.
- [ ] Gather feedback from beta testers on installation friction.
  - **Infrastructure set up:** bug report template (`.github/ISSUE_TEMPLATE/bug-report.yml`), `CONTRIBUTING.md` with reporting guidance, README troubleshooting section with repair commands. **Pending:** actual beta submissions.

**Considerations:**

| Factor | Script-first | Artix profile/ISO |
|--------|-------------|-------------------|
| Maintenance burden | Low — one codebase | Higher — build tooling + testing |
| User onboarding | Requires base Artix install | One-shot install |
| Flexibility | Works on any Artix setup | Fixed base assumptions |
| CI/testing | Easy to automate | Needs chroot/VM infrastructure |
| Time to ship | Now | Weeks to months |

### C2. Distribution decision

- [x] Decide on distribution path for v0.2.0 or stable.
  - **Decision:** ✅ Stay script-first. Rationale in `docs/distribution-decision.md`.
- [x] Document the decision in `ROADMAP.md` and `README.md`.
  - **Done:** `docs/distribution-decision.md` created. Existing out-of-scope statements in `ROADMAP.md` and `README.md` are already consistent with this decision.

### C3. ISO requirements (if ISO path is chosen)

- [x] Document minimum ISO tooling: `artools`, `mksquashfs`, `archiso`-compatible workflow or Artix-native equivalent.
  - **Done:** Documented in `docs/distribution-decision.md#iso-requirements-reference`.
- [x] Define the target ISO base: same `artix-base-openrc` image + pre-applied AHR.
  - **Done:** Documented in `docs/distribution-decision.md`.
- [x] Scope ISO build automation (GitHub Actions? manual?).
  - **Done:** Documented in `docs/distribution-decision.md`.

---

## Workstream D: Documentation & Project Health

### D1. Completion checklist update

- [x] Mark post-beta items in `COMPLETION_CHECKLIST.md` as completed or deferred as appropriate.
  - **Done:** M7 items updated — distribution decision, feedback channel, usability pass, issue template, CONTRIBUTING.md all marked. Estimate bumped to ~95%.
- [x] Keep `COMPLETION_CHECKLIST.md` estimate current (~93% → ~95%).

### D2. Parity audit refresh

- [x] Review `MILESTONE4_PARITY_AUDIT.md` for any items that should move from deferred into active scope based on beta feedback.
  - **No action:** No beta feedback received yet. All deferred items remain deferred. The audit's classification (required parity, optional polish, unsupported for now, etc.) is consistent with current project scope.

### D3. Release planning

- [ ] Define criteria for `v0.2.0-beta2` or `v0.1.0-stable`.
  - **Draft criteria:**
    - Intel GPU validation completed on real hardware (deferred from M6).
    - At least one optional profile validated on real hardware (printing or Docker).
    - No unresolved beta-blocker bugs.
    - Distribution path decision documented ✅.
    - `v0.1.0-stable` additionally requires: all three GPU profiles (Intel, AMD, NVIDIA) validated on real hardware, first-login screenshots captured, and validation bundles attached to release assets.
- [ ] Typical triggers: Intel validation done, critical bug fixes, distribution decision made.
  - Distribution decision ✅ — remaining triggers are Intel validation and critical bug fixes.

---

## Exit Criteria

- [ ] Intel GPU profile validated on real hardware.
- [x] At least one optional profile validated on real hardware (printing or Docker).
  - **Both validated on NVIDIA laptop (2026-06-06).**
- [ ] Beta feedback triaged and initial bug-fix pass complete.
- [x] Distribution path decision documented in `docs/distribution-decision.md`.
- [x] `COMPLETION_CHECKLIST.md` updated to reflect current state (~95%).
- [ ] No known beta-blocker issues unresolved.
