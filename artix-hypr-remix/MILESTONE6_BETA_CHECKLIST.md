# Milestone 6 — Beta checklist (draft)

Purpose
- Finalize release-facing documentation, validation artifacts, and a concise beta checklist so the project is ready for a public beta release.

Acceptance criteria
- README rewritten to clearly state the supported starting point, install path, validation workflow, and repair boundaries.
- A concise beta checklist is published and linked from the README.
- Known issues and troubleshooting guidance are documented in a single file.
- A minimal set of screenshots / expected-results examples are added to `config/` or `docs/screenshots/`.
- A frozen support matrix (startup modes, hardware classes, optional profiles) is published.
- Real-host validation logs captured for Intel/AMD/NVIDIA (desktop & laptop), TTY and `greetd` startup flows.

Checklist
- [x] Rewrite and publish README (replace or augment `README.md`).
- [x] Add and link this beta checklist from `README.md`.
- [x] Create `MILESTONE6_KNOWN_ISSUES.md` and link it from README.
- [x] Add a small set of screenshots / expected-results (placeholder and expected-result descriptions created at `docs/screenshots/README.md`).
- [x] Publish `BETA_SUPPORT_MATRIX.md` to freeze supported hardware/startup combinations.
- [ ] Collect validation logs for greetd autologin — confirmed working through daily use.
- [x] Collect validation logs for AMD, NVIDIA, and one laptop.
  - AMD: VM (virtualized GPU) — previously done
  - NVIDIA: real laptop host (TTY + greetd) — completed
  - Intel: still pending real-host validation
- [x] Run the full local quality gate and smoke validation on a test host (see commands below).
- [x] Run AHR maintenance checks: `ahr migrate --status` ✅, `ahr update --dry-run` ✅, `ahr repair --dry-run` 🟡 (wallpaper symlink deferred)
- [x] Produce release notes summarizing known issues, validation hosts, and rollback boundaries.
- [x] Tag and publish the beta release after CI passes.
  - Decision: ✅ Ship `v0.1.0-beta1` now with CI passing + NVIDIA/laptop validated. Intel validation deferred to post-beta.
  - Tag pushed: `v0.1.0-beta1` (2026-06-06)

Minimum validation commands

Run locally from the `artix-hypr-remix/` repo:

```bash
./scripts/quality-gate.sh --no-aur
AHR_HOST_POLICY=vm ./scripts/smoke-framework.sh --keep-sandbox
./scripts/milestone2-validate.sh --user <username> --gpu-profile intel --startup-modes "tty,greetd"
./scripts/check-hardware.sh /tmp/hardware-profile.json
ahr repair --dry-run
ahr repair --apply   # only after review
ahr migrate --status
ahr update --dry-run
```

Where to upload logs
- Installer log: `/var/log/artix-hypr-remix-install.log`
- Hardware snapshot: `/var/lib/artix-hypr-remix/hardware-profile.json`
- Per-host validation bundle: create a tarball named `validation-<host>-<gpu>-<date>.tar.gz` containing the above logs and `/var/log` excerpts.

Release checklist (high level)
- [x] All CI checks pass (quality gate, smoke framework).
- [x] AMD — VM validation (previously done)
- [x] NVIDIA + Laptop — real-host validation (just completed)
- [ ] Intel — still pending real-host validation
- [x] README, support matrix, and known-issues files are published and linked.
- [x] Validation bundles attached to the release assets.
  - AMD VM bundle (2026-06-05)
  - NVIDIA laptop bundle (2026-06-06)
- [x] Release notes drafted and reviewed: [RELEASE_NOTES.md](RELEASE_NOTES.md)
- [ ] Tag release (example: `v0.1.0-beta1`) and publish on GitHub.

Notes
- Keep the beta checklist intentionally concise — link into deeper docs for long-running validation artifacts (e.g., `MILESTONE2_VALIDATION_MATRIX.md`).
- Prefer reproducible host-validation commands and include exact script args used when capturing logs.
