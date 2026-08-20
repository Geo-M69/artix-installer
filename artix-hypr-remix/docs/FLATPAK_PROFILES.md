# AHR Flatpak Profiles

AHR uses Flatpak for optional graphical applications. Profiles are newline-
separated lists of Flatpak application IDs (refs) under `flatpaks/`:

- `flatpaks/default.txt` — installed by the default profile
  (`install.sh --flatpak-profile default`, the default).
- `flatpaks/optional.txt` — opt-in; installed only with
  `--flatpak-profile optional` or `all`.

Profile installation and idempotency are handled by `lib/flatpak.sh`
(`install_flatpak_profile`, `flatpak_collect_profile_refs`). This document
focuses on the Phase 2 OnlyOffice profile; the broader Phase 3 catalog is a
separate track and is intentionally **not** implemented here.

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
`org.onlyoffice.desktopeditors`. (Equivalently, it is reachable via the
optional profile: `./install.sh --flatpak-profile optional`.)

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
