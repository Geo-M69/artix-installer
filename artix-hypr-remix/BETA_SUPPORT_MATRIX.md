# Beta Support Matrix

This document freezes the supported hardware, startup modes, optional profiles, and shell combinations for the Artix Hypr Remix beta release.

## Base System Requirements

| Requirement | Value |
|-------------|-------|
| Distribution | Artix Linux |
| Init / service manager | OpenRC |
| Starting point | Working Artix base install with `pacman`, networking, and a non-root desktop user |
| Privilege model | `sudo` for phases 1–8; desktop user for phases 4–8 |
| Architecture | `x86_64` |

## Startup Modes

| Mode | Default | Status | Notes |
|------|---------|--------|-------|
| `tty` | ✅ Default | 🟢 Validated | Launches Hyprland via managed block in `~/.profile` on VT 1 |
| `greetd` | ❌ Optional | 🟢 Validated | Present and validated (greeter mode) |
| `greetd` + autologin | — | 🟢 Validated | Present and validated through daily use on VM and host; fresh-install validation bundle still needed for release artifacts |

## GPU / Hardware Profiles

| Profile | Status | Validated hosts | Notes |
|---------|--------|-----------------|-------|
| `amd` | 🟢 Validated | 1 (VM, virtualized GPU) | Package detection and OpenRC module present |
| `intel` | 🟡 Limited | 0 | Package detection stub and OpenRC module present; no real-host logs yet |
| `nvidia` | 🟢 Validated | 1 (NVIDIA laptop, TTY + greetd) | Real-host Artix OpenRC validation passed; nvidia/nvidia-utils/nvidia-settings installed; `nvidia_drm.modeset=Y` confirmed |
| `laptop` | 🟢 Validated | 1 (NVIDIA laptop, TTY + greetd) | Battery/power packages tracked, real-host validation passed on NVIDIA laptop |

### Validation notes

- **AMD** — one virtualized VM host validated (quality gate, smoke framework, milestone2-validate all pass). Tested with `tty`, `greetd` greeter, and `greetd` autologin startup modes.
- **Intel** — package stubs and OpenRC module actions exist in `config/hardware/intel/`, but **no real Artix host logs have been submitted yet**. Expected to work but not yet marked as validated.
- **NVIDIA + Laptop** — validated together on a real NVIDIA laptop host (both TTY and greetd startup modes). See validation bundle.

## Optional Profiles

| Profile | Flag | Status | Notes |
|---------|------|--------|-------|
| Docker | `--docker-profile on` | 🟢 Validated | Package set, service enable/start, and check script exist |
| Printing | `--printing-profile on` | 🟢 Validated | Package set, service enable/start, and validation script exist; uses `cups-openrc` / `avahi-openrc` |
| AUR packages | Phase 6 (default: on) | 🟢 Validated | `packages/90-aur.txt` — fail-fast on install failure |
| Flatpak (default) | `--flatpak-profile default` | 🟢 Validated | Installs `flatpaks/default.txt` |
| Flatpak (optional) | `--flatpak-profile optional` | 🟢 Validated | Installs `flatpaks/optional.txt` |
| Flatpak (all) | `--flatpak-profile all` | 🟢 Validated | Installs both default and optional |
| Dev baseline | `--dev-baseline on` (Phase 8) | 🟢 Validated | Git/GPG/SSH baseline, disabled by default |

## Shell Support

| Shell | Status | Notes |
|-------|--------|-------|
| `bash` | 🟢 Supported | Default on most Artix installs; `config/bash/.bashrc` deployed |
| `zsh` | 🟢 Supported | `config/zsh/.zshrc` deployed with `ZDOTDIR` support |

## Host Policies

| Policy | Flag / Env | Use case |
|--------|------------|----------|
| `artix` | `AHR_HOST_POLICY=artix` (default) | Production — requires Artix host |
| `vm` | `AHR_HOST_POLICY=vm` | Validation — requires Artix + virtualization |
| `any` | `AHR_HOST_POLICY=any` | Maintenance — bypasses host checks |

## Hardware Mode Options

| Mode | Flag | Behavior |
|------|------|----------|
| `recommend` | `--hardware-mode recommend` (default) | Prints detected profile packages and asks before installing |
| `auto` | `--hardware-mode auto` | Installs detected profile packages without prompt |
| `off` | `--hardware-mode off` | Disables hardware profile package handling and OpenRC module actions |

## Core Desktop — Expected To Work

Stack validated through the quality gate, smoke framework, and milestone-2 validation:

- Hyprland (TTY launch via managed `~/.profile` block)
- Waybar (status bar, toggle, restart)
- Mako (notifications, silencing, restart)
- PipeWire / WirePlumber (audio)
- `grim` (screenshots)
- `hyprlock` / `hypridle` (lock and idle)
- `wl-clipboard` (clipboard)
- `xdg-desktop-portal-hyprland` (portals)
- Theme engine (`ahr-theme-*` commands, nord default)
- Command namespace (`ahr`, `ahr-menu`, `ahr-repair`, `ahr-migrate`, `ahr-update`, etc.)
- First-run framework (idempotent, session-aware)
- Migration framework (stateful, retry-skipped)
- Repair framework (`ahr repair --namespace`, `--theme`, `--config`, `--docs`, `--migrations`, `--update-state`)

## Intentionally Unsupported For Beta

See also `BETA_READINESS.md`.

- systemd, UWSM, SDDM, Plymouth, Limine
- Non-OpenRC init systems
- Display managers other than `greetd`
- Full uninstall / reset command
- ISO / distribution profile work
- Web app installer
- Rich theme gallery, previews, theme install/update/remove
- Broad install/remove menus for gaming, Windows, AI, dev stacks, security tools
- Hardware-specific toggles not validated on real Artix hardware

## Validation Logs Required For Full Beta Confidence

| Profile | Real host needed | Logs captured |
|---------|-----------------|---------------|
| AMD (desktop or VM) | ❌ VM sufficient | ✅ 1 VM log |
| Intel (desktop) | ✅ Yes | ❌ |
| NVIDIA (desktop) | ✅ Yes | ❌ |
| Laptop (any GPU) | ✅ Yes | ❌ |

---

*Last updated: 2026-06-05*
