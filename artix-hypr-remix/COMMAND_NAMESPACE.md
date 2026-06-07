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
- `ahr-menu` - open feature-sliced command menu (`learn`, `trigger`, `style`, `setup`, `install`, `remove`, `update`, `system`) with app-launcher entry
- `ahr-menu-keybindings` - show Hyprland keybinding help from the active config
- `ahr-launch-apps` - open the application launcher using core fallback order
- `ahr-launch-terminal` - open preferred terminal
- `ahr-launch-browser` - open default browser/homepage
- `ahr-launch-files` - open file manager in a target path
- `ahr-launch-audio` - open audio control UI (or terminal fallback)
- `ahr-launch-bluetooth` - open Bluetooth control UI/TUI
- `ahr-launch-wifi` - open Wi-Fi/network UI (or terminal fallback)
- `ahr-default-browser` - inspect or set the user's default browser (xdg)
- `ahr-default-terminal` - inspect or set the user's preferred terminal (xdg-terminals.list)
- `ahr-update` - run package updates, migrations, and post-update hooks
- `ahr-update-available` - report package and migration work remaining
- `ahr-repair` - inspect common framework drift and apply safe repairs with `--apply`
- `ahr-status` - print install state, log paths, and framework summary
- `ahr-doctor` - run installed-framework health checks (required commands, desktop runtime, OpenRC services, capture tools, menu backend, MIME defaults, theme state, framework deployment)
- `ahr-list-backups` - list config backups created by installer phase 4
- `ahr-voxtype-model` - open voxtype model setup workflow
- `ahr-voxtype-config` - open voxtype configuration file
- `ahr-toggle-idle` - toggle `hypridle` daemon state for lock/suspend behavior
- `ahr-toggle-notification-silencing` - toggle do-not-disturb mode for `mako`
- `ahr-toggle-waybar` - show or hide Waybar
- `ahr-notification-dismiss` - dismiss the active Mako notification or a notification matching a summary
- `ahr-restart-mako` - restart Mako notification daemon
- `ahr-restart-waybar` - restart Waybar
- `ahr-restart-walker` - restart Walker launcher service
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
- `ahr-capture-screenrecording` - start or stop screen recording
- `ahr-capture-screenshot` - area, fullscreen, or window screenshot with Wayland tools (`--area`/`--fullscreen`/`--window`, `--open`)
- `ahr-capture-picker` - interactive picker for screenshot mode (bound to Print by default)
- `ahr-edit-config` - open a config file in user's preferred editor
- `ahr-system-suspend` - suspend to RAM
- `ahr-system-hibernate` - hibernate to disk

## Compatibility Aliases (Optional)

When namespace installation runs, selected Omarchy-style aliases are created in
`~/.local/bin` as symlinks to native commands:

- `omarchy-menu` -> `ahr-menu`
- `omarchy` -> `ahr`
- `omarchy-menu-keybindings` -> `ahr-menu-keybindings`
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
- `omarchy-launch-walker` -> `ahr-launch-apps`
- `omarchy-launch-browser` -> `ahr-launch-browser`
- `omarchy-launch-nautilus` -> `ahr-launch-files`
- `omarchy-launch-audio` -> `ahr-launch-audio`
- `omarchy-launch-bluetooth` -> `ahr-launch-bluetooth`
- `omarchy-launch-wifi` -> `ahr-launch-wifi`
- `omarchy-default-browser` -> `ahr-default-browser`
- `omarchy-default-terminal` -> `ahr-default-terminal`
- `omarchy-update` -> `ahr-update`
- `omarchy-update-available` -> `ahr-update-available`
- `omarchy-repair` -> `ahr-repair`
- `omarchy-status` -> `ahr-status`
- `omarchy-list-backups` -> `ahr-list-backups`
- `omarchy-voxtype-model` -> `ahr-voxtype-model`
- `omarchy-voxtype-config` -> `ahr-voxtype-config`
- `omarchy-toggle-idle` -> `ahr-toggle-idle`
- `omarchy-toggle-notification-silencing` -> `ahr-toggle-notification-silencing`
- `omarchy-toggle-waybar` -> `ahr-toggle-waybar`
- `omarchy-notification-dismiss` -> `ahr-notification-dismiss`
- `omarchy-restart-mako` -> `ahr-restart-mako`
- `omarchy-restart-waybar` -> `ahr-restart-waybar`
- `omarchy-restart-walker` -> `ahr-restart-walker`
- `omarchy-migrate` -> `ahr-migrate`
- `omarchy-system-lock` -> `ahr-system-lock`
- `omarchy-system-reboot` -> `ahr-system-reboot`
- `omarchy-capture-screenrecording` -> `ahr-capture-screenrecording`
- `omarchy-capture-screenshot` -> `ahr-capture-screenshot`
- `omarchy-edit-config` -> `ahr-edit-config`
- `omarchy-system-suspend` -> `ahr-system-suspend`
- `omarchy-system-hibernate` -> `ahr-system-hibernate`

The alias set is intentionally small. The canonical interface remains `ahr-*`.
Omarchy commands without safe Artix/OpenRC equivalents are intentionally omitted
until their behavior is implemented natively.

## Installation

Installer phase 7 runs:

- `~/.config/artix-hypr-remix/bin/namespace-install.sh --quiet`

This script links commands into `~/.local/bin` and installs alias symlinks.

Manual run:

    ~/.config/artix-hypr-remix/bin/namespace-install.sh
