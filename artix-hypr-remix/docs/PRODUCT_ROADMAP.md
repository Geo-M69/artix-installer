# Artix Hypr Remix Product Roadmap

## Purpose

This roadmap defines the post-beta path from a working Artix Hyprland remix to
a complete, maintainable daily desktop.

AHR uses Omarchy as a quality and workflow reference, not as a feature contract.
Parity means matching the usefulness and cohesion of a workflow where it fits
AHR, while keeping Artix, OpenRC, user choice, and a smaller trusted base.

This document is the source of truth for future product direction. Historical
milestone and parity documents remain useful records, but their web-app and
application-backlog entries do not override the decisions below.

## Product Position

AHR is:

- Artix Linux and OpenRC native.
- Script-first, with safe re-runs and explicit support boundaries.
- A polished keyboard-first Hyprland desktop.
- Native-package-first for the core desktop and system integration.
- Flatpak-first for optional graphical applications.
- Conservative about AUR, proprietary software, services, and destructive
  removal.
- Inspired by Omarchy without depending on its Arch/systemd boot stack or its
  Chromium-centered web-app model.

## Application Policy

### Core native packages

Use Artix repository packages for software that participates directly in the
session or must work before Flatpak is healthy:

- Hyprland, portals, lock/idle, notifications, bar, launcher fallback.
- PipeWire/WirePlumber, networking, Bluetooth, power, and OpenRC services.
- Terminal, file manager, screenshot/recording tools, clipboard, archive
  handling, and small desktop utilities.
- CLI and diagnostic tools used by AHR itself.

Core packages must have package-availability checks, a documented purpose, and
live validation on a supported Artix install.

### Optional graphical applications

Prefer Flatpak for communication, office, media, creative, and other optional
GUI applications. A supported catalog entry must declare:

- Flathub application ID and category.
- Whether it is default, recommended, or optional.
- Installation and launch checks.
- Desktop entry and any MIME/default-app behavior.
- Permission notes where relevant.
- Removal behavior that does not delete user data silently.

Flatseal and Warehouse remain complementary management tools, not substitutes
for an AHR catalog and validation layer.

### AUR and external sources

AUR, vendor repositories, downloaded binaries, and proprietary installers are
opt-in exceptions. They must show their source, explain the trust boundary, and
fail without weakening the base desktop.

### Web services

AHR will not build or bundle a Chromium-centered web-app runtime. Services such
as ChatGPT, WhatsApp, YouTube, X, Figma, and Zoom remain normal browser sites
unless a trustworthy standalone Flatpak is deliberately added to the catalog.
Chromium may remain an optional browser, but it is not application
infrastructure.

## Roadmap Order

The phases are dependency ordered. A later phase may be prototyped early, but it
should not be advertised as supported until its earlier gates are satisfied.

## Phase 1: Framework Delivery And Recovery

### Goal

Make AHR capable of safely delivering and recovering from its own updates.

### Work

- Define an installed AHR version, release channel, source revision, and update
  source.
- Teach update availability checks to distinguish framework, package, Flatpak,
  theme, and migration work.
- Stage framework updates before replacing installed files.
- Back up the installed framework and managed derived files before activation.
- Fetch new migrations as part of the framework update, then run them.
- Run post-update health checks and retain actionable failure state.
- Add a documented rollback path for the last framework update.
- Add safe per-component restore for derived or fully managed configuration.
- Keep user-edited Hyprland, Waybar, Mako, and application configs
  backup-before-replace.
- Detect Btrfs/Snapper as an optional enhancement; never assume a filesystem
  layout or make snapshots mandatory.

### Exit gate

- A clean beta install can update to the next test revision without re-running a
  checkout manually.
- An interrupted update is diagnosable and retryable.
- A deliberately broken framework update can be rolled back.
- New migrations arrive through the same update path that executes them.

### Phase 1 Artix Validation Status

**Status: complete.** The Phase 1 validation runbook defines no Batch 2G or
other mandatory work after Batch 2F.

