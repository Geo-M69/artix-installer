# Artix Package Substitutions

This document tracks known package name differences between Artix Linux
(OpenRC) and Arch Linux / Omarchy. These substitutions are already reflected
in the installer package manifests but are collected here for reference.

## OpenRC Service Wrappers

Artix ships `-openrc` packages that provide OpenRC init scripts for services
that ship systemd units on Arch. The installer always pairs these with their
base package.

| Base package | Artix OpenRC package | Purpose |
|-------------|---------------------|---------|
| `dbus` | `dbus-openrc` | D-Bus message bus |
| `elogind` | `elogind-openrc` | Seat/session management |
| `networkmanager` | `networkmanager-openrc` | Network management |
| `bluez` | `bluez-openrc` | Bluetooth stack |
| `cups` | `cups-openrc` | Printing (optional profile) |
| `avahi` | `avahi-openrc` | mDNS/DNS-SD (optional profile) |
| `docker` | `docker-openrc` | Container runtime (optional profile) |
| `nvidia-utils` | `nvidia-utils-openrc` | NVIDIA GPU utils (hardware profile) |

## NVIDIA Driver Variants

| Package | Context | Notes |
|---------|---------|-------|
| `nvidia-open` | AHR hardware profile | Open kernel module for Turing (20xx) GPUs and newer |
| `nvidia` | Arch/Omarchy default | Proprietary module; supports pre-Turing GPUs |
| `nvidia-open-dkms` | Arch/Omarchy alternative | DKMS variant of open module |
| `nvidia-dkms` | Arch/Omarchy alternative | DKMS variant of proprietary module |

AHR explicitly uses `nvidia-open` because it targets modern GPUs. The
`config/hardware/nvidia/packages.txt` header warns that `--hardware-mode auto`
may install the wrong driver on pre-Turing systems.

## AUR / Community Repo Packages

These packages exist in Arch's community/extra repos or AUR but may need
different package names or sources on Artix:

| Package | Repo | Notes |
|---------|------|-------|
| `gum` | AUR (`charmbracelet/gum`) | Not in official Artix repos `[a]` |
| `ghostty` | Arch extra / AUR | Available in Arch extra since late 2025; may need AUR on Artix |
| `gpu-screen-recorder` | AUR | Screen recording utility |
| `satty` | AUR | Screenshot annotation tool |
| `wofi` | Arch community | Launcher menu; verify availability on Artix |
| `walker-bin` | AUR | Application launcher (optional; in 91-aur-optional.txt) |
| `elephant*` (4 variants) | AUR | File search tools (optional; in 91-aur-optional.txt) |
| `python-pynvim` | Arch extra | May be named differently or need pip install on Artix |
| `luarocks` | Arch community | Lua package manager; verify availability on Artix |

`[a]`: `gum` is in `00-core.txt` and marked as required. If `gum` is
unavailable on Artix repos, the installer's preflight check for required
commands may still pass if `gum` is not a hard runtime dependency — but the
menu system depends on it. Consider moving `gum` to an AUR manifest or
documenting it as a required AUR bootstrap step.

## Hardware Profiles

These packages are the same name on Arch and Artix:

| Profile | Packages | Verified |
|---------|----------|----------|
| AMD | `vulkan-radeon` | VM (2026-06-05) |
| Intel | `vulkan-intel`, `intel-media-driver` | Not yet validated on real hardware |
| Laptop | `acpi`, `acpid`, `pm-utils` | NVIDIA laptop (2026-06-06) — battery, lid close, suspend validated |
| NVIDIA | `nvidia-open`, `nvidia-utils`, `nvidia-settings`, `nvidia-utils-openrc` | Laptop (2026-06-05) |

## Profile Validation Status

### Printing profile ✅ (dry-run validated 2026-06-06)

Packages: `cups`, `avahi`, `cups-openrc`, `avahi-openrc`
Services: `cupsd`, `avahi-daemon`

The installer correctly injects 4 printing packages and 2 OpenRC services
when `--printing-profile on` is set. A real-host live install is still needed
to verify cupsd/avahi-daemon actually start and function.

### Docker profile ✅ (dry-run validated via check-docker-profile.sh)

Packages: `docker`, `docker-openrc`
Services: `docker`

The `scripts/check-docker-profile.sh` script validates:
- `--help` mentions `--docker-profile`
- Phase 3 dry-run with `--docker-profile on` lists `docker` service
- Phase 3 dry-run with `--docker-profile off` omits `docker` service
- Phase 2 dry-run with `--docker-profile on` injects docker packages

This check passes in the quality gate. A real-host live install is still
needed to verify `docker` OpenRC service actually starts and functions.

### Optional AUR packages (91-aur-optional.txt)

```text
walker-bin
elephant
elephant-clipboard
elephant-desktopapplications
elephant-files
elephant-websearch
```

These are all AUR packages. The installer warns and continues on failure.
Validation requires a host with AUR access (`paru` installed).
