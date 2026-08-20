# AHR Default Applications and MIME Matrix

This document is the canonical reference for AHR's default-application and
MIME-handler behavior (Phase 2). The single source of truth is
`config/artix-hypr-remix/bin/ahr-default-apps-matrix.sh`, which is consumed by:

- `config/artix-hypr-remix/first-run.d/56-default-apps.sh` (setup, runs once per
  first login and is safe to re-run)
- `config/artix-hypr-remix/bin/ahr-doctor` (installed-framework health check)
- `scripts/doctor.sh` (full repo doctor)
- `scripts/post-install-smoke.sh` (post-install smoke)

Because setup and validation read the same matrix, they cannot silently drift.

## Design rules

- **Idempotent.** A configured handler is never overwritten.
- **User choice preserved.** Any valid handler — native or Flatpak — is kept.
  AHR assigns its default only when no valid handler exists for a MIME.
- **Stale handlers detected.** If a configured handler points at a desktop
  entry that no longer exists, validation reports it (and first-run repair
  re-assigns the AHR default).
- **Discovery is multi-root.** Desktop entries are resolved from system
  application directories, the user application directory, and Flatpak
  application directories. No single location is trusted.
- **Safe.** Desktop-entry data and manifests are treated as untrusted: only
  plain `*.desktop` filenames under known prefixes are accepted (no `eval`, no
  path traversal). All logic is POSIX-ish bash compatible with the supported
  environment.

## Default MIME matrix

| Category      | AHR default (candidate desktop entries)        | MIME types covered |
|---------------|------------------------------------------------|--------------------|
| HTTP/HTTPS    | browser (firefox, zen, chromium, …)            | `x-scheme-handler/http`, `x-scheme-handler/https`, `text/html` |
| Directories   | Nautilus (`org.gnome.Nautilus.desktop`)        | `inode/directory`, `x-directory/normal` |
| Plain text    | editor (helix, nvim, vim)                      | `text/plain`, `text/markdown`, `text/x-markdown` |
| PDF           | Evince (`org.gnome.Evince.desktop`)            | `application/pdf` |
| Images        | imv (`imv.desktop`)                            | `image/png`, `image/jpeg`, `image/gif`, `image/webp`, `image/bmp`, `image/tiff` |
| Video         | mpv (`mpv.desktop`)                            | `video/mp4`, `video/x-matroska`, `video/webm`, `video/x-msvideo`, `video/ogg`, `video/quicktime` |
| Audio         | mpv (`mpv.desktop`)                            | `audio/mpeg`, `audio/flac`, `audio/x-flac`, `audio/x-wav`, `audio/ogg`, `audio/x-vorbis` |
| Archives      | File Roller (`org.gnome.FileRoller.desktop`)   | `application/zip`, `application/x-tar`, `application/x-bzip`, `application/x-bzip2`, `application/gzip`, `application/x-7z-compressed`, `application/x-rar-compressed` |
| Calculator    | GNOME Calculator (`org.gnome.Calculator.desktop`) | (launched app; recorded in `env` as `CALCULATOR`) |

Audio is an explicit mpv mapping: common audio MIME types resolve to
`mpv.desktop`, not to a control-panel entry.

## Package → desktop-entry mapping (verified against Artix manifests)

| Package            | Manifest file         | Desktop entry(s) |
|--------------------|-----------------------|------------------|
| `firefox`          | `packages/30-files.txt` | `firefox.desktop` |
| `nautilus`         | `packages/30-files.txt` | `org.gnome.Nautilus.desktop`, `nautilus.desktop` |
| `file-roller`      | `packages/30-files.txt` | `org.gnome.FileRoller.desktop`, `file-roller.desktop` |
| `evince`           | `packages/30-files.txt` | `org.gnome.Evince.desktop`, `evince.desktop` |
| `imv`              | `packages/30-files.txt` | `imv.desktop` |
| `mpv`              | `packages/30-files.txt` | `mpv.desktop` |
| `gnome-calculator` | `packages/30-files.txt` | `org.gnome.Calculator.desktop`, `gnome-calculator.desktop` |
| `gvfs`, `gvfs-mtp`, `udisks2`, `gnome-disk-utility` | `packages/30-files.txt` | removable-device chain (Nautilus workflow) |
| `hyprpicker`       | `packages/10-hyprland.txt` | `hyprpicker` (Color Picker Capture action) |
| `swayosd`          | `packages/91-aur-optional.txt` | optional OSD (not required) |

`imv`, `mpv`, `evince`, `gnome-calculator`, and `hyprpicker` were added in
Phase 2; previously `imv`/`mpv` were referenced by setup but absent from the
manifests.

## Helper commands

- `ahr-default-browser <firefox|zen|chromium|chrome|brave|edge>` — get/set the
  web browser (also sets `x-scheme-handler/http`, `https`, `text/html`).
