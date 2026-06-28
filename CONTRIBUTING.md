# Contributing to artix-hypr-remix

## Reporting Bugs

Bug reports help make artix-hypr-remix more reliable. Please use the
[GitHub issue template](https://github.com/Geo-M69/artix-installer/issues/new/choose)
— it includes structured fields and prompts to gather the diagnostic info
needed to triage effectively.

### Before filing

1. Check [MILESTONE6_KNOWN_ISSUES.md](artix-hypr-remix/MILESTONE6_KNOWN_ISSUES.md)
   — your issue may already be known.
2. Run a quick health check and paste the output in the report:

   ```bash
   cd artix-hypr-remix
   ahr repair --dry-run
   ahr status
   scripts/doctor.sh --no-aur
   ```

3. If possible, collect a validation bundle:

   ```bash
   cd artix-hypr-remix
   sudo ./scripts/collect-validation-bundle.sh
   ```

   This captures hardware profile, installed packages, OpenRC service state,
   config state, and logs without personal data. Attach the resulting archive
   to the issue.

### What happens next

- Issues are triaged by severity: **blocker** (desktop unusable), **major**
  (feature broken but desktop usable), **minor** (cosmetic / nice-to-have).
- Blocker and major bugs are prioritised for the next beta or stable release.
- Minor issues and feature requests are tracked for future milestones.

Currently no issues have been filed, so there is nothing to triage. The bug report template
(`.github/ISSUE_TEMPLATE/bug-report.yml`) is set up and ready for when reports come in.

## Feature Requests

Open a [feature request](https://github.com/Geo-M69/artix-installer/issues/new/choose)
with a clear description of the problem you want to solve and any ideas for
how to approach it. Feature requests are discussed in the next milestone
planning cycle.

## Pull Requests

PRs are welcome but please open an issue first to discuss the change —
especially for large features or changes that affect installer behaviour,
hardware profiles, or OpenRC service handling.

### PR guidelines

- Run the quality gate before pushing:

  ```bash
  cd artix-hypr-remix
  ./scripts/quality-gate.sh --no-aur
  ```

- Keep changes focused. A PR should address one issue or feature.
- Update `COMPLETION_CHECKLIST.md` if the PR completes a checklist item.
- If the PR changes user-facing behaviour, update the README or relevant docs.

## Development setup

artix-hypr-remix is designed to be developed and tested on Artix Linux with
OpenRC. All scripts target `bash`. See `artix-hypr-remix/README.md` for the full setup and
validation workflow.
