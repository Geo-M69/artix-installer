# Artix Hypr Remix — Beta Release Notes

**Target version:** `v0.1.0-beta1`  
**Release date:** TBD  
**Base system:** Artix Linux with OpenRC

---

## Tested base system

The following base system was used for the current validation run:

| Detail | Value |
|--------|-------|
| Distribution | Artix Linux (OpenRC) |
| Image | `artix-base-openrc-20250501-x86_64.iso` |
| Validation date | 2026-06-05 |
| Validation host | `geoartix` (VM, QEMU/KVM, Virtio GPU) |
| Image source | [artixlinux.org/download](https://artixlinux.org/download) |
| Package state | Fresh `pacman -Syu` prior to install; live Artix repos as of 2026-06-05 |

> **Note:** Package availability depends on live Artix repository state at install time.
> The beta release will pin the exact ISO filename and a recommended minimum `pacman -Syu` date.
> Additional validation bundles (Intel, NVIDIA, laptop) are needed before broader support claims.

---

## What's included

This beta release provides an opinionated, phase-based installer that configures a complete Hyprland desktop on Artix Linux (OpenRC). The installer is idempotent and safe to re-run.

### Core desktop stack

- Hyprland (TTY launch by default, optional `greetd`)
- Waybar (status bar with toggle/restart support)
- Mako (notification daemon with silencing and restart)
- PipeWire / WirePlumber (audio)
- `grim` / `hyprlock` / `hypridle` (screenshots, lock, idle)
- `wl-clipboard` (clipboard)
- `xdg-desktop-portal-hyprland` (portals)
- Theme engine with `artix-dark` default
- Command namespace (`ahr`, `ahr-menu`, `ahr-repair`, `ahr-migrate`, `ahr-update`, etc.)

### Optional profiles

| Profile | Enabling flag |
|---------|---------------|
| Docker | `--docker-profile on` |
| Printing | `--printing-profile on` |
| AUR packages | Phase 6 (default: on) |
| Flatpak (default/optional/all) | `--flatpak-profile` |
| Dev baseline (Git/GPG/SSH) | `--dev-baseline on` (Phase 8) |

### Startup modes

- `tty` — default, launches Hyprland via managed block in `~/.profile`
- `greetd` — optional display-manager flow (greeter or autologin)

---

## Supported hardware

See [BETA_SUPPORT_MATRIX.md](BETA_SUPPORT_MATRIX.md) for the full frozen matrix.

| Profile | Status | Hosts validated |
|---------|--------|-----------------|
| AMD (desktop/VM) | 🟢 Validated | 1 (virtualized) |
| Intel | 🟡 Limited | 0 — stub and OpenRC module present, no real host yet |
| NVIDIA | 🟡 Limited | 0 — stub and OpenRC module present, no real host yet |
| Laptop | 🟡 Limited | 0 — detection flag present, no real host yet |

### Validation hosts

| Host | GPU | Startup | Date | Logs |
|------|-----|---------|------|------|
| `geoartix` (VM) | AMD (Virtio) | tty | 2026-06-05 | Quality gate ✅, smoke ✅, milestone2 ✅ |
| `geoartix` (VM) | AMD (Virtio) | greetd (greeter) | 2026-06-05 | Doctor ✅, post-install smoke ✅, milestone2 ✅ |
| `geoartix` (host) | AMD (Virtio) | greetd (autologin) | 2026-06-05 | Daily-use validation ✅ |

---

## Key known issues

See [MILESTONE6_KNOWN_ISSUES.md](MILESTONE6_KNOWN_ISSUES.md) for the full list.

- Real-host validation is still limited — Intel, NVIDIA, and laptop profiles need logs before strong support claims.
- `greetd` mode is present and validated for both greeter and autologin variants. Fresh-install log bundles still needed for release artifacts.
- `ahr repair --config` is detect-only and does not rewrite user-edited config automatically.
- Theme background fallback: `artix-dark` has no bundled background image; falls back to solid color.
- Package availability depends on live Artix repos and selected package profiles.
- Screenshots / visual gallery are deferred to future work.

---

## Fast start

```bash
git clone https://github.com/<you>/artix-installer.git
cd artix-installer/artix-hypr-remix
sudo ./install.sh
```

See `README.md` for phase options, flags, and validation commands.

---

## Rollback and recovery

See [RECOVERY_AND_RESET.md](RECOVERY_AND_RESET.md) for repair boundaries.

- Config backups are created at `~/.config/<name>.bak.<timestamp>` during Phase 4.
- Safe repair commands: `ahr repair --namespace --apply`, `ahr repair --theme --apply`.
- Installer phase 4 can re-deploy managed config: `sudo ./install.sh --phase 4 --user <username> -y`.
- No full uninstall/reset command exists yet.

---

## Intentionally unsupported (beta)

- systemd, UWSM, SDDM, Plymouth, Limine, and other systemd-specific Omarchy maintenance paths
- Non-OpenRC init systems
- Display managers other than `greetd`
- Full uninstall/reset command
- ISO / distribution profile work
- Web app installer
- Rich theme gallery, previews, and theme install/update/remove
- Broad install/remove menus for gaming, Windows, AI, dev stacks, security tools
- Hardware-specific toggles not validated on real Artix hardware

---

## How to contribute validation logs

See [MILESTONE6_BETA_CHECKLIST.md](MILESTONE6_BETA_CHECKLIST.md) for the exact commands to run.

To submit a validation bundle:
1. Run the minimum validation commands on your Artix host.
2. Gather logs from `/var/log/artix-hypr-remix-install.log` and `/var/lib/artix-hypr-remix/hardware-profile.json`.
3. Package into `validation-<host>-<gpu>-<date>.tar.gz`.
4. Attach to the beta release or open an issue.

Profiles most needed: **Intel desktop**, **NVIDIA desktop**, **laptop (any GPU)**.