- `ahr-default-terminal <ghostty|foot|kitty|alacritty>` — get/set the terminal.
- `ahr-default-editor <helix|neovim|vim|code>` — get/set the editor (records
  `EDITOR` and sets text/Markdown MIME defaults).
- `ahr-default-calculator <gnome-calculator>` — get/set the calculator
  (records `CALCULATOR`).

All four preserve an existing choice: `set` refuses to overwrite a valid
user-selected handler and backs up `env` before editing it.

## Doctor validation

`ahr-doctor` and `scripts/doctor.sh` validate the same matrix:

- Every matrix MIME is queried with `xdg-mime query default`.
- If a handler is configured and its desktop entry exists on disk, the check
  passes.
- If a handler is configured but its desktop entry is missing, the check
  reports a stale handler (hard fail in `scripts/doctor.sh`; warn-with-detail
  in the lightweight `ahr-doctor` for the installed framework).
- If no handler is configured for an AHR-managed category, the check reports a
  missing default.
- `ahr-doctor` additionally verifies the default calculator is available and
  that advertised Capture actions are present: `hyprpicker` (Color Picker) and
  SwayOSD (optional; absence is acceptable). Validation never calls
  `xdg-mime default` — it is read-only.

## Live validation

The isolated tests prove setup and validation logic. They are not a substitute
for the following clean-Artix desktop evidence. An existing developer desktop,
container, upgrade-in-place system, or session with pre-existing defaults is
**not** admissible Phase 2 completion evidence.

### Clean-host requirements

Perform this procedure as the non-root desktop user on a fresh Artix OpenRC
installation of the Phase 2 candidate (`7bacf80` or its exact release
artifact). Before recording any result, capture the output of:

```bash
pacman -Q nautilus gvfs gvfs-mtp udisks2 file-roller evince imv mpv \
  gnome-calculator hyprpicker
command -v hyprctl hyprpicker nautilus udisksctl wl-paste
printf 'session=%s desktop=%s wayland=%s\n' \
  "$XDG_SESSION_TYPE" "$XDG_CURRENT_DESKTOP" "$WAYLAND_DISPLAY"
```

The host is eligible only when all of the following are true:

- The Phase 2 native package set is installed, including Nautilus/GVfs/UDisks,
  File Roller, Evince, imv, mpv, and `hyprpicker`.
- `hyprpicker` is executable in the live Hyprland session.
- A **physical, non-system removable device** is available. Identify it with
  `lsblk -o NAME,TYPE,TRAN,RM,SIZE,MOUNTPOINTS`; never use the system disk.
- If `scripts/quality-gate.sh --no-aur` is part of the host gate, Docker and
  non-interactive sudo work: `sudo -n true` and `docker info` both succeed.
- OnlyOffice and SwayOSD are not prerequisites. Their absence is an expected
  supported case; do not install either merely to make this validation pass.

If a requirement is missing, record it as a blocker and stop. Do not use a
partial run to mark Phase 2 complete.

### Evidence record setup

Prepare one directory of harmless, valid representative fixtures owned by the
test user. Its pathname is recorded below as `$FIXTURES`; it must contain
`note.txt`, `note.md`, `document.pdf`, `image.png`, `audio.mp3`, `video.mp4`,
and `archive.zip`. The archive must contain at least one readable file.

```bash
export FIXTURES="$HOME/ahr-phase2-fixtures"
test -d "$FIXTURES"
```

Before each launch, record the MIME default shown by the query in the table's
**desktop entry ID** column. Launch the item visibly, identify the application
window, and enter the actual result; a successful shell exit alone is not
enough. A valid user-selected handler is correct and must be preserved. Where
the clean test user has no handler, the expected AHR candidate is shown below.

### Default-application evidence

| Item | MIME query / command or action | Expected application on an unconfigured clean user | Expected desktop entry ID | Observed application and desktop entry ID | Observed result |
|---|---|---|---|---|---|
| HTTP URL | `xdg-mime query default x-scheme-handler/http`; `xdg-open http://example.com` | Browser (Firefox when installed) | `firefox.desktop` | ☐ | ☐ Browser opens the URL |
| HTTPS URL | `xdg-mime query default x-scheme-handler/https`; `xdg-open https://example.com` | Browser (Firefox when installed) | `firefox.desktop` | ☐ | ☐ Browser opens the URL |
| Directory | `xdg-mime query default inode/directory`; `xdg-open "$FIXTURES"` | Nautilus | `org.gnome.Nautilus.desktop` (or `nautilus.desktop` alias) | ☐ | ☐ Nautilus opens and lists the fixture directory |
| Plain text | `xdg-mime query default text/plain`; `xdg-open "$FIXTURES/note.txt"` | Helix editor | `helix.desktop` | ☐ | ☐ Editor opens the text file |
| Markdown | `xdg-mime query default text/markdown`; `xdg-open "$FIXTURES/note.md"` | Helix editor | `helix.desktop` | ☐ | ☐ Editor opens the Markdown file |
| PDF | `xdg-mime query default application/pdf`; `xdg-open "$FIXTURES/document.pdf"` | Evince | `org.gnome.Evince.desktop` (or `evince.desktop` alias) | ☐ | ☐ Evince renders the PDF |
| Image | `xdg-mime query default image/png`; `xdg-open "$FIXTURES/image.png"` | imv | `imv.desktop` | ☐ | ☐ imv renders the image |
| Audio | `xdg-mime query default audio/mpeg`; `xdg-open "$FIXTURES/audio.mp3"` | mpv | `mpv.desktop` | ☐ | ☐ mpv starts audio playback |
| Video | `xdg-mime query default video/mp4`; `xdg-open "$FIXTURES/video.mp4"` | mpv | `mpv.desktop` | ☐ | ☐ mpv renders and plays video |
| Archive | `xdg-mime query default application/zip`; `xdg-open "$FIXTURES/archive.zip"` | File Roller | `org.gnome.FileRoller.desktop` (or `file-roller.desktop` alias) | ☐ | ☐ File Roller lists the archive contents |

