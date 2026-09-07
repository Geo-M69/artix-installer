# Artix Hypr Remix Architecture Context

This document is the architecture memory for Artix Hypr Remix (AHR). It is
intended to give a future contributor or AI assistant enough stable context to
reason about the project without access to the repository or prior
conversations. It describes product-roadmap Phases 1, 2, 3a, 3b, 3c, and 3d,
plus the accepted Phase 3 hardening evidence completed after 3d.

## Status And Evidence Boundary

The supported snapshot in this document stops after **Phase 3e:
category-driven Install/Remove menus**. The current command contract is `list
[--category CAT] [--format menu]`, `search`, `info`, `status [--category CAT]
[--installed] [--format menu]`, `validate`, `install`, `launch`, `remove`, and
`update`. It also includes the documentation-only Flatseal/Warehouse boundary,
offline catalog-entry validation, read-only live availability evidence,
out-of-band drift regressions, normalized lifecycle diagnostics, and the
menu regression suite. These hardening slices add no schema, scope, purge,
remote metadata, or bulk lifecycle behavior. User-scope Flatpaks and schema
expansion remain unfinished and must not be inferred from them.

The accepted Phase 3 exit-gap repairs keep that contract intact: `ahr
update-available` reports a failed Flatpak update query as `query-failed`
instead of a current state, all `status` Flatpak execution runs through the
runtime library (the catalog library interprets data only), and a failing
catalog query in the Install/Remove menus surfaces a diagnostic instead of
presenting misleading catalog choices.

Status terms used below are deliberate:

- **Confirmed implementation fact** means it is present in the Phase 3d
  implementation, its accepted hardening evidence, or its Phase 1/2 foundation
  and is covered by repository evidence.
- **Architectural decision** means a design choice future work should preserve
  unless it is explicitly superseded.
- **Constraint** means a safety, compatibility, or scope boundary that must not
  be violated casually.
- **Unresolved** means the repository has not yet selected or accepted a final
  product behavior.
- **Roadmap** means intended work, not implemented behavior.

# Project Identity

Artix Hypr Remix is an opinionated, keyboard-first Hyprland desktop and
installer for Artix Linux with OpenRC. Its goal is an Omarchy-quality daily
desktop experience adapted to Artix rather than a literal Omarchy clone. The
supported base is a fresh or minimal Artix/OpenRC installation with `pacman`,
network access, Bash, and an existing non-root desktop user.

The project aims to make installation, first login, maintenance, framework
updates, recovery, and ordinary desktop tasks coherent and repeatable. It is a
script-first system: shell entrypoints, small libraries, declarative manifests,
and explicit state files are preferred over a daemon, package-manager
replacement, or large application framework.

Its application policy has two primary lanes:

- Core desktop and system integration are native-package-first. Hyprland,
  portals, audio, networking, OpenRC services, launchers, recovery tools, and
  other boot/session dependencies must not depend on Flatpak.
- Optional graphical applications are Flatpak-first when upstream distribution
  provides a useful isolation and portability boundary. Flatpak applications
  must remain optional unless a later product decision explicitly promotes
  one.

AHR modifies systems conservatively. It validates before mutation, uses full
`pacman -Syu` transactions rather than partial-upgrade patterns, backs up
replaced configuration, makes framework delivery transactional and
recoverable, keeps migrations incremental, and preserves user choices and data
where ownership is uncertain.

AHR intentionally avoids:

- systemd assumptions or `systemctl`-based service integration;
- display managers other than the optional OpenRC-compatible `greetd` path;
- line-for-line Omarchy parity;
- a Chromium-centered web-application runtime;
- making optional GUI applications prerequisites for login or recovery;
- wholesale import of another distribution's application catalog;
- mandatory filesystem snapshot technology or an assumed filesystem layout;
- broad reset, uninstall, or destructive cleanup without explicit ownership;
- ISO/profile distribution work before the script installer is dependable.

# Architecture Principles

## Safety Principles

1. **Validate before mutating.** Catalog schema and selectors, staged framework
   contents, target paths, manifests, and required commands are checked before
   the related mutation. This exists so malformed data cannot become shell or
   package-manager input and partial operations fail as early as possible.

2. **Preview consequential actions.** Catalog install, remove, and update
   operations print concise plans; configuration replacement requires
   confirmation unless explicitly pre-approved; restore operations default to
   dry-run. This keeps scope and ownership visible to the operator.

3. **Prefer idempotent operations.** Installer phases, migrations, first-run
   tasks, profile installation, and catalog lifecycle no-ops are designed to be
   safe to retry. Interrupted or partially completed work is normal operating
   reality, not an exceptional afterthought.

4. **Back up before replacement.** User configuration is copied to timestamped
   backups before installer replacement. Framework updates back up every
   managed target and relevant derived state before activation. This exists
   because AHR cannot assume an existing installation is disposable.

5. **Preserve user data by default.** Application removal must not silently
   delete documents or per-application data. User-created themes, browser
   profiles, shell history, projects, and arbitrary configuration are outside
   automatic cleanup. Explicit purge, if ever generalized, requires a separate
   product decision and a precise plan.

6. **Fail closed at trust boundaries.** Catalog JSON is data, never shell
   input. IDs, slugs, and desktop-entry names are constrained; selectors must
   resolve through the catalog before catalog-managed mutation. Framework
   transactions and backup associations are parsed as data and cross-checked,
   never sourced as shell code.

7. **Separate synthetic, offline, and live evidence.** Deterministic offline
   tests protect code and compatibility contracts in the quality gate. Dated,
   read-only live checks test time-sensitive upstream assumptions but never
   mutate Flatpak state and never become a prerequisite for the offline gate.
   This prevents network availability from weakening CI while avoiding false
   claims that stubs prove current Flathub or desktop behavior.

## Compatibility Principles

1. **Artix/OpenRC is the native platform.** Service enable/start logic uses
   OpenRC and package assumptions must be validated on Artix. This avoids
   importing systemd behavior that can break boot or session recovery.

2. **Keep core operation independent of optional applications.** First login,
   doctor, repair, framework update, and recovery must work without OnlyOffice,
   SwayOSD, or any optional catalog application. This protects the minimum
   supported desktop and makes optional failures non-catastrophic.

3. **Preserve existing public modes and ordering.** Flatpak profiles retain the
   meanings `default`, `optional`, `all`, and `none`; Phase 3a preserved all 13
   prior Flatpak IDs and their order. Ordering is observable installer behavior
   and cannot change accidentally.

4. **Keep startup modes behind one launcher.** Both TTY startup and optional
   `greetd` invoke the same Hyprland session launcher. This prevents two
   startup implementations from drifting.

5. **Use the command namespace as the public shell interface.** `ahr` dispatches
   to focused `ahr-*` programs installed under the framework. Menu UIs and
   other callers should invoke these public commands instead of copying their
   policy logic.

## Migration Principles

1. **Migrate incrementally, in sortable order.** Migrations are small scripts
   named with a date prefix and executed in filename order. This makes changes
   auditable and lets old installs move forward without reinstalling.