- Validation branch: `validation/ahr-phase1-artix-20260806`
- Validated candidate: `98d7ecd2349af66c846bf01403fb7abedb589466`

`ARTIX BATCH 2F RESTART-SAFE RECOVERY/ROLLBACK PASS`

Completed validation batches:

- Batch 1 successful paths: **PASS**
- Batch 2A health-failure rollback: **PASS**
- Batch 2B migration-failure rollback: **PASS**
- Batch 2C namespace-failure rollback: **PASS**
- Batch 2D backup-failure containment/recovery: **PASS**
- Batch 2E updater interruption: **PASS**
- Batch 2F restart-safe recovery/rollback: **PASS**

Batch 2F evidence:

- The remote validation branch and persistent validation-source `HEAD` both
  resolved exactly to `98d7ecd2349af66c846bf01403fb7abedb589466`.
- Persistent source `git fsck --full` was clean.
- `scripts/test-framework-update.sh`: `445 passed, 0 failed`.
- `scripts/test-ahr-doctor.sh`: `25 passed, 0 failed`.
- `scripts/test-framework-check.sh`: `18 passed, 0 failed`.
- `AHR_HOST_POLICY=artix bash scripts/smoke-framework.sh` passed.
- Candidate-direct dry-run exited `0` and pinned the exact candidate commit.
- No-mutation verification passed for the installed framework, namespace,
  migration markers, transactions, and framework backups.
- Final transaction count: `0`; final backup count: `0`.
- Installed `framework.json` was restored to the public source:
  `update_source=https://github.com/Geo-M69/artix-installer.git` and
  `revision=null`.

Accepted Phase 1 limitations:

1. Rollback restores migration markers but cannot reverse arbitrary external
   migration side effects.
2. `SIGKILL` is untrappable; restart safety relies on durable persisted
   checkpoints plus explicit continuation.
3. No additional destructive live recovery-interruption run was performed
   beyond the approved Batch 2F scope.

## Phase 2: Complete Daily-Desktop Baseline

### Goal

Ensure a default install can open ordinary files and perform ordinary desktop
tasks without asking the user to assemble missing pieces.

### Work

- Select and validate a PDF viewer.
- Add and validate image and video/audio viewers; reconcile the existing
  `imv`/`mpv` MIME setup with the actual package manifests.
- Select and validate a calculator.
- Decide whether SwayOSD and `hyprpicker` belong in core or in a small desktop
  utilities profile.
- Validate URL, directory, text, PDF, image, video/audio, archive, and removable
  device behavior.
- Keep office software optional, but offer at least one supported Flatpak
  office profile.
- Verify default browser, terminal, editor, file manager, and MIME choices
  survive updates and reboots.

### Exit gate

- The default-app/MIME matrix passes on a clean live session using real files.
- Every advertised Capture and Setup action either works with the default
  install or clearly offers the supported dependency.
- No optional application is required for first login or core recovery.

### Phase 2 Implementation Summary

**Status: complete (implementation and clean-Artix live validation).** The
default-app/MIME baseline is data-driven, idempotent, and choice-preserving.
See `docs/DEFAULT_APPS.md` for the matrix, package → desktop-entry mapping,
doctor validation, and live-validation procedure; see
`docs/FLATPAK_PROFILES.md` for the opt-in OnlyOffice profile.

Implemented in this phase:

- PDF → Evince (`org.gnome.Evince.desktop`); image → imv; video **and** audio →
  mpv (audio MIME explicitly maps to `mpv.desktop`); calculator → GNOME
  Calculator; directory/removable-device workflow → Nautilus + GVfs/MTP +
  UDisks2 (explicit dependency chain in `packages/30-files.txt`); archives →
  File Roller.
- `hyprpicker` added to the core desktop (`packages/10-hyprland.txt`) because
  Color Picker is an advertised Capture action. SwayOSD stays optional
  (`packages/91-aur-optional.txt`); its absence never fails doctor, smoke, or
  volume/brightness/media controls.
