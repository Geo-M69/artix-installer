# Phase 6: Action Mapping — Omarchy Menu to AHR Command Reference

## 1. Supported Items: Omarchy Label → AHR Command

### Top-Level Menu

| Omarchy Label | AHR Handler | Dispatch Slice | Command/Implementation |
|---|---|---|---|
| Apps | `open_application_launcher()` | `apps` | `ahr-launch-apps` (walker/wofi/rofi) |
| Learn | `show_learn_menu()` | `learn` | Interactive submenu |
| Trigger | `show_trigger_menu()` | `trigger` | Interactive submenu |
| Style | `show_style_menu()` | `style` | Interactive submenu |
| Setup | `show_setup_menu()` | `setup` | Interactive submenu |
| Install | `show_install_menu()` | `install` | Interactive submenu |
| Remove | `show_remove_menu()` | `remove` | Interactive submenu |
| Update | `show_update_menu()` | `update` | Interactive submenu |
| About | `show_about_menu()` | `about` | Terminal about display |
| System | `show_system_menu()` | `system` | Interactive submenu |

### Learn Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Keybindings | ✅ Direct | `ahr-menu-keybindings` | Requires `walker` for graphical mode |
| Getting Started | AHR extra | `show_getting_started` (inline guide) | None (terminal) |
| Quick Reference | AHR extra | `open_markdown_doc quick-reference.md` | `less` or terminal fallback |
| AHR Command Help | AHR extra | `ahr help` | Requires `ahr` |
| Theme Help | AHR extra | `ahr-theme help` | Requires `ahr-theme` |
| Update Help | AHR extra | `ahr-update --help` | Requires `ahr-update` |
| Theme Asset Guide | AHR extra | `open_markdown_doc theme-assets.md` | File exists check |
| Open README | AHR extra | `xdg-open` GitHub URL | `xdg-open` or terminal fallback |
| Hyprland Reference | ✅ Added | `xdg-open https://wiki.hypr.land/` | `xdg-open` or terminal fallback |
| Artix Reference | ✅ Added | `xdg-open https://wiki.artixlinux.org/` | `xdg-open` or terminal fallback |

### Trigger Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Capture | ✅ Direct | `show_capture_menu()` | Interactive submenu |
| Toggle | ✅ Direct | `show_toggle_menu()` | Interactive submenu |
| Reminder | 🚫 Coming soon | `ahr_notify "not yet implemented"` | No command exists |
| Transcode | 🚫 Coming soon | `ahr_notify "not yet implemented"` | No command exists |
| Share | 🚫 Coming soon | `ahr_notify "not yet implemented"` | No command exists |
| Hardware | 🚫 Coming soon | `ahr_notify "not yet implemented"` | No command exists |

### Capture Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Screenshot | ✅ Direct | `ahr-capture-screenshot` (default) | `grim` |
| Area Screenshot | ✅ Direct | `ahr-capture-screenshot --area` | `grim`, `slurp` |
| Fullscreen Screenshot | ✅ Direct | `ahr-capture-screenshot --fullscreen` | `grim` |
| Window Screenshot | ✅ Direct | `ahr-capture-screenshot --window` | `grim`, `jq`, `hyprctl` |
| Screenrecord | ✅ Direct | `ahr-capture-screenrecording` | `gpu-screen-recorder` |
| Clipboard History | ✅ Direct | `ahr-clipboard-picker` | `cliphist` |
| Color Picker | ✅ Direct | `hyprpicker -az` | `hyprpicker`, `wl-copy` |

### Toggle Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Nightlight | ✅ Direct | `ahr-toggle-nightlight` | `hyprsunset` or toggle state |
| Idle Lock | ✅ Direct | `ahr-toggle-idle` | `hypridle` |
| Notifications | ✅ Direct | `ahr-toggle-notification-silencing` | `makoctl` or toggle state |
| Top Bar (Waybar) | ✅ Direct | `ahr-toggle-waybar` | `waybar` |
| Waybar Position | ✅ Direct | `ahr-toggle-waybar-position` | Waybar config |

### Style Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Theme | ✅ Direct | `ahr-theme set` / `ahr-theme list` / `show_theme_set_menu()` | `ahr-theme` |
| Font Set | ✅ Direct | `ahr-font set --family` / `ahr-font set --size`, `show_font_set_menu()` | `ahr-font` |
| Font Status | ✅ Direct | `ahr-font status` | `ahr-font` |
| Background Picker | ✅ Direct | `ahr-theme-bg-switcher` | `ahr-theme` |
| Background Next | ✅ Direct | `ahr-theme bg-next` | `ahr-theme` |
| Background Gallery | ✅ Direct | `ahr-theme-bg-gallery --backend fzf` | `ahr-theme` |
| Install Background | ✅ Direct | Custom script in terminal | `ahr-theme-bg-install` |
| Theme Status | ✅ Direct | `ahr-theme status` | `ahr-theme` |
| Download Omarchy Theme | ✅ Direct | `ahr-theme-install-omarchy --set` | `ahr-theme-install-omarchy` |
| Theme Refresh | ✅ Direct | `ahr-theme refresh` | `ahr-theme` |
| Waybar state | ✅ Direct | `ahr-toggle-waybar` | `waybar` |
| Restart Waybar | ✅ Direct | `ahr-restart-waybar` | `waybar` |
| Restart Mako | ✅ Direct | `ahr-restart-mako` | `mako` |