2. **Make migrations idempotent and narrow.** They check target existence,
   prefer new files or managed blocks, and skip absent optional features. This
   minimizes damage to user-edited configuration.

3. **Record outcomes durably.** Applied and skipped markers and a migration log
   live in user state. A failed or skipped migration remains visible and can be
   reviewed or retried.

4. **Do not confuse marker rollback with side-effect rollback.** Framework
   rollback restores migration marker snapshots exactly, but arbitrary changes
   a migration made elsewhere may persist. Every migration must therefore own
   its backup and recovery story.

5. **Keep old behavior readable during transitions.** Existing formats or
   entrypoints should remain usable for at least a migration window when
   practical. Replacement requires tests and an explicit compatibility plan.

## Data Ownership Principles

1. **Framework-owned data** lives primarily under
   `~/.config/artix-hypr-remix/`. The updater owns the `bin/`, `migrations/`,
   `docs/`, `hooks/`, `first-run.d/`, and `default/` targets plus
   `framework.json`. The Flatpak catalog is framework-owned beneath `default/`
   and is replaced and rolled back with that target.

2. **Runtime state** lives primarily under
   `~/.local/state/artix-hypr-remix/`. Installer progress, first-run results,
   migration markers, update transactions, backups, locks, and logs are state,
   not source configuration.

3. **Cache data** belongs under `~/.cache/artix-hypr-remix/` and must never be
   authoritative for apply. In particular, framework apply and dry-run use a
   fresh checkout; the remote-version cache is read-only acceleration for
   status checks.

4. **User-owned data and choices** include documents, projects, app data,
   browser profiles, user-created themes/backgrounds, and edits outside a
   declared managed area. AHR may inspect them but must not overwrite or delete
   them without a specific, explicit contract.

5. **System-owned state** includes pacman/AUR packages, OpenRC services, and
   the system Flatpak installation. Framework rollback does not imply package,
   service, or application rollback.

## Scope Boundaries

- The installer installs a desktop; it is not a general package manager.
- The catalog curates supported Flatpak identities; it is not a live Flathub
  mirror or remote search engine.
- The framework transaction protects AHR framework targets; it is not a whole
  system snapshot.
- The default-app matrix manages a defined set of MIME categories while
  preserving any valid existing handler; it does not claim all MIME types.
- Flatseal and Warehouse complement AHR's catalog but do not replace its
  policy, validation, or stable identities (`docs/FLATSEAL_WAREHOUSE.md`).
- Menus are presentation and dispatch layers. They must not become a second
  catalog parser or Flatpak policy implementation.

# Current System Architecture

## Installer Layer

The top-level Bash installer is phase-based, records progress, supports
bounded reruns with `--from-phase`/`--phase`, and defaults to completing through
phase 7. Phase 8 is an explicit opt-in development baseline.

1. Preflight validates Artix host policy, commands, repository inputs, and
   target-user context required by the requested phase window.
2. Native packages are collected from ordered manifests, augmented by guarded
   hardware/Docker/printing profiles, availability-checked, and installed only
   after a full package database refresh and upgrade transaction.
3. Required and optional OpenRC services are validated and enabled/started with
   different failure policies.
4. Repository configuration is deployed to the target user's XDG config tree
   using copy plus timestamped backup-before-replace.
5. Startup is configured as TTY by default or optional `greetd`, both through
   the shared Hyprland session launcher.
6. Core AUR packages are fail-fast, optional AUR packages warn and continue,
   and the selected Flatpak profile is installed.
7. First-run/post-install state is prepared and post-install smoke validation
   runs before the reboot offer.
8. An optional Git/GPG/SSH baseline uses guarded managed blocks and one-time
   backups.

Application installation follows the product policy rather than a single
mechanism: core software comes from Artix/pacman, AUR is an exception path,
and optional GUI applications come from Flatpak. In installer phase 6, Flatpak
profile refs are derived from the validated catalog in catalog order. The
installer checks local system installation state, ensures a system-scoped
Flathub remote when needed, installs missing refs one at a time with
noninteractive system scope, and stops on an installation failure. Dry-run
resolves and prints the catalog-derived plan without touching Flatpak.

`--flatpak-profile default` is the default. `optional` installs only entries
marked optional, `all` installs all entries in catalog order, and `none` or
`--skip-flatpak` performs no Flatpak work.

## Framework Delivery Layer

The installed framework lives at `~/.config/artix-hypr-remix/`. Its managed
directory targets are:

- `bin/`
- `migrations/`
- `docs/`
- `hooks/`
- `first-run.d/`
- `default/`

`framework.json` is managed metadata alongside those targets. The catalog is
inside `default/flatpak/catalog.json`, so no separate catalog updater or
out-of-band copy path exists.

For dry-run and apply, the updater clones the configured source into a staging
directory once, resolves and pins the exact Git commit, reads and validates the
candidate metadata, and rechecks the commit before activation. Staged
validation verifies version/channel metadata, required targets and commands,
catalog validity, shell syntax, file types, and symlink containment. An invalid
catalog fails before backup or activation.

Apply creates a collision-resistant transaction and verified backup, prepares
each target, activates targets transactionally, writes pinned framework
metadata, reinstalls the command namespace, runs a runtime smoke check,
executes migrations, and runs `ahr-doctor`. The update is a durable multi-step
transaction, not an assertion that every system side effect is globally
atomic.

Rollback is one level and prevalidates the complete backup before its first
mutation. It restores the framework targets and exact applied/skipped migration
marker snapshots. It cannot reverse arbitrary external migration side effects
or package/Flatpak operations.

Recovery uses durable per-transaction phase and per-target progress. An
incomplete transaction blocks new apply/rollback work until explicit recovery.
Signal handlers attempt reverse-order restoration; persisted restore-complete
checkpoints make recovery and rollback finalization restart-safe even when a
process cannot trap `SIGKILL`. Backup-to-transaction identity is immutable and
cross-checked to prevent restoration from an unrelated backup.

## Application Management Layer

The application layer is intentionally split into three responsibilities:

- **Catalog library:** validates schema-v1 JSON, emits ordered rows, selects
  profiles, performs local search, and resolves exact selectors. It owns data
  interpretation, not Flatpak execution.
- **Runtime library:** owns small, reusable system-scoped Flatpak primitives:
  command availability, local installation check, Flathub presence/bootstrap,
  installation, launch, removal, targeted update, and expected system
  desktop-entry lookup. At the Phase 3d boundary it does not own presentation,
  selector parsing, catalog schema, menus, generic remote discovery, or product
  policy.
- **CLI layer:** `ahr` dispatches `ahr flatpak ...` to a thin command program.
  The command program resolves catalog data, prints user-facing plans/results,
  and composes catalog and runtime library functions. It should not reimplement
  either library. The local-installation state column behind `status` is added
  here by composing catalog rows with runtime-library checks
  (`ahr_flatpak_require_command`, `ahr_flatpak_system_ref_installed`), so the
  catalog library itself performs no Flatpak execution and every query honors
  `AHR_FLATPAK_COMMAND` at system scope.