- OnlyOffice is an opt-in Flatpak profile only (`flatpaks/optional.txt` +
  `ahr-onlyoffice`); it is excluded from the default install, first-login,
  recovery, and framework-update requirements.
- The shared matrix lives in
  `config/artix-hypr-remix/bin/ahr-default-apps-matrix.sh` and is consumed by
  first-run setup (`56-default-apps.sh`), `ahr-doctor`, `scripts/doctor.sh`,
  and `scripts/post-install-smoke.sh`, so setup and validation cannot drift.

#### Phase 2 Validation Status

- **Final verdict: COMPLETE.** Clean-host validation ran in an Artix/OpenRC
  QEMU/KVM VM with a live Hyprland/Wayland session. Physical removable-device
  evidence used USB passthrough; no virtual disk was substituted.
- **Live default-app matrix: PASS.** All ten URL, directory, text, Markdown,
  PDF, image, audio, video, and archive rows passed before reboot and again
  after reboot with visible launches. MIME state was preserved byte-for-byte.
- **Physical removable device: PASS.** Mount, Nautilus browse/read, unmount,
  safe removal, physical removal/reinsertion, and integrity verification passed.
- **Color Picker: PASS.** The advertised AHR Menu Color Picker launched
  `hyprpicker`, and its clipboard value matched the selected on-screen color.
- **Framework update preservation: PASS.** The synthetic candidate passed
  preflight, apply, rollback, exact outer restoration, MIME preservation, and
  transaction/backup-residue checks.
- **Privileged gates: PASS.** `bash scripts/quality-gate.sh --no-aur` and
  `sudo ./scripts/post-install-smoke.sh --user geo` both exited `0` without
  changing the installed framework or MIME preservation control and without
  leaving updater transaction or backup residue.
- **Current doctor: PASS.** The final read-only host-level `ahr doctor` exited
  `0`.
- **Automated regressions: PASS.** Synthetic harness tests: 13/13; updater
  tests: 445/445; default-app tests: 70/70; doctor tests: 28/28;
  framework-check tests: 18/18. The Artix framework smoke and relevant syntax
  and diff checks also passed.

The Phase 2 exit gate is satisfied. Live validation evidence remains outside
the repository and is intentionally not committed.

Separately recorded, non-blocking findings:

- The first-run lexical ordering/theme-state lifecycle defect predates Phase 2
  and is not a Phase 2 regression. It remains out of scope for this phase.
- SwayOSD remains optional; its absence does not fail doctor, smoke, or the
  underlying volume, brightness, and media controls.
- Docker is not a Phase 2 requirement; its absence does not block the Phase 2
  quality gate or post-install smoke contract.

Implementation decisions:

- Use Evince as the core PDF viewer, `imv` as the core image viewer, `mpv` as
  the core video/audio player, and GNOME Calculator as the core calculator.
  Add their Artix packages to the native package manifests and verify their
  installed desktop-entry IDs instead of assuming upstream names.
- Keep Nautilus and File Roller as the directory and archive handlers. Make
  the removable-device dependency chain explicit, including GVfs/MTP and
  UDisks, and validate mount, open, unmount, and safe-removal behavior from a
  live Nautilus session.
- Add `hyprpicker` to the core desktop because Color Picker is already an
  advertised Capture action and the package is available from the configured
  repositories. Keep SwayOSD optional because it is presentation polish rather
  than a dependency of the underlying volume, brightness, or media controls;
  its startup hook must continue to skip cleanly when it is absent.
- Split OnlyOffice into a supported, opt-in office Flatpak profile. The profile
  must expose its application ID, installation and launch checks, document MIME
  behavior, and removal command without deleting user documents. It remains
  outside the default install and is not used by first-login or recovery paths.

The default-app setup will become data-driven and idempotent for HTTP/HTTPS,
directories, plain text and Markdown, PDF, common image formats, common video
and audio formats, and supported archives. It will set an AHR default only when
no valid handler exists, preserve explicit user choices, and report handlers
whose desktop entries have disappeared. Doctor and post-install smoke will use
the same matrix so setup and validation cannot drift.

