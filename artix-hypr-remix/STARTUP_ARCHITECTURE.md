# Startup Architecture Lock-in

This document defines the long-term startup model for artix-hypr-remix.

## Goals

- Keep an OpenRC-native default that is easy to recover from.
- Provide an optional polished display-manager path.
- Ensure both modes launch Hyprland through a single shared session launcher.
- Keep migration safety and mode switching deterministic.

## Supported Modes

- `tty` (default): managed shell-profile block starts Hyprland from tty1.
- `greetd` (optional): greetd manages login/session startup.

Both modes launch:

- `~/.config/artix-hypr-remix/bin/start-hyprland-session.sh`

This avoids drift between startup paths.

## Installer Contract

Phase 5 is startup configuration.

- `./install.sh --startup-mode tty`
- `./install.sh --startup-mode greetd`
- `./install.sh --startup-mode greetd --greetd-mode autologin`
- `./install.sh --startup-mode greetd --greetd-mode greeter`

Behavior:

- `tty` mode:
  - Ensures managed startup block is present in `~/.bash_profile` and `~/.zprofile`.
  - Removes greetd from OpenRC runlevel (best effort).
- `greetd` mode:
  - Removes managed tty startup block from `~/.bash_profile` and `~/.zprofile`.
  - Writes `/etc/greetd/config.toml` using the selected greetd policy:
    - `autologin`: boot directly into Hyprland and keep tuigreet as fallback.
    - `greeter` (default): show tuigreet login prompt on boot.
  - Enables greetd in OpenRC default runlevel.

Mode state is written to:

- `~/.local/state/artix-hypr-remix/startup.mode`

## Requirements for Greetd Mode

- OpenRC service `/etc/init.d/greetd` must exist.
- `tuigreet` must be installed.

If either dependency is missing, the installer stops with a clear error.

## Why Not Exactly Omarchy

Omarchy currently centers around systemd, UWSM, and SDDM. This project is Artix + OpenRC first.

We mirror the user experience goal (a polished DM path) but keep OpenRC-native internals.

## Validation Matrix

Minimum checks before release:

1. Fresh install with `--startup-mode tty`.
2. Fresh install with `--startup-mode greetd --greetd-mode autologin`.
3. Fresh install with `--startup-mode greetd --greetd-mode greeter`.
4. Run phase 5 to switch from `tty` to `greetd`.
5. Run phase 5 to switch from `greetd` to `tty`.
6. Verify first-run and post-boot hooks still execute.
