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
- `ahr-theme-*` for theme management and compatibility with Omarchy theme assets

## V1 Commands

- `ahr` - top-level help and subcommand dispatcher
- `ahr-menu` - open the application launcher
- `ahr-launch-terminal` - open preferred terminal
- `ahr-launch-browser` - open default browser/homepage
- `ahr-launch-files` - open file manager in a target path
- `ahr-launch-audio` - open audio control UI (or terminal fallback)
- `ahr-launch-wifi` - open Wi-Fi/network UI (or terminal fallback)
- `ahr-default-browser` - inspect or set the user's default browser (xdg)
- `ahr-default-terminal` - inspect or set the user's preferred terminal (xdg-terminals.list)
- `ahr-update` - run package updates, migrations, and post-update hooks
- `ahr-update-available` - report package and migration work remaining
- `ahr-migrate` - run framework migrations directly (`--status`, `--dry-run`, `--retry-skipped`)
- `ahr-theme` - top-level theme management dispatcher (`list`, `current`, `set`, `refresh`, `bg-next`, `bg-set`)
- `ahr-theme-list` - list discovered themes from Artix and Omarchy theme directories
- `ahr-theme-current` - show current theme
- `ahr-theme-set` - apply a theme atomically with template rendering
- `ahr-theme-refresh` - reapply current theme without changing selection
- `ahr-theme-bg-next` - cycle to next background for current theme
- `ahr-theme-bg-set` - set a specific background image
- `ahr-theme-set-templates` - render templates into a target theme directory
- `ahr-theme-colors-from-alacritty` - generate `colors.toml` from `alacritty.toml`
- `ahr-system-lock` - lock current session
- `ahr-system-reboot` - reboot safely via available init interface
- `ahr-capture-screenshot` - area screenshot with Wayland tools

## Compatibility Aliases (Optional)

When namespace installation runs, selected Omarchy-style aliases are created in
`~/.local/bin` as symlinks to native commands:

- `omarchy-menu` -> `ahr-menu`
- `omarchy-theme` -> `ahr-theme`
- `omarchy-theme-list` -> `ahr-theme-list`
- `omarchy-theme-current` -> `ahr-theme-current`
- `omarchy-theme-set` -> `ahr-theme-set`
- `omarchy-theme-refresh` -> `ahr-theme-refresh`
- `omarchy-theme-bg-next` -> `ahr-theme-bg-next`
- `omarchy-theme-bg-set` -> `ahr-theme-bg-set`
- `omarchy-theme-set-templates` -> `ahr-theme-set-templates`
- `omarchy-theme-colors-from-alacritty` -> `ahr-theme-colors-from-alacritty`
- `omarchy-launch-terminal` -> `ahr-launch-terminal`
- `omarchy-launch-browser` -> `ahr-launch-browser`
- `omarchy-launch-nautilus` -> `ahr-launch-files`
- `omarchy-launch-audio` -> `ahr-launch-audio`
- `omarchy-launch-wifi` -> `ahr-launch-wifi`
- `omarchy-default-browser` -> `ahr-default-browser`
- `omarchy-default-terminal` -> `ahr-default-terminal`
- `omarchy-update` -> `ahr-update`
- `omarchy-update-available` -> `ahr-update-available`
- `omarchy-migrate` -> `ahr-migrate`
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