### Setup Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Audio Control | ✅ Direct | `ahr-launch-audio` | `pavucontrol` or `pwvucontrol` or `alsamixer` |
| Network Control | ✅ Direct | `ahr-launch-wifi` | `nm-connection-editor` or `nmtui` or `nmcli` |
| Bluetooth Control | ✅ Direct | `ahr-launch-bluetooth` | `blueman-manager` or `bluetui` or `bluetoothctl` |
| Default Browser | ✅ Direct | `ahr-default-browser <name>` | `ahr-default-browser` |
| Default Terminal | ✅ Direct | `ahr-default-terminal <name>` | `ahr-default-terminal` |
| Default Editor | ✅ Direct | `ahr-default-editor <name>` | `ahr-default-editor` |
| Edit Hyprland Config | ✅ Direct | `ahr-edit-config hyprland.conf` | Helix or terminal editor |
| Edit Hypridle Config | ✅ Direct | `ahr-edit-config hypridle.conf` | Helix or terminal editor |
| Edit Hyprlock Config | ✅ Direct | `ahr-edit-config hyprlock.conf` | Helix or terminal editor |
| Edit Waybar Config | ✅ Direct | `ahr-edit-config waybar/config.jsonc` | Helix or terminal editor |
| Edit Mako Config | ✅ Direct | `ahr-edit-config mako/config` | Helix or terminal editor |
| Edit Walker Config | ✅ Direct | `ahr-edit-config walker/config.toml` | Helix or terminal editor |
| Edit AHR Config | ✅ Direct | `ahr-edit-config artix-hypr-remix/config` | Helix or terminal editor |
| Restart Walker | ✅ Direct | `ahr-restart-walker` | `walker` |

### Install Menu

| Omarchy Label | AHR Equivalent | Command | Guard | Safety |
|---|---|---|---|---|
| Pacman Package(s) | ✅ Direct (simpler) | `sudo pacman -S --needed $packages` | `sudo`, `pacman` | User provides package names |
| AUR Package(s) | ✅ Direct (simpler) | `paru -S --needed $packages` or `yay -S --needed` | AUR helper | User provides package names |
| Flatpak App | ✅ Direct (simpler) | `flatpak install flathub $app_id` | `flatpak` | User provides app ID |
| Docker Stack (OpenRC) | ⚠️ OpenRC adaptation | `sudo pacman -S docker docker-openrc && sudo rc-update add docker default && sudo rc-service docker start` | `sudo`, `pacman` | Requires `confirm_yes` |
| Printing Stack (OpenRC) | ⚠️ OpenRC adaptation | `sudo pacman -S cups avahi cups-openrc avahi-openrc && sudo rc-update add cupsd default && sudo rc-update add avahi-daemon default` | `sudo`, `pacman` | Requires `confirm_yes` |

### Remove Menu

| Omarchy Label | AHR Equivalent | Command | Guard | Safety |
|---|---|---|---|---|
| Pacman Package(s) | ✅ Direct (simpler) | `sudo pacman -Rns $packages` | `sudo`, `pacman` | User provides package names |
| Flatpak App | ✅ Direct (simpler) | `flatpak uninstall $app_id` | `flatpak` | User provides app ID |
| Docker Stack (OpenRC) | ⚠️ OpenRC adaptation | `sudo rc-service docker stop && sudo rc-update del docker default && sudo pacman -Rns docker docker-openrc` | `sudo` | Requires `confirm_yes` |
| Printing Stack (OpenRC) | ⚠️ OpenRC adaptation | `sudo rc-service cupsd stop && sudo rc-service avahi-daemon stop && sudo rc-update del cupsd default && sudo rc-update del avahi-daemon default && sudo pacman -Rns cups avahi cups-openrc avahi-openrc` | `sudo` | Requires `confirm_yes` |

### Update Menu

