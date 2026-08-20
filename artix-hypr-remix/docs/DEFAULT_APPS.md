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

The isolated tests prove the setup/validation logic. A clean-Artix live session
must additionally prove real-file and removable-device behavior. Run as the
desktop user after a fresh install (or after re-running first-run):

1. **URL / directory / text / PDF / image / audio / video / archive** — for
   each sample, `xdg-open <file-or-url>` and confirm the correct app launches:
   - `xdg-open https://example.com` → browser
   - `xdg-open ~` → Nautilus
   - `xdg-open note.txt` → editor
   - `xdg-open doc.pdf` → Evince
   - `xdg-open pic.png` → imv
   - `xdg-open clip.mp3` → mpv
   - `xdg-open clip.mp4` → mpv
   - `xdg-open archive.zip` → File Roller
2. **Removable device** (Nautilus session, with a USB stick):
   - mount: device appears in Nautilus sidebar and mounts under `/run/media/$USER/...`
   - open: opens in Nautilus
   - browse: files are readable
   - unmount: safely unmounts from Nautilus
   - safe removal: device can be removed without data loss
3. **Capture action**: Color Picker → `hyprpicker` launches and copies a color.
4. **Setup action**: `ahr doctor` reports the default-app matrix as configured.
5. **Repeat after reboot** and **after a framework update**; the matrix must be
   unchanged and any valid user choice preserved.

Record the exact commands run and the observed application for each step as
evidence. Until this live session is executed, Phase 2 live validation remains
PENDING.
