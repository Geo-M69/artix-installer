# AHR Flatpak Profiles

AHR uses Flatpak for optional graphical applications. The canonical profile
data is the schema-v1 catalog at
`config/artix-hypr-remix/default/flatpak/catalog.json`. Its array order is the
installation order. `profile` membership drives the existing installer modes:

- `default` installs catalog entries whose `profile` is `default`.
- `optional` installs catalog entries whose `profile` is `optional`.
- `all` installs every catalog entry in catalog order.
- `none` installs no Flatpaks.

`flatpaks/default.txt` and `flatpaks/optional.txt` remain temporary Phase 3a
migration fixtures. Runtime profile resolution does not read them. The focused
catalog test requires the catalog-derived lists to match them byte-for-byte
after comment/whitespace parsing, preserving the pre-Phase-3a IDs and order.

Schema parsing and validation are owned by
`config/artix-hypr-remix/bin/ahr-flatpak-catalog-lib.sh`. Installation and
idempotency remain in `lib/flatpak.sh` (`install_flatpak_profile`,
`flatpak_collect_profile_refs`). The catalog is nested under the existing
transactional `default/` framework-update target, so it is staged, backed up,
activated, recovered, and rolled back with the framework.

## Catalog CLI

Phase 3b exposes the local catalog without changing installation behavior:

```text
ahr flatpak list
ahr flatpak search <query>
ahr flatpak info <slug|name|flatpak-id>
ahr flatpak status [selector]
ahr flatpak validate
```

`list`, `search`, `info`, and `validate` use only the local catalog. `status`
inspects only local system-installation state — composed through the shared
Flatpak runtime library, which honors `AHR_FLATPAK_COMMAND` and reports
`installed`, `not-installed`, or `unavailable` when the Flatpak command is
absent; it does not contact Flathub. Search is a
case-insensitive substring match over slug, name, Flatpak ID, and category.
`info` and the optional `status` selector are exact, case-insensitive matches
on slug, name, or Flatpak ID.

Phase 3c adds catalog-managed installation and launch:

```text
ahr flatpak install <slug|name|flatpak-id>
ahr flatpak launch <slug|name|flatpak-id>
```

Installation prints its system-scope Flathub plan before mutation, is
idempotent, and accepts only entries that resolve through the catalog. Launch
requires a system-installed application and its catalog-declared desktop entry
under `/var/lib/flatpak/exports/share/applications` before invoking
`flatpak run --system`.

Phase 3d adds catalog-managed removal and updates:

```text
ahr flatpak remove <slug|name|flatpak-id>
ahr flatpak update [slug|name|flatpak-id]
```

Removal prints its plan, uninstalls only the validated system application, and
does not pass Flatpak's data-deletion option or delete anything under
`~/.var/app`. Application data is therefore preserved. Purge is intentionally
not available from the catalog command.

With a selector, `ahr flatpak update` updates that application only when it is
installed for system scope. Without a selector, it locally checks every
catalog entry, preserves catalog order, and passes only the installed catalog
IDs to one system-scoped `flatpak update` operation. By contrast,
`ahr update --flatpak` remains the broader global update workflow: it can run
system, AUR, migration, and unrestricted Flatpak update steps. The catalog
command does not delegate to it because doing so would update non-catalog
Flatpaks and unrelated subsystems.

Phase 3e adds category-driven Install and Remove menus and the read-only CLI
flags that support them:

```text
ahr flatpak list [--category CAT] [--format menu]
ahr flatpak status [--category CAT] [--installed] [--format menu]
```

`--format menu` emits a headerless TSV row (`slug<TAB>name<TAB>support<TAB>
proprietary<TAB>unofficial`) that the menu consumes without parsing JSON.
`--installed` filters `status` to system-installed catalog entries. Exact
category filtering lives in the catalog library; the menu only handles
presentation and dispatch. Install and Remove menus now default to catalog
discovery (`Install > Flatpak Apps (Catalog)` and `Remove > Flatpak Apps
(Catalog)`), showing only non-empty categories and system-installed catalog
entries respectively, with clear Proprietary/Unofficial labels. Clearly labeled
`Advanced: Install/Remove by Flatpak ID…` entries remain at the bottom of each
menu and continue to invoke interactive raw `flatpak install --system flathub
<id>` / `flatpak uninstall --system <id>` paths that bypass AHR catalog
validation; they never pass `--delete-data`. If a catalog CLI query fails
(invalid or missing catalog), the menus show an actionable diagnostic pointing
at `ahr flatpak validate`, present no catalog choices, and return to the parent
menu; they never fall back automatically to the advanced raw-ID path.