Menu integration became part of Phase 3e. The Install and Remove menus now
offer `Flatpak Apps (Catalog)` category discovery that calls the catalog CLI
(`ahr flatpak list --category … --format menu` and `ahr flatpak status
--category … --installed --format menu`) and dispatches resolved slugs to `ahr
flatpak install <slug>` and `ahr flatpak remove <slug>`. They remain
presentation/dispatch only: they do not parse JSON, source the catalog or
runtime libraries, or duplicate Flatpak lifecycle logic. Clearly labeled
`Advanced: Install/Remove by Flatpak ID…` entries remain at the bottom and keep
the interactive raw `flatpak install --system flathub <id>` / `flatpak
uninstall --system <id>` paths as bypasses; they never pass `--delete-data`. A
failed catalog CLI query (invalid or missing catalog) is never collapsed into
an empty-category result: the menus print an actionable diagnostic pointing at
`ahr flatpak validate`, present no catalog choices (including the all-apps
entry), return cleanly to the parent menu, and never fall back automatically to
the advanced raw-ID path.

Flatseal and Warehouse are default-profile applications that complement this
layer without participating in it. Flatseal owns user-directed permission
overrides; Warehouse can expose broader installation, remote, scope, and data
management. Neither tool understands catalog slugs, profiles, support labels,
or lifecycle policy, and no AHR command, hook, doctor check, migration, or menu
invokes either tool.

State changed through those tools or raw Flatpak commands is out-of-band. The
catalog treats only system-scope state as authoritative: a user-scope-only
catalog app reads as not installed, a non-catalog system app is ignored by
catalog-wide update, and a system-installed catalog app with a missing expected
desktop entry still reads as installed but cannot be launched through the
catalog. Catalog install remains an idempotent no-op for that last state; it
does not attempt export repair.

The Phase 2 `ahr-onlyoffice` helper remains a dedicated compatibility
prototype. It predates the general catalog CLI, is opt-in, uses system scope,
documents office MIME behavior, and has its own explicit data-preserving
removal/purge contract. Its existence does not make purge a general Phase 3d
catalog capability.

## Testing Layer

AHR uses layered regression evidence:

- The host-independent quality gate is the repository's enforced CI check for
  changes under `artix-hypr-remix/**`. It runs shell syntax, OpenRC portability,
  first-run idempotency, Docker-profile, six Flatpak suites (catalog, CLI,
  operations, lifecycle, drift, and menu), the offline catalog-entry validator,
  and core/full dependency checks. On a non-Artix host, `--no-aur` skips only
  the full AUR-dependent manifest check.
- Phase 3a's isolated catalog test validates the canonical catalog, every
  required field/type/enum, identifier safety, duplicate rejection, exact
  legacy-profile equivalence, ordering, invalid-data fail-before-Flatpak, and
  installer idempotency.
- Phase 3b's isolated CLI test runs with temporary homes and a stub Flatpak
  executable. It verifies ordering, search/selector semantics, offline schema
  behavior, system-only local status calls, dispatcher wiring, and namespace
  installation.
- Phase 3c's isolated operations test stubs all Flatpak effects and the system
  desktop-entry directory. It verifies exact command arguments, plan output,
  idempotency, missing-remote bootstrap, clean failure boundaries, raw-ID
  rejection, installed-state checks, desktop-entry checks, and launch failure
  reporting.
- Phase 3d's isolated lifecycle test verifies system-scoped uninstall and
  update arguments, removal plans, preservation of application data, safe
  already-absent behavior, catalog-wide installed-entry filtering and ordering,
  no-op behavior, and fail-before-Flatpak handling for invalid catalogs and
  selectors.
- The Phase 3e menu regression suite (`scripts/test-flatpak-menu.sh`) stubs the
  terminal launcher and Flatpak command, then drives the TTY menu backend with
  scripted input. It verifies category/order behavior, empty-category omission,
  installed-only removal discovery, menu-level `[Proprietary]`/`[Unofficial]`
  label rendering, exact slug dispatch, cancellation, missing-Flatpak handling,
  and advanced-path isolation/system scope without `--delete-data`. It also
  proves the catalog-query failure path: an invalid or missing catalog surfaces
  an actionable diagnostic pointing at `ahr flatpak validate`, presents no
  catalog choices (including the all-apps entry), exits to the parent menu, and
  never auto-falls back to the advanced raw-ID path. Menus are proven to be
  presentation/dispatch only: they call the catalog CLI and never parse JSON or
  source catalog/runtime libraries.
- The out-of-band drift slice (`scripts/test-flatpak-drift.sh`) models system
  state changed outside the catalog — user-scope installs, non-catalog system
  installs, and missing or leftover desktop-entry exports — using a stub
  `flatpak` with separate user and system pools. It proves catalog commands
  never query user scope, that user-scope and non-catalog installs stay
  non-authoritative for status, install, launch, remove, and update, and that
  an installed application missing its expected desktop entry is surfaced
  consistently (status `installed`, explicit full-path launch refusal,
  idempotent install no-op). It also pins the normalized operator-facing
  wording: one `Name (ID) is not installed for system scope` phrase across
  launch, remove, and update; one scope-qualified
  `is <state> for system scope; no changes made.` no-op skeleton shared by
  install and remove; and update failures that name their concrete targets in
  the same `Name (ID)` style as install and removal failures. These are
  diagnostic-wording clarifications of documented
  `docs/FLATSEAL_WAREHOUSE.md` behavior, not new commands, states, or policy.
- A focused catalog-entry validation layer
  (`scripts/validate-flatpak-catalog-entries.sh`) pins the current
  application-availability assumptions — the exact 13 slug/Flatpak-ID pairs in
  catalog order — and the expected desktop-entry convention
  (`desktop_entry == "<flatpak-id>.desktop"`) for every existing entry. Its
  default mode is offline and host-independent and runs in the quality gate.
  `--live-flathub` adds a strictly read-only live re-check of every catalog ID
  against the configured Flathub remote summary; it never bootstraps remotes,
  never mutates Flatpak state, and is never required by the offline gate.
- The Phase 3b CLI suite additionally proves the offline guarantee directly:
  `list`, `search`, `info`, and `validate` never invoke Flatpak at all, and
  `status` degrades to a clean `unavailable` state for every row when the
  Flatpak command is absent. The suite also pins the status/runtime boundary:
  `status` queries installation state (and tests availability) exclusively
  through the configured `AHR_FLATPAK_COMMAND` via the runtime library — a
  differently-named configured stub receives every call while a PATH `flatpak`
  stays untouched — and a static check proves the catalog library contains no
  direct Flatpak execution.