Validation will combine isolated tests with a clean Artix live-session run.
Fixtures will cover missing packages, missing and stale desktop entries,
preserved user defaults, repeat execution, and optional-component absence. The
live run will open representative URL, directory, text, PDF, image, audio,
video, and archive samples; exercise a removable device; verify every visible
Capture and Setup action; then repeat the default checks after a reboot and a
framework update. Phase 2 is complete only when that evidence is recorded and
the existing Phase 2 exit gate passes without depending on the office profile,
SwayOSD, AUR software, or another optional application.

## Phase 3: Flatpak Application Catalog

### Goal

Replace raw application-ID entry and static profile files with a curated,
discoverable, reversible Flatpak experience.

### Work

- Define a machine-readable catalog schema.
- Add CLI operations for listing, searching, inspecting, installing, launching,
  and removing catalog applications.
- Organize the catalog into:
  - Communication
  - Office and writing
  - Media
  - Creative
  - Development
  - Gaming
  - System utilities
- Mark entries as default, recommended, optional, experimental, or
  proprietary.
- Show source, download size when available, and permission guidance before
  installation.
- Integrate catalog categories into Install and Remove menus.
- Keep direct `flatpak search`/application-ID installation as an advanced path.
- Include Flatpak update state in `ahr update-available`.
- Add catalog validation for application IDs, desktop entries, and clean
  missing-Flathub behavior.
- Document how Flatseal and Warehouse complement the catalog.

### Initial catalog direction

- Preserve the current default profile: Zen Browser, Flatseal, Warehouse, and
  Gear Lever, subject to live validation.
- Preserve the current optional applications as catalog candidates: OBS Studio,
  Discord, Vesktop, Obsidian, Spotify, Signal, OnlyOffice, EasyEffects, and
  Mission Center.
- Add applications only one category at a time; do not import Omarchy's
  preinstall list wholesale.

### Exit gate

- A user can discover, inspect, install, launch, update, and remove a catalog
  application without knowing its application ID.
- Each supported entry has a validation result and removal story.
- Unofficial wrappers and proprietary applications are visibly distinguished.

## Phase 4: Finish Keyboard-First Workflows

### Goal

Replace menu placeholders with a smaller set of real, dependable workflows.

### Work

- Implement stateful reminders with set, list, and clear operations.
- Add OCR text extraction as an optional capture dependency with language-data
  checks.
- Extend screen recording with explicit no-audio, desktop-audio, microphone,
  and optional webcam modes.
- Add LocalSend-based clipboard/file/folder sharing only after its native or
  Flatpak path and local-network behavior are validated.
- Implement a simple transcode CLI before adding menu or Nautilus integration.
- Add time/date, weather, and battery notices that degrade cleanly.
- Add an emoji/symbol picker path using the selected launcher provider.
- Hide unfinished Trigger entries in release builds or mark them experimental;
  do not present inert “coming soon” actions as finished features.

### Exit gate

- Every visible Trigger action performs work, names a missing supported
  dependency, or is explicitly labeled experimental.
- Capture modes handle cancellation, missing devices, and failed processes
  without leaving stale state.
- Sharing and reminders work from both CLI and menu.

## Phase 5: Hardware, Power, And Session Controls

### Goal

Turn install-time hardware detection into safe daily controls.

### Work

- Add power-profile selection with clear unavailable-service behavior.
- Add reversible internal-display, mirror, and monitor-scaling actions.
- Preserve and expose internal-monitor recovery.
- Add touchpad toggle and consider touchscreen control only after hardware
  testing.
- Add audio output switching and microphone feedback.
- Add keyboard-backlight support where hardware exposes a standard interface.
- Make suspend and hibernate menu availability reflect actual system support.
- Add OpenRC-native service restart/recovery actions for audio, Wi-Fi, and
  Bluetooth.
- Keep hybrid-GPU switching, fingerprint, FIDO2, and device-specific haptics
  experimental until tested hardware and rollback procedures exist.

