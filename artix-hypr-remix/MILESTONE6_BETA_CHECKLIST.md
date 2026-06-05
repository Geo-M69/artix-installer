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
- [ ] Rewrite and publish README (replace or augment `README.md`).
- [ ] Add and link this beta checklist from `README.md`.
- [ ] Create `MILESTONE6_KNOWN_ISSUES.md` and link it from README.
- [ ] Add a small set of screenshots / expected-results (place under `config/docs/screenshots/`).
- [ ] Publish `BETA_SUPPORT_MATRIX.md` to freeze supported hardware/startup combinations.
- [ ] Collect validation logs for at least one host per GPU profile (intel, amd, nvidia) and one laptop.
- [ ] Run the full local quality gate and smoke validation on a test host (see commands below).
- [ ] Run AHR maintenance checks: `ahr repair` (dry-run + apply), `ahr migrate --status`, `ahr update --dry-run`.
- [ ] Produce release notes summarizing known issues, validation hosts, and rollback boundaries.
- [ ] Tag and publish the beta release after CI passes.

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
- [ ] All CI checks pass (quality gate, smoke framework).
- [ ] At least one validated host for each GPU profile (intel/amd/nvidia) and at least one laptop.
- [ ] README and known-issues files are published and linked.
- [ ] Validation bundles attached to the release assets.
- [ ] Release notes drafted and reviewed.
- [ ] Tag release (example: `v0.1.0-beta1`) and publish on GitHub.

Notes
- Keep the beta checklist intentionally concise — link into deeper docs for long-running validation artifacts (e.g., `MILESTONE2_VALIDATION_MATRIX.md`).
- Prefer reproducible host-validation commands and include exact script args used when capturing logs.
