# Artix-native Command Namespace

This document defines the desktop command namespace for artix-hypr-remix.

Goals:
- Keep commands native to Artix + OpenRC behavior.
- Avoid hard dependency on Omarchy internals.
- Preserve user muscle memory with a small, optional compatibility alias layer.

## Naming

Primary prefix:
- `ahr-` (Artix Hypr Remix)

Categories:
- `ahr-launch-*` for app launching helpers
- `ahr-system-*` for lock/reboot/session helpers
- `ahr-capture-*` for capture tooling

## V1 Commands

- `ahr` - top-level help and subcommand dispatcher
- `ahr-menu` - open the application launcher
- `ahr-launch-terminal` - open preferred terminal
- `ahr-launch-browser` - open default browser/homepage
- `ahr-launch-files` - open file manager in a target path
- `ahr-launch-audio` - open audio control UI (or terminal fallback)
- `ahr-launch-wifi` - open Wi-Fi/network UI (or terminal fallback)
- `ahr-system-lock` - lock current session
- `ahr-system-reboot` - reboot safely via available init interface
- `ahr-capture-screenshot` - area screenshot with Wayland tools

## Compatibility Aliases (Optional)

When namespace installation runs, selected Omarchy-style aliases are created in
`~/.local/bin` as symlinks to native commands:

- `omarchy-menu` -> `ahr-menu`
- `omarchy-launch-terminal` -> `ahr-launch-terminal`
- `omarchy-launch-browser` -> `ahr-launch-browser`
- `omarchy-launch-nautilus` -> `ahr-launch-files`
- `omarchy-launch-audio` -> `ahr-launch-audio`
- `omarchy-launch-wifi` -> `ahr-launch-wifi`
- `omarchy-system-lock` -> `ahr-system-lock`
- `omarchy-system-reboot` -> `ahr-system-reboot`
- `omarchy-capture-screenshot` -> `ahr-capture-screenshot`

The alias set is intentionally small. The canonical interface remains `ahr-*`.

## Installation

Installer phase 7 runs:

- `~/.config/artix-hypr-remix/bin/namespace-install.sh --quiet`

This script links commands into `~/.local/bin` and installs alias symlinks.

Manual run:

    ~/.config/artix-hypr-remix/bin/namespace-install.sh