| Omarchy Label | AHR Equivalent | Command | Guard |
|---|---|---|---|
| Run Full Update | ⚠️ AHR migration semantics | `ahr-update` | `ahr-update` |
| Run Update + Flatpak | ⚠️ AHR migration semantics | `ahr-update --flatpak` | `ahr-update` |
| Run Migrations Only | ⚠️ AHR migration semantics | `ahr-update --migrations-only` | `ahr-update` |
| Check Update Availability | ⚠️ AHR migration semantics | `ahr-update-available` | `ahr-update-available` |
| Migration Status | ⚠️ AHR migration semantics | `ahr-migrate --status` (wraps `migrate.sh`) | `ahr-migrate` |
| Retry Skipped Migrations | ⚠️ AHR migration semantics | `ahr-migrate --retry-skipped` (wraps `migrate.sh`) | `ahr-migrate` |

### System Menu

| Omarchy Label | AHR Equivalent | Command | Guard | Safety |
|---|---|---|---|---|
| Lock Screen | ✅ Direct | `ahr-system-lock` | `hyprlock` or `swaylock` | Background action |
| Suspend | ✅ Direct | `ahr-system-suspend` | OpenRC elogind | Requires `confirm_yes` |
| Hibernate | ✅ Direct | `ahr-system-hibernate` | OpenRC elogind | Requires `confirm_yes` |
| Logout | ✅ Direct | `hyprctl dispatch exit` | `hyprctl` | Immediate exit |
| Restart | ✅ Direct | `sudo reboot` via `run_terminal_script` | `sudo` | Requires `confirm_yes` |
| Power Off | ✅ Direct | `sudo poweroff` via `run_terminal_script` | `sudo` | Requires `confirm_yes` |
| Open Terminal (AHR extra) | AHR extra | `ahr-launch-terminal` | Terminal app | Background |
| Open App Launcher (AHR extra) | AHR extra | `ahr-launch-apps` | walker/wofi/rofi | Background |

---

## 2. Unsupported Items: Omarchy Label → Reason

### Deferred / Unsupported Omarchy Features

| Omarchy Menu Item | Category | Reason |
|---|---|---|
| Learn > Tmux keybindings | 🚫 Unsupported | AHR doesn't have tmux keybinding documentation. Could be added as optional polish. |
| Learn > Omarchy manual | 🚫 Unsupported | Links to Omarchy web app. AHR has its own docs (Getting Started, Quick Reference, README). |
| Learn > Neovim keymaps | 🚫 Unsupported | Links to LazyVim keymap docs. AHR has Quick Reference instead. Deferred. |
| Learn > Bash devhints | 🚫 Unsupported | Links to external devhints site. Deferred. |
| Trigger > Reminder | 🚫 Needs new command | No `ahr-reminder` command exists yet. Menu entry shows "coming soon" notification. |
| Trigger > Transcode | 🚫 Needs new command | No `ahr-transcode` command exists yet. Menu entry shows "coming soon" notification. |
| Trigger > Share | 🚫 Needs new command | No `ahr-share` command exists yet. Menu entry shows "coming soon" notification. |
| Trigger > Hardware | 🚫 Needs new command | No `ahr-hardware` command exists yet. Menu entry shows "coming soon" notification. |
| Capture > Text Extraction | 🚫 Needs new command | No OCR/text-extraction command exists in AHR. Deferred. |
| Toggle > Screensaver | 🚫 Needs new command | No screensaver toggle command exists in AHR. Deferred. |
| Toggle > Workspace Layout | 🚫 Needs new command | No hyprland workspace layout cycle command. Deferred. |
| Toggle > Window Gaps | 🚫 Needs new command | No hyprland window gap toggle command. Deferred. |
| Toggle > 1-Window Ratio | 🚫 Needs new command | No window single-square-aspect toggle. Deferred. |
| Toggle > Monitor Scaling | 🚫 Needs new command | No monitor scaling cycle command. Deferred. |
| Toggle > Direct Boot | 🚫 Needs new command | No direct-boot configuration command. Deferred. |
| Toggle > Passwordless Sudo | 🚫 Needs new command | No sudo-passwordless toggle command. Deferred. |
| Style > Unlock (lock screen) | 🚫 Unsupported | Omarchy unlock screen is a custom Walker menu (`-m menus:omarchyunlocks`). AHR doesn't have this. |
| Style > Corners (Sharp/Round) | 🚫 Needs new command | No `ahr-style-corners` command exists. Deferred. |
| Style > Hyprland visual settings | 🚫 Unsupported | Omarchy opens `~/.config/hypr/looknfeel.lua`. AHR's hyprland config is different format. |
| Style > Screensaver branding | 🚫 Unsupported | Omarchy has text/image/default branding for screensaver. No AHR equivalent. |
| Style > About branding | 🚫 Unsupported | Omarchy has text/image/default branding for about screen. AHR has terminal about display. |
| Setup > Power Profile | 🚫 Needs new command | No power profile switching in AHR setup menu. Uses `powerprofilesctl` in Omarchy. |
| Setup > System Sleep | 🚫 Needs new command | Suspend/hibernate toggle config not in AHR setup. |
| Setup > Monitors | 🚫 Unsupported | Omarchy opens hypr monitors config. AHR doesn't have this entry. |
| Setup > Keybindings (config) | 🚫 Unsupported | Omarchy opens hypr bindings config. Not in AHR setup. |
| Setup > Input (config) | 🚫 Unsupported | Omarchy opens hypr input config. Not in AHR setup. |
| Setup > DNS | 🚫 Needs new command | No DNS setup command in AHR. |
| Setup > Security (Fingerprint/Fido2) | 🚫 Needs new command | No security setup scripts in AHR. |
| Install > Web App | 🚫 Unsupported | No `omarchy-webapp-install` equivalent. Deferred. |
| Install > TUI | 🚫 Unsupported | No `omarchy-tui-install` equivalent. Deferred. |
| Install > Service (Dropbox/Tailscale/etc.) | 🚫 Unsupported | No install-service commands in AHR. Deferred. |
| Install > Development environments | 🚫 Unsupported | No `omarchy-install-dev-env` equivalent. Deferred. |
| Install > Editors (VSCode/Cursor/etc.) | 🚫 Unsupported | No editor install commands in AHR. Deferred. |
| Install > Terminals (Alacritty/etc.) | 🚫 Unsupported | No terminal install commands in AHR. Deferred. |
| Install > Browsers (Chrome/Firefox/etc.) | 🚫 Unsupported | No browser install commands in AHR. Deferred. |
| Install > AI (Ollama/LM Studio/etc.) | 🚫 Unsupported | No AI install commands in AHR. Deferred. |
| Install > Gaming | 🚫 Unsupported | No gaming install commands in AHR. Deferred. |
| Install > Windows VM | 🚫 Unsupported | No Windows VM install command in AHR. Deferred. |
| Remove > All subcategories | 🚫 Unsupported | AHR's Remove menu is intentionally minimal. |
| Update > Channel | 🚫 Unsupported | No update channels concept in AHR (AHR uses git-based migrations). |
| Update > Config reset | 🚫 Unsupported | AHR doesn't have config reset commands for individual components. |
| Update > Extra Themes | 🚫 Unsupported | No separate theme update command in AHR (themes update via `ahr-theme update`). |
| Update > Process restart | 🚫 Unsupported | AHR has restart commands in Style/Setup menus, not Update. |
| Update > Hardware restart | 🚫 Unsupported | No hardware restart commands in AHR. |
| Update > Firmware | 🚫 Unsupported | No firmware update command in AHR. |
| Update > Password | 🚫 Unsupported | No password management in AHR menu. |
| Update > Timezone | 🚫 Unsupported | No timezone setup in AHR menu. |
| Update > Time | 🚫 Unsupported | No time sync in AHR menu. |
| System > Screensaver | 🚫 Needs new command | No screensaver launch command in AHR. Deferred. |

