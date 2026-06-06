# Milestone 7 Kickoff — Post-Beta Hardening & Distribution

**Started:** 2026-06-06
**Predecessor:** Milestone 6 — `v0.1.0-beta1` tagged and published

Milestone 7 shifts focus from release readiness to post-beta hardening: closing validation gaps, responding to real-user feedback, and deciding the distribution path forward.

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

- [ ] Validate printing profile (`--printing-profile on`) on a real host.
- [ ] Validate Docker profile (`--docker-profile on`) on a real host.
- [ ] Validate optional package names (`packages/91-aur-optional.txt`) on a fresh Artix install.

### A3. Laptop-specific validation

- [ ] Validate battery/power package behavior on laptop hardware (NVIDIA laptop covers this partially).
- [ ] Validate lock/idle after suspend/resume on laptop hardware.
- [ ] Validate lid-close behavior with `elogind` + `hypridle`.

### A4. Real-host verification of existing profiles

- [ ] Confirm AMD hardware profile on non-VM real AMD hardware (if accessible).
- [ ] Document any Artix package substitutions versus Omarchy/Arch equivalents (e.g., `nvidia-open` vs `nvidia`, DKMS variants).

---

## Workstream B: Beta Feedback & Bug Triage

### B1. Feedback channel

- [ ] Set up a GitHub issue template for beta bug reports (include validation bundle instructions).
- [ ] Add a `CONTRIBUTING.md` or update README with how to report issues.
- [ ] Monitor incoming issues and categorize by severity.

### B2. First bug-fix pass

- [x] Fix the deferred wallpaper symlink workflow (`ahr repair` reports missing `current/background`).
  - **Done:** `ahr-theme-set` now creates a sentinel symlink for themes without images.
  - `ahr repair --theme --apply` repairs existing installs.
- [ ] Triage and address any beta-blocker bugs reported.
- [ ] Consider whether `ahr repair --config` should move beyond detect-only for specific known-safe paths.

### B3. Usability pass

- [ ] Run one clean-install usability pass where the tester has not read the source docs.
- [ ] Capture friction points and update guidance docs accordingly.
- [ ] Validate that `README.md` fast-start instructions work verbatim on a fresh Artix install.

---

## Workstream C: Distribution Path Decision

### C1. Evaluate script-first vs ISO/profile

- [ ] List pros/cons of staying script-first (current approach).
- [ ] List pros/cons of shipping an Artix profile/ISO.
- [ ] Gather feedback from beta testers on installation friction.

**Considerations:**

| Factor | Script-first | Artix profile/ISO |
|--------|-------------|-------------------|
| Maintenance burden | Low — one codebase | Higher — build tooling + testing |
| User onboarding | Requires base Artix install | One-shot install |
| Flexibility | Works on any Artix setup | Fixed base assumptions |
| CI/testing | Easy to automate | Needs chroot/VM infrastructure |
| Time to ship | Now | Weeks to months |

### C2. Distribution decision

- [ ] Decide on distribution path for v0.2.0 or stable.
- [ ] Document the decision in `ROADMAP.md` and `README.md`.

### C3. ISO requirements (if ISO path is chosen)

- [ ] Document minimum ISO tooling: `artools`, `mksquashfs`, `archiso`-compatible workflow or Artix-native equivalent.
- [ ] Define the target ISO base: same `artix-base-openrc` image + pre-applied AHR.
- [ ] Scope ISO build automation (GitHub Actions? manual?).

---

## Workstream D: Documentation & Project Health

### D1. Completion checklist update

- [ ] Mark post-beta items in `COMPLETION_CHECKLIST.md` as completed or deferred as appropriate.
- [ ] Keep `COMPLETION_CHECKLIST.md` estimate current (~93% → target).

### D2. Parity audit refresh

- [ ] Review `MILESTONE4_PARITY_AUDIT.md` for any items that should move from deferred into active scope based on beta feedback.

### D3. Release planning

- [ ] Define criteria for `v0.2.0-beta2` or `v0.1.0-stable`.
- [ ] Typical triggers: Intel validation done, critical bug fixes, distribution decision made.

---

## Exit Criteria

- [ ] Intel GPU profile validated on real hardware.
- [ ] At least one optional profile validated on real hardware (printing or Docker).
- [ ] Beta feedback triaged and initial bug-fix pass complete.
- [ ] Distribution path decision documented in ROADMAP.md.
- [ ] `COMPLETION_CHECKLIST.md` updated to reflect current state.
- [ ] No known beta-blocker issues unresolved.