### Exit gate

- No hardware action can strand the user without a documented recovery path.
- Laptop suspend/resume preserves lock, audio, network, bar, and notification
  behavior.
- Unsupported hardware produces a harmless, useful result.

## Phase 6: Developer And Terminal Experience

### Goal

Offer a coherent development workstation without making large language stacks
part of the desktop base.

### Work

- Add Tmux configuration, launcher integration, and discoverable keybindings,
  or explicitly keep Tmux unconfigured.
- Decide whether AHR owns a Neovim/LazyVim-style configuration or installs plain
  Neovim with documentation.
- Add optional CLI/TUI profiles for tools such as GitHub CLI, Lazygit, and
  Lazydocker after Artix package validation.
- Design opt-in development environments around a version manager rather than
  preinstalling many language runtimes.
- Add editor Flatpaks or native/AUR packages only through the catalog/source
  policy.
- Keep AI agents and local-LLM tools optional, fast-moving profiles with no
  dependency from the core desktop.

### Exit gate

- The terminal/editor/Tmux ownership boundary is documented.
- Optional development profiles are independently installable and removable.
- AHR updates do not overwrite user projects or unowned editor configuration.

## Phase 7: Visual Cohesion, Manual, And Stable Release

### Goal

Turn implemented features into a product that is understandable and supportable.

### Work

- Expand theme application only for supported applications, with missing assets
  remaining non-fatal.
- Decide the supported scope for lock-screen, corner, Waybar-position, and
  branding customization.
- Create an AHR user manual organized around the actual menu and workflows.
- Clearly label supported, optional, experimental, intentionally different, and
  unsupported features.
- Capture real first-login, launcher, menu, theme, application-catalog, capture,
  and recovery screenshots.
- Reconcile support claims with current validation bundles.
- Run clean-install and upgrade usability tests with someone who has not read
  the source documentation.

### Stable gate

- Framework update and rollback have been exercised across at least one release.
- Core default applications and MIME handling pass on real hardware.
- Flatpak catalog operations pass with and without optional applications
  installed.
- Supported GPU, laptop, TTY, and `greetd` claims have evidence or explicit
  limits.
- Portal screen sharing and suspend/resume are live validated.
- Menus, docs, release notes, and health-check language agree.
- No visible menu item is merely a placeholder.

## Later Or Optional Tracks

These tracks must not block the core roadmap:

- Gaming profiles using validated native or Flatpak packages.
- Additional communication, creative, and media Flatpaks.
- OpenRC-native optional services such as Tailscale.
- Fingerprint and FIDO2 authentication with tested PAM rollback.
- Filesystem-specific snapshot integration.
- Additional terminal and editor choices.
- Distribution image/profile work if user demand eventually justifies it.

## Explicit Non-Goals

- A line-for-line Omarchy clone.
- A Chromium-centered web-app installer or bundled web-service launchers.
- Making Chromium a hidden dependency for optional applications.
- Porting systemd, UWSM, SDDM, Plymouth, or Limine maintenance behavior into
  OpenRC paths without an independently justified AHR design.
- Preinstalling broad gaming, AI, commercial, social, or development suites.
- A Windows VM workflow as part of the supported desktop.
- Automatic destructive cleanup of application data.
- Chasing Omarchy alpha changes before their value and stability are clear.

## Immediate Implementation Slices

Work should begin with small vertical slices:

1. Add framework version/source metadata and make
   `ahr update-available` report framework state without changing anything.
2. Reconcile `imv`, `mpv`, PDF, calculator, SwayOSD, and `hyprpicker` decisions
   with package manifests and the default-app smoke test.
3. Define the Flatpak catalog schema and migrate the existing default/optional
   lists without changing installed application behavior.
4. Implement one catalog category end to end, including install, launch,
   validation, update visibility, and removal.
5. Replace Reminder’s placeholder with the first complete Trigger workflow.

Each slice must include automated checks where practical, a live-test procedure,
documentation, and an explicit rollback/removal story.
