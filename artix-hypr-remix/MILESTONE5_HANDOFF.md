# Milestone 5 Handoff Notes

Milestone 5 should turn the Milestone 4 UX work into stronger maintenance, repair, and upgrade tooling.

## Repair/Reapply Requirements

- Add an AHR repair entrypoint for common drift, likely `ahr repair` or `ahr doctor --repair`.
- Reapply framework-managed config safely without deleting user changes silently.
- Detect missing namespace links and rerun `namespace-install.sh`.
- Detect missing theme state and offer `ahr theme set artix-dark` or a selected fallback.
- Detect missing first-run or migration state and explain whether to rerun, retry, or reset.
- Detect stale update locks and point to `~/.local/state/artix-hypr-remix/update.log`.
- Keep repair actions dry-runnable before changing files.
- Preserve timestamp backups for any rewritten user config.

## Update And Migration Follow-Ups

- Add guided recovery for interrupted `ahr update` runs.
- Explain stale lock cleanup without asking users to blindly remove files.
- Improve skipped migration UX beyond `ahr migrate --retry-skipped`.
- Add clearer migration policy notes for future config format changes.
- Consider a post-update process restart menu for safe AHR-managed processes only.
- Consider a config refresh/reapply route that does not imply a full reinstall.

## Doctor And Smoke Follow-Ups

- Extend `doctor` to report repair suggestions, not only pass/fail state.
- Extend post-install smoke with more first-login readiness checks where safe.
- Keep runtime-session checks conditional so SSH/headless validation does not fail unfairly.
- Add explicit checks for expected installed docs and menu/keybinding discoverability.

## Documentation Gaps For Release Readiness

- Add known issues and troubleshooting.
- Add a concise beta checklist.
- Add rollback/reset expectations without promising full uninstall.
- Add screenshots or visual validation examples when the desktop visuals stabilize.
- Document unsupported Omarchy parity items in one release-facing place.

## Unsupported-For-Now Items To Keep Explicit

- systemd/UWSM/SDDM maintenance flows.
- Broad Omarchy install/remove workflows that have not been made Artix-safe.
- Web app installer.
- Reminder, transcode, and LocalSend share workflows.
- Rich theme gallery, previews, and theme install/update/remove.
- Hardware-specific toggles that have not been validated on real Artix hardware.