---

## 3. Safety Classifications

### OpenRC-Native Adaptations
Items that use `systemctl` in Omarchy but have been adapted for OpenRC:
- Docker stack management: `rc-service docker start` / `rc-update add docker default`
- Printing stack management: `rc-service cupsd start` / `rc-update add cupsd default`
- Suspend/Hibernate: Uses AHR wrapper commands (`ahr-system-suspend`, `ahr-system-hibernate`) which call OpenRC-compatible elogind paths

### Systemd-Only Actions (Intentionally Omitted)
These Omarchy actions use systemd and have no OpenRC-safe equivalent:
- `systemctl suspend` / `systemctl hibernate` (AHR uses elogind-compatible wrappers instead)
- `systemctl --user enable --now emacs.service` (used in Omarchy install menu)
- `uwsm-app` service wrapping (AHR doesn't use UWSM)

### Guarded Actions (Require `confirm_yes`)
- Docker stack install/remove
- Printing stack install/remove
- System reboot
- System power off
- System suspend
- System hibernate

### Package Availability Checks (`menu_require`)
- `grim` / `slurp` for screenshots
- `gpu-screen-recorder` for screen recording
- `cliphist` for clipboard
- `hyprpicker` for color picker
- `hypridle` for idle toggle
- Config editing: delegates dependency handling to `ahr-edit-config` (no `menu_require`)

### Terminal Handoff Pattern
Long-running commands use `run_terminal_script()` or `run_terminal_command()`:
- Package installs/removes (user provides package names interactively)
- Theme operations (background gallery, theme install from URL)
- System power off (requires `sudo` password)
- Update runs (show terminal output)

### Notification Pattern
Missing dependency notifications use `ahr_notify`:
```bash
ahr_notify "artix-hypr-remix" "'$cmd' is not installed — install with: sudo pacman -S $pkg"
```
This is consistent across all `menu_require` calls.