For every row, record the literal command/action run, the queried desktop entry
ID, and the visible outcome in the validation log. If an existing valid choice
differs from the candidate in this table, record that choice and mark it as
**preserved**, not failed.

### Removable-device evidence

Use a disposable USB device with no required data. Substitute the recorded
partition and disk values below; `<partition>` is, for example, `/dev/sdb1`,
and `<disk>` is its parent, for example `/dev/sdb`.

| Step | Command/action | Expected result | Observed result |
|---|---|---|---|
| Detection | Insert the USB device; run `lsblk -o NAME,TYPE,TRAN,RM,SIZE,MOUNTPOINTS` | A physical removable USB disk and partition are identifiable; neither is a system disk. | ☐ |
| Mount | In Nautilus, select the device in the sidebar, or run `udisksctl mount -b <partition>` | Mount succeeds and the mounted path is reported/visible. | ☐ |
| Open | Select the mounted device in Nautilus, or run `nautilus <mount-path>` | Nautilus opens the device. | ☐ |
| Browse | Open a known file and navigate one directory level in Nautilus. | Contents are readable and navigation works. | ☐ |
| Unmount | Eject/unmount from Nautilus, or run `udisksctl unmount -b <partition>` | The mount disappears and no busy-device error remains. | ☐ |
| Safe removal | Run `udisksctl power-off -b <disk>` when supported, then physically remove it. | Power-off/safe-removal succeeds; no data-loss or filesystem error is reported on reinsertion. | ☐ |

Record the `lsblk` identification, mounted path, exact Nautilus action, and all
`udisksctl` output. Never run `power-off` against an unresolved or non-removable
disk.

### Capture and optional-component evidence

1. Run the visible Color Picker action (`ahr-capture-picker`, or Capture →
   Color Picker). `hyprpicker` must open.
2. Select a known on-screen color, then run `wl-paste`. Record both the command
   output and the copied color value.
3. With SwayOSD absent, run `ahr doctor` and the relevant post-install smoke
   command. Record the optional-warning text and confirm no result is made
   unsuccessful because SwayOSD is absent.
4. With OnlyOffice absent, verify the default-app launches above still work and
   record `flatpak info org.onlyoffice.desktopeditors` as not installed. Its
   absence must not block the core workflow.

### Reboot and framework-update repeat evidence

Before reboot and before the framework update, save an association snapshot.
The same command must be run after each event and compared byte-for-byte:

```bash
for mime in x-scheme-handler/http x-scheme-handler/https inode/directory \
  text/plain text/markdown application/pdf image/png audio/mpeg video/mp4 \
  application/zip; do
  printf '%s=%s\n' "$mime" "$(xdg-mime query default "$mime")"
done | tee "$HOME/ahr-phase2-mime-before.txt"
```

1. Reboot, log into the same test user, rerun the snapshot command to
   `ahr-phase2-mime-after-reboot.txt`, and run `diff -u` against the baseline.
   Re-run every default-application launch row above.
2. Make one valid, intentional test-user MIME selection using an installed
   alternate desktop entry; record both the MIME and entry ID. Do not use a
   nonexistent entry. This is the preservation control.
3. Run the approved framework-update procedure for the candidate, then rerun
   the snapshot to `ahr-phase2-mime-after-framework-update.txt` and compare it
   with the pre-update snapshot. Confirm the intentional valid selection is
   unchanged, then repeat the affected visible launch.
4. Record the framework version before and after (`ahr-update-framework
   --status`) and retain the update log. Any changed default, missing desktop
   entry, or failed launch is a Phase 2 failure until explained and fixed.

### Exit condition

Attach the completed tables, command output, screenshots where useful, and
reboot/update comparison files to the validation report. Until all required
live rows pass on an eligible clean host, **Phase 2 status is PENDING**. Do not
change the roadmap status to complete or create a completion commit from this
procedure alone.
