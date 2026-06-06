# Distribution Path Decision

**Date:** 2026-06-06
**Context:** Milestone 7 — Post-beta hardening & distribution
**Decision:** ✅ **Stay script-first** for v0.2.0 and v0.1.0-stable

---

## Evaluation: Script-First vs Artix Profile/ISO

### Script-First (current approach)

| Pros | Cons |
|------|------|
| Low maintenance — one bash codebase | Requires user to have a working Artix base install |
| Easy to CI/test — runs on any Linux host with bash | Longer install path (base install + AHR script) |
| Works on any Artix setup (real hardware, VM, container) | User must partition, network, and create user themselves |
| No build toolchain needed | No "one-shot" install experience |
| Single source of truth — no ISO rebuild cycle | |
| Changes ship as git pulls, not ISO respins | |
| Fast iteration — no respin/delay between fix and ship | |

### Artix Profile/ISO

| Pros | Cons |
|------|------|
| One-shot install — boot ISO, get a complete system | High maintenance — build tooling + testing for each release |
| Polished onboarding — guided installer UX | Needs chroot/VM infrastructure for CI |
| No base install prerequisite for end user | Fixed base assumptions — harder to adapt to user's partitioning/users |
| | Weeks to months to set up correctly |
| | Needs `artools`, `mksquashfs`, ArchISO-compatible or Artix-native workflow |
| | Split codebase — installer scripts + ISO build tooling |
| | ISO rebuilds needed for every release |

### Recommendation

**Stay script-first through v0.2.0 and v0.1.0-stable.**

The script-first approach matches the project's current maturity level:
- The installer is still evolving — script-first allows fast iteration without ISO respin cycles.
- Early adopters are Linux users comfortable with a base install + script workflow.
- CI/testing infrastructure for ISO builds doesn't exist yet and would divert effort from hardening.
- The script installer is the right foundation to prove reliability before committing to an ISO build pipeline.

### When to reconsider

Revisit an ISO/profile path when:
1. The script installer has been stable for at least one minor release cycle.
2. There's clear user demand for a one-shot install experience (e.g., repeated feedback that base install is a barrier).
3. CI infrastructure exists to build and test ISOs automatically.
4. Maintenance bandwidth allows for a parallel ISO build pipeline.

---

## Update: ROADMAP.md and README.md

The existing out-of-scope statements in both files are consistent with this decision — ISO/profile work is explicitly deferred until the script installer is reliable. No changes needed.

---

## ISO Requirements (Reference)

If the ISO path is revisited, these are the known requirements:

### Tooling
- `artools` (Artix build tools) or `archiso`-compatible workflow
- `mksquashfs` (for squashfs filesystem)
- `pacman` + custom repo configuration
- `mkinitcpio` for initramfs generation

### Base image
- Target: same `artix-base-openrc` ISO image used as the starting point today
- Pre-applied AHR configuration as a profile/package set
- Same hardware profile detection and OpenRC service handling

### Build automation
- GitHub Actions with QEMU/systemd-nspawn for chroot-based builds
- Weekly or release-triggered ISO builds
- Artifact storage (GitHub Releases or external hosting)

### Testing
- VM boot test for each ISO build (QEMU + libvirt)
- Validation bundle collection as part of ISO CI
- The existing smoke framework and quality gate should run inside the ISO build chroot