Purge, remote metadata, and schema expansion remain later Phase 3 work.

## Flatseal and Warehouse

Flatseal and Warehouse ship in the default profile as complementary Flatpak
management tools (permissions and installation-level management,
respectively). They do not replace catalog validation, selector resolution, or
the system-scope lifecycle contract. See `docs/FLATSEAL_WAREHOUSE.md` for the
boundary details.

## Catalog schema v1

The top-level object contains `schema_version: 1` and an ordered
`applications` array. Every application requires:

- `slug`: stable lowercase kebab-case catalog identity.
- `name`: display name.
- `flatpak_id`: safe reverse-DNS Flatpak application ID.
- `category`: `communication`, `office-writing`, `media`, `creative`,
  `development`, `gaming`, or `system-utilities`.
- `profile`: `default` or `optional`.
- `support`: `default`, `recommended`, `optional`, or `experimental`.
- `proprietary` and `unofficial`: independent boolean classifications.
- `desktop_entry`: expected plain `.desktop` filename.

Duplicate slugs and Flatpak IDs are invalid. Invalid catalog data stops phase 6
before the installer invokes Flatpak.

Entries also follow a documented convention: `desktop_entry` is the Flatpak ID
with `.desktop` appended. `scripts/validate-flatpak-catalog-entries.sh` pins
the current application set (identity, Flatpak ID, and order) against the
live-validated availability assumptions and enforces this convention. Its
default mode is offline and part of the quality gate; `--live-flathub` adds a
read-only live re-check of every catalog ID against the configured Flathub
remote and never bootstraps, installs, or mutates anything. Live availability
results are recorded in `docs/ARCHITECTURE_CONTEXT.md` and are separate from
synthetic regression evidence.

## OnlyOffice (opt-in office profile)

OnlyOffice is **not** part of the default install and is **not** used by
first-login, recovery, or framework-update paths. Users opt in explicitly with
the `ahr-onlyoffice` command.

### Application ID

`org.onlyoffice.desktopeditors` (Flathub, system scope).

### Installation

```
ahr onlyoffice install
```

This ensures the Flathub remote exists and installs
`org.onlyoffice.desktopeditors`. It can also be installed through
`ahr flatpak install onlyoffice` or through the optional installer profile:
`./install.sh --flatpak-profile optional`.

### Launch validation

```
ahr onlyoffice launch            # validates desktop entry, launches app
ahr onlyoffice launch doc.docx   # opens a specific document
ahr onlyoffice status            # shows install state + handled MIME types
ahr onlyoffice mimes             # prints the document MIME types handled
```

`launch` verifies the desktop entry exists under the Flatpak exports
(`~/.local/share/flatpak/exports/share/applications` or
`/var/lib/flatpak/exports/share/applications`) before launching, so a missing
entry is reported instead of failing silently.

### Document MIME behavior

After installation, OnlyOffice registers for office document types, including:

- `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
- `application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- `application/vnd.ms-powerpoint`, `application/vnd.openxmlformats-officedocument.presentationml.presentation`
- `application/vnd.oasis.opendocument.text/.spreadsheet/.presentation`
- `application/pdf`

AHR's default-app matrix deliberately does **not** manage office document MIME
types, so installing or removing OnlyOffice never disturbs the core
AHR-managed defaults (PDF stays on Evince, etc.).

### Removal

```
ahr onlyoffice remove            # removes the app; preserves user data
ahr onlyoffice remove --purge    # also deletes app data at ~/.var/app/<id>
```

**Safety guarantees:**

- **User documents are never deleted.** `~/Documents` (and any other user
  files) are untouched.
- **Application data is not silently deleted.** By default, `remove` keeps
  `~/.var/app/org.onlyoffice.desktopeditors`. Passing `--purge` deletes that
  app-data directory explicitly, with a clear on-screen description of what is
  and is not removed.
- `remove` prints a removal plan before acting so the operator knows exactly
  what will be removed.

## Other optional applications

The remaining optional Flatpak entries (`com.obsproject.Studio`, Discord,
Vesktop, Obsidian, Spotify, Signal, EasyEffects, Mission Center) follow the
same profile conventions but are not given dedicated management commands in
Phase 2; they are installed via the optional/all profile and removed with
`flatpak uninstall`.