- A focused `ahr-update-available` reporting suite
  (`scripts/test-update-available-flatpak.sh`) runs the command under a
  controlled PATH with a stub `flatpak remote-ls` in both human and JSON modes.
  It pins the three Flatpak states: a successful zero-update query stays
  `current` with count zero, updates keep their existing count, a failed
  remote/query reports `query-failed` (never `current`, never "No updates
  pending") with an actionable diagnostic and no contribution to the pending
  total, and a missing command remains `unavailable`.
- Framework updater regression tests verify that the catalog travels inside
  the managed `default/` target, is activated and restored with that target,
  and is rejected during staged validation before a backup is created.
- Doctor, post-install smoke, and clean-host validation cover different
  contracts. Synthetic tests are required but are not substitutes for live
  Artix/Hyprland evidence where real desktop, hardware, portal, or application
  behavior matters.

At the latest document review, the focused Phase 3a–3d suites passed 42/42,
29/29, 13/13, and 14/14 assertions, the offline catalog-entry validator passed
its 3 pinned-assumption assertions, the out-of-band drift slice passed 12/12
assertions, the Phase 3e menu regression suite passed 17/17 assertions, and the
`ahr-update-available` Flatpak reporting suite passed 9/9 assertions. This
confirms the isolated contracts; it
does not complete the broader Phase 3 exit gate, and the synthetic suites alone
do not prove catalog applications against current Flathub metadata.

Live evidence is deliberately separate from synthetic evidence. On
2026-09-05, a read-only live pass on an Artix host with a system-scoped
Flathub remote found all 13 catalog IDs in the current Flathub summary, and
all 13 catalog-declared desktop entries were exported for the installed
system set under `/var/lib/flatpak/exports/share/applications`.
`./scripts/validate-flatpak-catalog-entries.sh --live-flathub` refreshes only
the Flathub-ID availability portion. Desktop-entry export evidence requires a
separate installed-system check. Neither live check is part of the offline
quality gate.

# Phase History

These are **product roadmap phases**, not the installer's numbered execution
phases.

## Phase 1: Framework Delivery And Recovery

**Problem solved.** Before Phase 1, updating AHR risked replacing the very
scripts needed to diagnose or recover an update. The project needed a safe way
to deliver its own framework independently of system-package and Flatpak
updates.

**Foundations created.** Phase 1 established version/channel/source metadata,
fresh staged checkouts pinned to an exact commit, recursive staged validation,
exclusive durable transactions, verified framework backups, per-target
activation progress, command-namespace repair, ordered migrations,
post-activation smoke and health checks, explicit recovery, one-level rollback,
and scoped component restore. It also separated framework, package, Flatpak,
theme, and migration update reporting.

**Why later phases depend on it.** The Flatpak catalog, its libraries, CLI, and
future migrations are framework assets. Because Phase 1 owns their delivery,
Phase 3 can change catalog behavior without inventing another updater and can
reject an invalid candidate before activation. Phase 1 completed both
implementation and the documented Artix recovery/rollback validation campaign.

Accepted limitations remain: migration side effects are not generally
reversible, `SIGKILL` relies on persisted checkpoints rather than traps, and
framework rollback does not roll back system packages or applications.

## Phase 2: Complete Daily-Desktop Baseline

**Problem solved.** The desktop referenced applications and MIME handlers that
were not consistently installed or validated, and ordinary file workflows
could drift between setup and doctor checks.

**Default application matrix.** A single shell data source is consumed by
first-run setup, installed doctor, repository doctor, post-install smoke, and
tests. The accepted baseline is:

- browser for HTTP/HTTPS/HTML, preserving a valid installed choice;
- Nautilus for directories and removable-device browsing;
- Helix/Neovim/Vim candidates for text and Markdown;
- Evince for PDF;
- imv for images;
- mpv for both video and audio;
- File Roller for archives;
- GNOME Calculator for calculator launch state.

Setup assigns an AHR candidate only where no valid handler exists. Desktop
entries are resolved across user, native-system, and user/system Flatpak export
roots. Stale configured handlers are detected; arbitrary valid user choices
are preserved.

**OnlyOffice prototype.** OnlyOffice is a supported opt-in system Flatpak and
is also an optional-profile entry. It is excluded from the default install,
first login, recovery, and framework-update requirements. The dedicated helper
demonstrated install/status/launch/MIME/removal behavior and the rule that
documents are never deleted and application data is preserved unless the user
explicitly requests the helper's narrowly scoped `--purge`.

**Optional-application rules.** Optional software may not become a health,
login, or recovery dependency. Its absence must fail or skip cleanly according
to its advertised support level. SwayOSD is a concrete example: presentation
polish remains optional while the underlying controls remain functional.

Phase 2 completed implementation and clean Artix live validation, including
real MIME launches, physical removable media, reboot preservation, framework
update preservation, and regression suites.

## Phase 3a: Flatpak Catalog Foundation

**Problem solved.** Static profile text files and raw application IDs could not
support stable identities, categories, trust labels, discovery, or consistent
validation.

**Foundation.** Phase 3a introduced the framework-owned JSON catalog and a
single catalog parsing/validation library. The schema carries stable slug,
display name, Flatpak ID, category, installer profile, support label,
proprietary/unofficial flags, and expected desktop entry.

**Migration strategy.** The catalog became runtime source of truth immediately,
while the old `flatpaks/default.txt` and `flatpaks/optional.txt` files remained
temporary regression fixtures. Tests derive each profile from the catalog and
require exact equality with the legacy lists. Runtime does not fall back to the
legacy files. This is a compatibility bridge, not dual ownership.

**Compatibility guarantees.** All 13 pre-existing IDs and their installation
order were preserved. The four profile modes retained their existing meaning.
An invalid catalog stops installer profile resolution before any Flatpak
operation. Nesting the catalog under the existing transactional `default/`
target also allowed delivery without creating a new framework target.

## Phase 3b: Read-Only Catalog CLI

**Problem solved.** Users and scripts needed a stable catalog interface without
parsing JSON themselves or requiring a network request.

**CLI and offline design.** Phase 3b added the `ahr flatpak` command group and
read-only list, search, info, status, and validation behavior. Catalog reads
are local. Status calls only `flatpak info --system`; it does not query Flathub.
This makes catalog inspection deterministic and usable offline.

**Query behavior.** List preserves catalog order. Search is a
case-insensitive substring match over slug, display name, Flatpak ID, and
category, also preserving order. Info and a status selector use an exact,
case-insensitive match on slug, name, or Flatpak ID. Zero matches fail for
exact lookup; ambiguous names are rejected. Search with zero matches reports
an empty result successfully.

## Phase 3c: Catalog-Managed Install And Launch

**Problem solved.** Read-only discovery still forced users or callers to drop
to raw Flatpak commands, which bypassed catalog identity and duplicated
installer behavior.

**Install architecture.** The CLI resolves exactly one validated catalog row,
prints application, ID, remote, and system scope, checks for Flatpak, returns
success without mutation when already installed, bootstraps the system Flathub
remote only when absent, and installs the catalog ID noninteractively. Unknown
or non-catalog raw IDs are rejected before Flatpak is touched.

**Launch architecture.** The CLI resolves the catalog entry, verifies the app
is installed at system scope, requires the catalog-declared desktop-entry file
under the system Flatpak export directory, and then runs the app by ID with
`flatpak run --system`. Missing installation, desktop entry, command, or run
failure is reported explicitly.

**Shared runtime extraction.** Installer and CLI use the same small Flatpak
runtime primitives for local state, Flathub bootstrap, installation, desktop
entry verification, and launch. The installer retains orchestration and
profile summaries; the CLI retains selector and presentation behavior.

**Safety guarantees.** Schema validation and exact catalog lookup happen
before mutation; scope is always system for the catalog-managed path; install
is idempotent; a missing remote is added with `--if-not-exists`; no raw-ID
bypass is accepted by catalog install/launch; and Phase 3c performs no removal
or purge.

## Phase 3d: Catalog-Managed Removal And Updates

**Problem solved.** Catalog applications could be discovered, installed, and
launched, but completing their ordinary lifecycle still required raw Flatpak
commands whose scope and target set were not bounded by the catalog.

**Removal architecture.** The CLI resolves exactly one validated catalog entry
before constructing or displaying its application-data path. It prints the
application, ID, system scope, and explicit data-preservation result; treats an
already-absent system application as a successful no-op; and otherwise invokes
a noninteractive system uninstall for that application only. It never passes
Flatpak's data-deletion option and never deletes `~/.var/app/<flatpak-id>`.
Catalog removal has no purge option.

**Update architecture.** With a selector, the CLI resolves one catalog entry,
requires it to be installed at system scope, prints the plan, and updates only
that ID. Without a selector, it checks every catalog entry locally in catalog
order, builds a list containing only installed catalog IDs, and passes that
ordered list to one system-scoped Flatpak update operation. An empty installed
set is a successful no-op.

**Ownership boundary.** `ahr flatpak update` is deliberately catalog-scoped.
It does not delegate to `ahr update --flatpak`, because that broader workflow
can orchestrate system packages, AUR, unrestricted Flatpak updates, migrations,
and post-update hooks. Catalog update must not mutate non-catalog Flatpaks or
unrelated subsystems. Separately, `ahr update-available` already reports a
global Flatpak update count using `flatpak remote-ls --updates`; that report is
remote-backed and not catalog-scoped. A failed query is reported as
`flatpak_state: "query-failed"` (human output says the Flatpak state is
unknown and how to reproduce the query) rather than as a current state, and it
contributes nothing to the pending total; only a missing `flatpak` command
reports `unavailable`.

**Safety guarantees.** Removal and selected update reject unknown raw IDs and
invalid catalogs before Flatpak is called. All lifecycle operations retain
system scope. Removal preserves application data even when uninstall fails;
update rejects a selected application that is not installed; and both commands
report underlying Flatpak failures clearly.

## Post-3d Phase 3 Hardening

These completed slices strengthen evidence and documentation without expanding
the Phase 3d command or schema contract:

- **Flatseal/Warehouse boundary:** `docs/FLATSEAL_WAREHOUSE.md` assigns
  permission management and broad installation-level management to those
  external GUIs while preserving catalog identity, validation, system scope,
  bounded update, and data-preserving removal as AHR responsibilities.
- **Catalog-entry validation:**
  `scripts/validate-flatpak-catalog-entries.sh` uses the shared catalog library
  and pins the 13 slug/Flatpak-ID pairs in order plus the
  `<flatpak-id>.desktop` convention. Its duplicated expected-entry set is an
  evidence fixture only, never a runtime source of truth. Optional
  `--live-flathub` reads the configured remote summary without adding a remote
  or changing installed state.
- **Out-of-band drift regression:** `scripts/test-flatpak-drift.sh` models
  separate user/system pools, non-catalog installs, and mismatched desktop
  exports. It pins the catalog-visible state boundaries without adding repair
  behavior.
- **Diagnostic normalization:** lifecycle commands use consistent
  system-scope state language, and failed catalog updates identify their
  concrete `Name (ID)` targets in catalog order. This is an operator-facing
  wording contract, not a new state model.
- **Phase 3 exit-gap repairs:** three audit findings were fixed without
  expanding the contract. `ahr update-available` distinguishes a failed
  `flatpak remote-ls --updates` query (`query-failed`) from a genuinely
  current state in human and JSON output. The catalog library no longer
  performs Flatpak execution: the `status` installation-state column is
  composed by the CLI from catalog rows plus runtime-library primitives,
  consistently honoring `AHR_FLATPAK_COMMAND`. Catalog-menu population shows
  an actionable `ahr flatpak validate` diagnostic on invalid/missing-catalog
  query failure instead of presenting misleading catalog choices or silently
  falling back to the raw-ID path. Focused regression coverage was added for
  all three, including menu-level `[Proprietary]`/`[Unofficial]` label
  assertions.

# Current Flatpak Architecture

## Catalog

The source catalog is
`config/artix-hypr-remix/default/flatpak/catalog.json`; after deployment it is
`~/.config/artix-hypr-remix/default/flatpak/catalog.json`. It is owned by the
AHR framework and delivered inside the transactional `default/` target. Users
should not treat edits to the installed copy as durable customization.

Schema version is integer `1`. The top-level object contains a nonempty ordered
`applications` array. Every entry requires:

- `slug`: lowercase kebab-case stable identity;
- `name`: nonempty display name;
- `flatpak_id`: constrained reverse-DNS-style application ID;
- `category`: one of communication, office-writing, media, creative,
  development, gaming, or system-utilities;
- `profile`: default or optional;
- `support`: default, recommended, optional, or experimental;
- `proprietary` and `unofficial`: independent booleans;
- `desktop_entry`: a safe plain `.desktop` filename.

Validation checks top-level shape/version, required fields, types, allowed
enums, safe slug/ID/desktop-entry formats, and uniqueness of slugs and Flatpak
IDs. It does not query Flathub, validate download size or permissions, prove
remote existence, enforce unique display names, or prove the desktop entry is
installed. Those are deliberately different responsibilities.

Selector resolution is exact and case-insensitive over slug, display name, or
Flatpak ID. Slug and ID are schema-unique; a non-unique name produces an
ambiguous-selector error. Search is broader substring matching but never
changes catalog order.

The preserved catalog population is 13 applications: default contains Zen
Browser, Flatseal, Warehouse, and Gear Lever; optional contains OBS Studio,
Discord, Vesktop, Obsidian, Spotify, Signal, OnlyOffice, EasyEffects, and
Mission Center. The schema and offline fixtures alone are not proof of current
upstream state. The latest recorded read-only evidence, dated 2026-09-05,
found all 13 IDs on Flathub and all 13 declared desktop entries in the installed
system export directory; that evidence is time-sensitive and separate from the
catalog contract.

## Runtime Library

At the Phase 3d contract boundary, the runtime library owns system-scoped
mechanics:

- detect the configured Flatpak executable;
- test whether a ref is installed locally at system scope;
- test for the system `flathub` remote;
- add that remote idempotently from the configured Flathub repository URL;
- install one ID noninteractively from Flathub at system scope;
- uninstall one ID noninteractively at system scope without deleting data;
- update one or more explicitly supplied IDs at system scope;
- locate an expected desktop entry in the system Flatpak export directory;
- launch one ID at system scope.

It does not own JSON/schema knowledge, catalog/profile selection, user-facing
tables and plans, menu navigation, arbitrary remote search, broad system update
orchestration, MIME policy, purge, or user-data deletion. Keeping mechanics
separate prevents installer and CLI drift without creating a generic package
abstraction. Every local system-installation query — including the state column
behind `ahr flatpak status` and its category variant — must route through this
library's primitives so `AHR_FLATPAK_COMMAND` and system scope are honored in
one place; the catalog library performs no Flatpak execution at all.

## CLI

The accepted Phase 3d commands are:

| Command | Purpose and important behavior | Current limitation |
|---|---|---|
| `list [--category CAT] [--format menu]` | Prints all entries or one exact category in catalog order. `--format menu` emits a headerless TSV (`slug<TAB>name<TAB>support<TAB>proprietary<TAB>unofficial`). | Local catalog only; it does not show remote freshness, permissions, size, or install state. |
| `search <query>` | Case-insensitive substring search over slug, name, ID, and category; zero matches is a successful empty result. | No remote Flathub search, fuzzy ranking, tags, or category UI. |
| `info <selector>` | Prints all schema-v1 fields for one exact case-insensitive slug/name/ID match. | Catalog metadata only; name ambiguity is rejected and remote metadata is absent. |
| `status [selector] [--category CAT] [--installed] [--format menu]` | Reports `installed`, `not-installed`, or `unavailable` for all entries, one exact selector, or one exact category, by composing catalog rows with runtime-library system-scope installation checks (honoring `AHR_FLATPAK_COMMAND`). `--installed` filters to installed entries; `--format menu` emits the same five-column TSV used by menus. | Does not contact Flathub or report update availability, user-scope installs, health, permissions, or desktop-entry presence. |
| `validate` | Validates local schema and catalog invariants. | Does not validate Flathub availability, downloads, installed exports, permissions, or launch success. |
| `install <selector>` | Resolves one catalog entry, prints a plan, ensures system Flathub, skips an already-installed ref, and installs system-wide. | One catalog entry only; no raw-ID bypass, size/permission preview, user scope, bulk category install, or transaction rollback. |
| `launch <selector>` | Requires a system installation and expected system desktop entry, then runs the catalog ID at system scope. | No file/argument forwarding, user-scope launch, desktop-entry repair, or automatic installation. |
| `remove <selector>` | Resolves one catalog entry, prints a system-scope removal plan, preserves app data, skips an already-absent ref, and uninstalls only that ID. | No purge, confirmation prompt, user scope, unused-runtime cleanup, bulk/category removal, or non-catalog ID. |
| `update [selector]` | Updates one installed selected entry, or all installed catalog entries in catalog order with one system operation; an empty set is a no-op. | Does not install missing apps, update user-scope or non-catalog Flatpaks, show remote changes, or replace the broader update workflow. |

## Existing Installer Integration

The installer consumes the catalog through the catalog library; it does not
parse JSON independently. Compatibility behavior is:

- `default`: the four entries whose `profile` is `default`;
- `optional`: the nine entries whose `profile` is `optional`, not default plus
  optional;
- `all`: all 13 entries in their single catalog order;
- `none`: no entries and no Flatpak activity.

`--skip-flatpak` also skips the Flatpak phase. The legacy text lists remain
test fixtures only. Exact fixture comparisons pin the pre-catalog IDs and the
default-then-optional ordering.

Installer and catalog CLI operations use system scope. Installation checks
each ref in order and skips installed refs, making reruns idempotent. Flathub is
ensured once before missing refs are installed. Invalid catalog data fails
synchronously before process-substitution or Flatpak behavior could hide the
validation failure.

# Architectural Decisions Log

## ADR: JSON Catalog Chosen

### Decision

Use a versioned JSON object with an ordered applications array.

### Reason

JSON is machine-readable with `jq`, represents typed booleans and structured
metadata directly, and can preserve installer order without introducing a new
runtime language or service.

### Consequences

`jq` is required. Schema changes require a versioned migration and validation
updates. Array order is part of compatibility behavior. JSON must never be
evaluated as shell.

## ADR: Catalog Is The Flatpak Source Of Truth

### Decision

Derive installer profiles and catalog CLI behavior from the catalog library.
Keep legacy text profiles only as temporary regression fixtures.

### Reason

Dual runtime sources would drift and make labels, IDs, and ordering ambiguous.

### Consequences

Every consumer uses the shared reader. Invalid catalog data blocks operations.
Removing the fixtures later requires an explicit migration decision and
replacement compatibility evidence.

## ADR: Preserve Profile Semantics During Catalog Migration

### Decision

Keep the exact 13 previous IDs, their order, and the established meanings of
default/optional/all/none.

### Reason

Phase 3a was an architectural migration, not a product-bundle change.

### Consequences

Catalog evolution must separate schema/mechanism changes from application-set
changes. Reordering or reclassifying applications is a visible product
decision and needs dedicated review and tests.

## ADR: Use System-Scoped Flatpaks

### Decision

Installer profiles and every catalog-managed state or lifecycle command—status,
install, launch, remove, and update—operate on the system Flatpak installation
and system Flathub remote.

### Reason

One consistent scope matches existing installer behavior, avoids split state
between installation paths, and lets an administrator-installed desktop expose
the same applications to the target user.

### Consequences

Commands use explicit `--system`; user-scope-only installs appear not installed
to the catalog. Adding user-scope support later is a migration/product decision,
not a flag to add opportunistically.

## ADR: Keep The CLI Thin

### Decision

Use `ahr-flatpak` for argument validation, presentation, and orchestration, with
catalog interpretation and Flatpak mechanics delegated to focused libraries.

### Reason

This follows AHR's script-first command namespace while keeping reusable policy
out of menus and avoiding a large application-management framework.

### Consequences

CLI output may evolve, but selection and runtime safety must stay centralized.
Menu integration should dispatch into this layer rather than duplicate it.

## ADR: Extract A Small Runtime Library

### Decision

Share concrete Flatpak primitives between installer and runtime CLI.

### Reason

The installer already had proven system-scope and idempotency behavior. Sharing
those mechanics prevents the CLI from creating a subtly different installation
path.

### Consequences

The library remains Flatpak-specific and small. Installer summaries and CLI
plans stay with their callers; catalog parsing stays in the catalog library.
Do not generalize it into an abstract multi-package backend without a real need.

## ADR: Offline Operations Do Not Depend On Remote Metadata

### Decision

List, search, info, and validate use only framework-owned catalog data. Status
uses only local system Flatpak information.

### Reason

Discovery of curated identities and local state should remain deterministic,
fast, and usable when the network or Flathub is unavailable.

### Consequences

The CLI cannot currently show live size, remote availability, permissions, or
update state. Adding those must preserve an offline path and define caching and
failure semantics.

## ADR: Keep Live Evidence Optional And Read-Only

### Decision

Pin deterministic identity and desktop-entry assumptions offline, and expose
current Flathub availability only through an opt-in, non-mutating live check.

### Reason

Catalog availability changes over time and cannot be proved by stubs, but
network access and a configured remote are unsuitable prerequisites for the
quality gate.

### Consequences

The offline validator uses the shared catalog library and may duplicate the
expected application set only as a test fixture. `--live-flathub` may read
remote state but must not bootstrap a remote or mutate applications. Live
results are dated evidence, not permanent catalog facts, and installed desktop
exports require a separate host check.

## ADR: Deliver The Catalog With Framework Transactions

### Decision

Place the catalog under the existing managed `default/` framework target and
validate it during staged framework validation.

### Reason

Catalog schema, libraries, and CLI must change coherently and must share the
existing backup, activation, recovery, and rollback guarantees.

### Consequences

No independent catalog updater is needed. A bad candidate catalog blocks a
framework update before backup. Installed-catalog hand edits are framework
drift and may be replaced.

## ADR: Preserve Application Data On Removal By Default

### Decision

The catalog removal path uninstalls only the explicitly resolved application
and preserves user documents and per-application data by default. Any future
removal surface must retain that contract.

### Reason

Package ownership does not imply ownership of user data. Silent deletion is
hard to recover and conflicts with AHR's conservative modification policy.

### Consequences

Catalog removal prints a visible plan, validates the selector before deriving
the app-data path, treats a missing installation idempotently, and uninstalls
only the system-scoped app without `--delete-data`. General purge remains
unresolved; the older OnlyOffice helper's explicit purge is a narrow precedent,
not an automatic catalog-wide policy.

## ADR: Keep Catalog Updates Separate From Broad Updates

### Decision

`ahr flatpak update [selector]` updates only installed system-scope catalog
entries. It does not delegate to `ahr update --flatpak`.

### Reason

The broad updater may combine package, AUR, unrestricted Flatpak, migration,
and hook work. A catalog command must have a bounded, predictable mutation set
derived from validated local catalog identities.

### Consequences

A selected app must already be installed. Selector-free update checks all
catalog entries locally, preserves catalog order, and makes one Flatpak update
call containing only installed catalog IDs. Non-catalog Flatpaks are untouched;
users must deliberately choose the broader update workflow to update them.

# Non-Negotiable Constraints

- Do not silently delete user documents, application data, profiles, themes,
  projects, shell history, or arbitrary configuration.
- Do not make an optional catalog application required for first login, core
  desktop recovery, doctor, migration, or framework update.
- Do not bypass framework staging, validation, backup, activation,
  transaction, recovery, or rollback when delivering framework-owned catalog
  data or scripts.
- Do not update the installed catalog through an independent mutable channel;
  it belongs to the transactional framework `default/` target.
- Do not parse catalog JSON separately in the installer, CLI, menus, or updater;
  use the catalog library.
- Do not duplicate Flatpak scope, remote-bootstrap, install, launch, remove, or
  update logic in menus. Menus are UI/dispatch boundaries.
- Do not implement catalog update by delegating to `ahr update --flatpak`; the
  catalog command must remain bounded to installed catalog identities.
- Do not pass an unresolved or unvalidated selector to Flatpak. Catalog-managed
  commands accept only entries resolved through the local validated catalog.
- Do not treat JSON, transaction state, manifests, desktop entries, or other
  data as executable shell input. No `eval` or sourcing of data records.
- Do not switch catalog-managed behavior between user and system scope
  implicitly. Current accepted scope is system.
- Do not use the legacy text profiles as a runtime fallback or a second source
  of truth.
- Do not turn the catalog-entry validator's pinned expected-entry set into a
  runtime source. It is evidence that the canonical catalog still matches the
  last accepted/live-checked application set.
- Do not change profile meaning, IDs, or ordering as a side effect of a schema
  or implementation refactor. Product-set changes require explicit review and
  regression updates plus refreshed live availability evidence.
- Do not use partial pacman refresh/install patterns that risk an Arch/Artix
  partial upgrade; preserve the full transaction policy.
- Do not introduce `systemctl` or systemd-only assumptions into supported
  Artix/OpenRC paths.
- Do not overwrite user-edited configuration without the existing ownership,
  confirmation, and backup rules. Prefer managed blocks or new files in
  migrations.
- Do not claim framework rollback reverses packages, Flatpaks, services, or
  arbitrary migration side effects.
- Do not add purge, recursive deletion, broad uninstall, or automatic backup
  cleanup without a separate safety design and exact ownership validation.
- Do not replace tested behavior without a compatibility migration and tests
  proving old installs can move forward.
- Do not make remote access a prerequisite for local catalog inspection or
  local status.
- Do not make the opt-in live Flathub validator mutate state, add a missing
  remote, or become required by the offline quality gate.
- Do not import a broad application list, create a generic package abstraction,
  or expand Phase 3 into web apps/gaming/services without architectural review.
- Do not advertise a roadmap slice as supported merely because candidate code
  exists. Require aligned contract, documentation, tests, and appropriate live
  validation.

# Current Known Risks

## Unresolved Decisions

- **Removal interaction details:** The accepted operation is catalog-only,
  system-scoped, data-preserving, planned, and idempotent. Category-driven
  single-app removal via menus is implemented; category/bulk removal, purge,
  unused-runtime cleanup, and integration with external management tools still
  need review.
- **Purge behavior:** OnlyOffice has an explicit narrow purge. Whether a
  catalog-wide purge should exist, and how paths and ownership would be proven,
  is unresolved. It must not be inferred from a Flatpak ID alone.
- **Update presentation:** Catalog update ownership is resolved: selected or
  installed catalog entries only, separate from `ahr update --flatpak`. Remote
  change previews, whether `ahr update-available` needs a catalog-specific view
  in addition to its existing global Flatpak count, and how the menu explains
  the distinction remain unresolved.
- **User versus system scope:** System scope is accepted today. Supporting
  user-scope installations would affect status, launch, desktop-entry lookup,
  installer compatibility, privilege expectations, and duplicate installs.
- **Trust labeling:** `support`, `proprietary`, and `unofficial` are stored, but
  their exact user-facing warnings, support promises, and combinations are not
  yet an enforced UX policy.
- **Metadata sources:** Live download size, permissions, verification status,
  and remote availability are absent. Source authority, freshness, caching,
  offline fallback, and failure behavior require a design before network
  metadata enters the core CLI.
- **Menu design:** Category-driven Install/Remove menus are implemented and
  wired into the quality gate. The legacy raw-ID path is retained as a clearly
  labeled advanced option. Bulk/category mutations, purge, and user-scope
  support remain unresolved.
- **Category model:** Schema-v1 has seven allowed categories, but ordering,
  display names, multi-category membership, category-level actions, and future
  evolution are not settled.
- **Display-name identity:** Slugs and Flatpak IDs are unique; names are not
  required to be unique. Exact name selection therefore has an intentional
  ambiguity failure that future catalog curation must respect.
- **Remote/application drift:** The dated 2026-09-05 live pass confirmed all 13
  IDs and installed desktop exports at that time, but offline validation cannot
  prove that a Flathub app still exists, its export remains unchanged, its
  permissions are acceptable, or its behavior still works on Artix/Hyprland.
  The live validator refreshes remote-ID availability only; installed exports
  and actual launch/portal behavior require separate checks.
- **Flatpak transaction limits:** A profile installs entries sequentially and
  stops on failure; it does not roll back applications installed earlier in the
  same run. Framework transactions do not cover application mutations.
- **Migration side effects and backup retention:** Marker state can be restored,
  but arbitrary external effects cannot. Framework backups have manual
  retention and no automatic cleanup policy.

# Future Phase Roadmap

Nothing in this section is implemented merely because it is listed.

## Ready To Implement

- Keep `docs/FLATSEAL_WAREHOUSE.md` synchronized when catalog scope, lifecycle,
  or external-tool boundaries change; its initial boundary documentation is
  complete.
- Refresh read-only Flathub-ID evidence when an entry changes and before a
  release claim that depends on current availability. Check installed desktop
  exports separately rather than attributing them to the live validator.
- Complete behavioral evidence for catalog entries where relevant: actual
  launch, clean missing-Flathub handling, and Artix/Hyprland portal behavior.
- Retire the legacy text-profile fixtures only after an explicit migration gate
  replaces their compatibility role; until then, keep the exact-equivalence
  test.

## Requires Design Decision

- General removal confirmation and purge policy, including app-data ownership
  and shared-runtime cleanup.
- Whether update availability needs a catalog-specific count in addition to
  the existing global Flatpak count, and menu presentation that clearly
  distinguishes bounded catalog update from the broad update orchestrator.
- Any user-scope Flatpak support or migration from the accepted system scope.
- User-facing meaning and visual treatment of support, proprietary, and
  unofficial labels.
- Source, caching, trust, and offline behavior for download size, permission
  guidance, and other remote metadata.
- Whether schema-v1 categories remain single-valued and how category order and
  naming are presented in menus.

## Avoid Until Later

- Schema expansion before a concrete accepted consumer requires it.
- Remote Flathub discovery as a dependency of local list/search/info/status.
- Broad or automatic purge, unused-runtime cleanup, full AHR uninstall, or
  destructive preinstall cleanup.
- Wholesale import of Omarchy or another project's application list.
- A generic package-manager abstraction spanning pacman, AUR, Flatpak, vendor
  installers, and web apps.
- A Chromium-centered web-app subsystem; current product direction treats
  those services as normal browser sites unless a trusted standalone Flatpak is
  deliberately curated.
- Automatic system/package rollback or mandatory Btrfs/Snapper integration
  before a filesystem-independent safety design exists.
- Broad gaming, AI, proprietary-service, or hardware-sensitive installers
  without per-source trust, package availability, removal, and live-validation
  work.

# How Future AI Assistants Should Reason About This Project

1. Start from the accepted architecture and phase boundary, then inspect the
   current repository conventions before proposing a rewrite. Candidate code
   is not automatically accepted product behavior.
2. Distinguish product decisions from implementation decisions. For example,
   system scope and data-preserving removal are product/safety decisions;
   whether a helper uses one Bash function or two is implementation detail.
3. Preserve the existing source-of-truth graph: catalog library interprets
   catalog data, runtime library performs Flatpak mechanics, CLI orchestrates,
   installer consumes profiles, menus dispatch, and framework updater delivers
   the whole set transactionally.
4. Prefer an incremental migration with pinned compatibility tests. Do not
   combine catalog schema change, bundle-content change, scope change, and menu
   redesign in one patch.
5. Identify ownership and irreversible effects before every mutation. State
   explicitly what is framework-owned, system-owned, app-owned, and user-owned;
   then define backup, retry, failure, and recovery behavior.
6. Treat offline behavior as a contract. If remote metadata is proposed,
   preserve useful local list/search/info/status behavior and define stale or
   unavailable states explicitly.
7. Challenge unnecessary complexity. AHR prefers small Bash libraries and
   explicit data over daemons, databases, plugin systems, or generic
   abstractions. Add a layer only when multiple real callers need the same
   policy.
8. Check compatibility on old installations, not only a clean checkout. Ask
   how the current installed updater receives new files, how migrations are
   ordered, which state survives rollback, and whether namespace links remain
   valid.
9. Use isolated stubs to prove command boundaries, but request live Artix and
   Hyprland evidence for claims involving repositories, desktop entries,
   portals, hardware, launch behavior, or current upstream metadata.
10. Keep terminology precise: installer phase 6 is where AUR/Flatpak install
    runs; product Phase 3 is the Flatpak catalog roadmap. Do not conflate them.
11. Before expanding scope, state which roadmap exit gate the change advances
    and which unresolved decisions it depends on. Do not smuggle broad package,
    web-app, or destructive cleanup work into catalog polish.

# Decision Template

Use this template for any architectural choice that changes product behavior,
ownership, safety, compatibility, or phase scope:

```text
Decision:
Context:
Options:
Chosen approach:
Reason:
Tradeoffs:
Migration impact:
Tests required:
```

# Final Review

- **Phase accuracy:** This document treats Phases 1, 2, 3a, 3b, 3c, 3d, and 3e as
  completed and includes the accepted catalog install, launch, removal, update,
  and category-driven menu contracts plus the accepted documentation,
  validation, drift, diagnostic-hardening, and menu-regression evidence. Those
  slices do not expand schema, scope, purge, remote metadata, or bulk lifecycle
  behavior. User scope and schema expansion remain explicitly unfinished.
- **Architecture rather than inventory:** It records responsibility boundaries,
  state ownership, source-of-truth relationships, compatibility promises,
  transaction/recovery guarantees, and decision rationale rather than
  describing every repository file.
- **Fact/decision/constraint separation:** Confirmed implementation appears in
  current architecture and phase history; durable choices appear in the ADR
  log; non-negotiable limits and unresolved risks have their own sections;
  future work is explicitly non-implemented.
- **Standalone usefulness:** Paths, scope, command semantics, installer and
  update flows, schema-v1 fields, known limitations, and reasoning guidance are
  included so another model can plan without repository access.
- **Evidence:** Phase 1 and Phase 2 have documented live Artix validation.
  Phase 3a–3d have passing isolated regression suites, framework-delivery
  coverage, and a pinned catalog-entry validation layer whose availability
  assumptions carry a dated read-only live pass (2026-09-05, 13/13 IDs on
  Flathub, 13/13 desktop entries separately confirmed in the installed system
  export directory). The live validator refreshes only the ID-availability
  portion; the complete Phase 3 product exit gate remains open.
