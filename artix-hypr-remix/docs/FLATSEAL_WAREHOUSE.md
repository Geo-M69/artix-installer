# Flatseal And Warehouse

Flatseal and Warehouse ship in the AHR Flatpak catalog's `default` profile.
This document explains what each tool is for, how it complements the
catalog-managed workflow, and the boundaries that keep the catalog the source
of truth. It is documentation only: it describes no new commands, schema,
menus, or behavior beyond the accepted Phase 3d contract recorded in
`docs/ARCHITECTURE_CONTEXT.md` and `docs/FLATPAK_PROFILES.md`.

## Roles at a glance

| Concern | Owner in AHR |
|---|---|
| Catalog identity, schema, and validation | Catalog library; `ahr flatpak validate` |
| Catalog discovery and lifecycle | `ahr flatpak list`, `search`, `info`, `status`, `install`, `launch`, `remove`, `update` |
| Per-application permission inspection and changes | Flatseal (user-owned, outside the catalog contract) |
| User-scope applications, user data, remotes | Warehouse or raw `flatpak` commands (advanced path, outside the catalog contract) |
| Broad updates including non-catalog Flatpaks | `ahr update --flatpak` |
| Delivery of the catalog itself | Transactional framework `default/` target |

Flatseal and Warehouse complement the catalog; they do not replace its
validation, selector resolution, or system-scope lifecycle policy.

## What the catalog layer guarantees

The catalog is the framework-owned source of truth for supported Flatpak
identities. Recap of the guarantees that external tools do not provide:

- **Validation before mutation.** Schema-v1 shape, required fields, enums, and
  unique slugs/IDs are validated by the catalog library. Invalid catalog data
  fails before any Flatpak operation.
- **Selector resolution.** Catalog commands accept only selectors that resolve
  exactly (case-insensitive) to a catalog slug, display name, or Flatpak ID.
  Ambiguous names are rejected; raw application IDs never bypass the catalog.
- **System scope.** Catalog-managed install, launch, remove, and update are
  always `--system`. A user-scope-only install reads as `not-installed` to the
  catalog.
- **Bounded updates.** `ahr flatpak update` mutates only installed catalog
  entries, in catalog order. It never touches non-catalog Flatpaks; the
  broader `ahr update --flatpak` workflow remains the unrestricted path.
- **Data preservation.** `ahr flatpak remove` never passes Flatpak's
  data-deletion option and never deletes `~/.var/app/<flatpak-id>`. There is
  no catalog purge option.
- **Catalog ownership.** The catalog lives in the transactional `default/`
  framework target. Edits to the installed copy are framework drift and may be
  replaced by an update.

## Flatseal: permissions

Flatseal (`com.github.tchx84.Flatseal`, category `system-utilities`, support
`default`) is a graphical tool for reviewing and changing the permissions of
installed Flatpak applications.

**How it complements the catalog.** The catalog CLI deliberately does not
display, validate, or manage permissions; live permission metadata is an
unresolved design decision, not an oversight. Flatseal fills exactly that
inspection and adjustment gap at the Flatpak layer.

**Boundaries.** Flatseal knows nothing about the catalog. It works on
installed application IDs and has no concept of slugs, installer profiles,
support labels, or selector resolution. Permission changes made in Flatseal
are user-owned choices recorded as Flatpak overrides: AHR does not validate,
record, or revert them, and catalog validation and lifecycle behavior are
unaffected by them.

## Warehouse: installation-level management

Warehouse (`io.github.flattool.Warehouse`, category `system-utilities`,
support `default`) is a general Flatpak management tool for installed
applications, their user data, and configured remotes.

**How it complements the catalog.** The catalog CLI is intentionally bounded:
`status` reports system-scope state only, and the offline commands do not show
installation-level detail such as user-scope state, remotes, or data
footprint. Warehouse covers those installation-level chores with a GUI.

**Boundaries.** Warehouse does not read or validate the catalog, resolve
selectors, or know profiles and support labels. Anything it changes is a
Flatpak-level change, and only catalog-resolved, system-scope entries
participate in `ahr flatpak` lifecycle commands. Remote management and user
data handling in Warehouse are outside the catalog contract, which bootstraps
only the system `flathub` remote when needed and never deletes application
data itself.

## Out-of-band changes and their catalog-visible results

| Action taken outside the catalog | Catalog-visible result |
|---|---|
| Install a catalog application at user scope with another tool | `ahr flatpak status` reports it `not-installed`; catalog install offers a system-scope copy; catalog update ignores it. |
| Install an application ID that is not in the catalog | It is a non-catalog Flatpak: no selector resolves to it, catalog commands reject it, and `ahr update --flatpak` remains the way to update it. |
| Out-of-band system install whose exports lack the catalog-declared desktop entry | `ahr flatpak status` still reports `installed`; `ahr flatpak launch` refuses with the expected desktop-entry path; `ahr flatpak install` reports already installed and does not repair exports. |
| Change an application's permissions in Flatseal | Stored as Flatpak overrides outside the catalog; catalog validation and lifecycle are unaffected. |
| Delete application data with Warehouse | A user-owned out-of-band deletion. Catalog `remove` itself preserves `~/.var/app/<flatpak-id>` and has no purge option. |
| Hand-edit the installed `catalog.json` | Framework drift; the transactional `default/` target may replace it on the next framework update. |

These are descriptions of current accepted behavior, not new policy. The
user-scope non-authoritative results and the desktop-entry mismatch states are
pinned offline by `scripts/test-flatpak-drift.sh` in the quality gate, which
also pins the shared system-scope state wording used by the catalog commands.
General purge and user-scope support remain unresolved product decisions.

## Not required for core AHR operation

Flatseal and Warehouse are `default`-profile catalog entries, but like every
catalog application they are optional in the architectural sense:

- First login, `ahr doctor`, `ahr repair`, framework update, rollback,
  recovery, and `ahr update` all work when they are absent — including after
  `--flatpak-profile none` or `--skip-flatpak`.
- They are not part of the update machinery. `ahr flatpak update` invokes only
  `flatpak update --system`; no AHR path launches a Flatpak GUI.
- The catalog CLI works without them. Read-only commands are local and
  offline; `status` reports `unavailable` only when the `flatpak` executable
  itself is missing.

Their presence in the default profile preserves the pre-Phase-3a default
application set; it is not a dependency statement.

## Developer notes

- No code integration exists at the Phase 3d boundary: no script, hook,
  menu entry, doctor check, or migration invokes, parses, or depends on
  Flatseal or Warehouse; the only repository references are their catalog
  rows, the legacy text fixtures that pin them, and the tests that assert
  catalog equivalence.
- Future menu work must dispatch through the catalog CLI or shared libraries.
  Flatseal and Warehouse must not become a substitute for catalog validation,
  selector resolution, or lifecycle policy, and menus must not grow a second
  catalog parser or Flatpak policy implementation.
- Adding live permissions, size, or verification metadata to the catalog CLI
  is an open design decision. Installing these GUI tools does not resolve it
  and does not change the offline CLI contract.

## Explicit non-goals of this document

- No claim that Flatseal or Warehouse is required for any AHR workflow.
- No new AHR commands, flags, schema fields, or menu behavior.
- No purge or user-scope design; current accepted limitations stand.
- No integration contract with either tool beyond what is written here.
