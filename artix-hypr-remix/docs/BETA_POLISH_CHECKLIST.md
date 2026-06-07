# Beta Polish Implementation Checklist

This checklist is for future implementation passes that polish Artix Hypr Remix from "working beta" toward an Omarchy-class daily desktop experience while preserving Artix/OpenRC correctness.

## 1. Purpose and target

The beta polish target is an Artix OpenRC-native Omarchy-equivalent Hyprland desktop setup with a safe installer, a polished first-login experience, rich menus, theme and wallpaper gallery workflows, complete default-app behavior, and practical capture/share/toggle utilities. This document is an implementation checklist for future Codex sessions: pick one surface, inspect current behavior, compare against Omarchy for UX completeness, adapt safely for Artix/OpenRC, validate, then update this checklist. Omarchy is the UX and feature reference for completeness, package choices, workflows, menus, themes, and polish; it is not a systemd, UWSM, SDDM, or Arch blueprint for this project.

Primary reference points:

- AHR repo root: `artix-hypr-remix/`
- Omarchy reference checkout: `../omarchy`
- Downloaded Omarchy manual: `../the-omarchy-manual.md`
- Existing parity audit: `MILESTONE4_PARITY_AUDIT.md`
- Existing completion tracker: `COMPLETION_CHECKLIST.md`
- Installed framework source: `config/artix-hypr-remix/`

## 2. Non-negotiable project constraints

- [ ] Do not add a systemd requirement.
- [ ] Do not add unguarded `systemctl`; prefer OpenRC equivalents or document unsupported behavior.
- [ ] Do not add unguarded `loginctl`; if elogind `loginctl` is used, guard it with command detection, fallback behavior, and explicit OpenRC notes.
- [ ] Prefer `rc-service`, `rc-update`, OpenRC service files, and OpenRC-native behavior.
- [ ] Do not assume AUR helpers are installed; detect `paru`/`yay` or provide non-AUR fallback/defer.
- [ ] Do not assume a fixed username; resolve target user through installer/helper context.
- [ ] Do not assume `/home/$USER` exists without checking `getent passwd`, directory existence, and unsafe homes such as `/`.
- [ ] Do not overwrite user configs without timestamped backups and clear user-facing messaging.
- [ ] Do not silently ignore package failures; required package failures must fail loudly, optional packages must be reported as skipped/deferred.
- [ ] Do not assume NetworkManager, SDDM, or GDM unless explicitly selected by this project. Current supported network path uses NetworkManager; display-manager path is optional `greetd`.
- [ ] Preserve Artix/OpenRC correctness over Omarchy exactness.
- [ ] Run `scripts/check-openrc-portability.sh` after touching runtime scripts, and resolve any `systemctl`, `loginctl`, `journalctl`, `systemd-run`, or `/run/systemd` findings intentionally.
- [ ] Keep broad package install/remove actions conservative until package availability and rollback behavior are tested on Artix.

## 3. Current beta status

Future sessions should update this table after direct inspection or validation.

| Area | Status: present / rough / missing / unknown | Evidence/files | Omarchy reference | Priority | Notes |
| --- | --- | --- | --- | --- | --- |
| Installer safety | present | `install.sh`, `lib/checks.sh`, `lib/dotfiles.sh`, `lib/state.sh`, `COMPLETION_CHECKLIST.md` | `../omarchy/install/` | Public beta blocker | Phase-based install, logging, backups, preflight, dry run, resume paths are present. Keep validating re-runs. |
| Package coverage | rough | `packages/*.txt`, `flatpaks/*.txt`, `docs/package-substitutions.md` | `../omarchy/install/packages.sh`, Omarchy package helpers | High-impact polish | Core Hyprland/audio/network/files/editor packages present; optional AUR and richer app categories remain narrow by design. |
| OpenRC services | present | `services/openrc-default.txt`, `lib/openrc.sh`, `scripts/post-install-smoke.sh` | Omarchy systemd service usage | Public beta blocker | `dbus`, `elogind`, `NetworkManager`, `bluetoothd` are handled through OpenRC. |
| Hyprland launch/session | present | `config/artix-hypr-remix/bin/start-hyprland-session.sh`, `lib/tty.sh`, `STARTUP_ARCHITECTURE.md` | `../omarchy/default/wayland-sessions/omarchy.desktop` | Public beta blocker | TTY default and optional `greetd`; no UWSM/SDDM. |
| Waybar/status bar | present but rough | `config/waybar/config.jsonc`, `config/waybar/style.css`, Waybar helper scripts | `../omarchy/default/waybar/`, `../omarchy/themes/*/waybar.css` | High-impact polish | Indicators for updates, recording, idle, notifications, weather, voxtype exist; position/theme richness is thinner than Omarchy. |
| App launcher | present | `config/artix-hypr-remix/bin/ahr-launch-apps`, `ahr-menu`, `config/walker/config.toml` | `../omarchy/bin/omarchy-menu`, Walker defaults | Public beta blocker | Supports `wofi`/`walker`/`rofi`/TTY backend fallback. |
| Power/logout menu | present but rough | `ahr-menu`, `ahr-system-lock`, `ahr-system-suspend`, `ahr-system-hibernate`, `ahr-system-reboot` | `../omarchy/bin/omarchy-menu` System menu | Public beta blocker | Lock/logout/suspend/hibernate/reboot/power off exposed; validate suspend/hibernate and portability policy. |
| Screenshot/capture tools | present | `ahr-capture-screenshot`, `ahr-capture-picker`, `ahr-capture-screenrecording`, `config/hypr/hyprland.conf` | Omarchy Capture menu and `omarchy-capture-*` commands | High-impact polish | Fullscreen/window/area screenshot modes, screenshot picker (PrtSc), and screen recording toggle implemented; still missing OCR, color picker, audio/webcam recording menu paths. |
| Clipboard history | present | `ahr-clipboard-picker`, Hyprland `wl-paste` autostart, `cliphist` package | `../omarchy/default/hypr/bindings/clipboard.lua` | High-impact polish | Text/image watchers present; keep validating picker backend and image history. |
| Notifications | present | `config/mako/config`, Mako autostart, `ahr-toggle-notification-silencing`, Waybar indicator | Omarchy notification toggle/status | High-impact polish | Basic Mako control and toggle state exist. |
| Lock/idle behavior | present but needs hardware testing | `config/hypr/hypridle.conf`, `config/hypr/hyprlock.conf`, `ahr-system-lock`, `ahr-toggle-idle` | Omarchy screensaver/lock/idle helpers | Public beta blocker | Validate after suspend/resume on laptop hardware. |
| Wallpaper/theme handling | present but rough | `ahr-theme*`, `default/themes/*`, `default/themed/*.tpl`, `ahr-launch-wallpaper-session` | `../omarchy/themes/*`, `omarchy-theme-*`, `omarchy-theme-bg-*` | High-impact polish | Theme set/list/current/refresh/background state exist; gallery previews/install/remove/update are deferred. |
| Default apps | present but rough | `first-run.d/56-default-apps.sh`, `ahr-default-browser`, `ahr-default-terminal`, `ahr-launch-*` | Omarchy Defaults menu | High-impact polish | Browser, terminal, file manager defaults exist; default editor and broader `xdg-mime` coverage are missing. |
| Browser/terminal/file manager/editor | present but rough | `packages/20-terminal-shell.txt`, `packages/30-files.txt`, `packages/40-editors.txt`, launch helpers | Omarchy install/default browser/terminal/editor menus | High-impact polish | Firefox, Ghostty, Nautilus, Yazi, Neovim, Helix are present; install/remove defaults are intentionally narrow. |
| Audio/network/bluetooth | present | `packages/50-audio.txt`, `packages/60-network-openrc.txt`, `ahr-launch-audio`, `ahr-launch-wifi`, `ahr-launch-bluetooth` | Omarchy Setup Audio/Wifi/Bluetooth/Power | Public beta blocker | Uses PipeWire/WirePlumber, NetworkManager OpenRC, BlueZ OpenRC/Blueman. Power profile UX needs testing. |
| Portals/screen sharing | present but needs app testing | `packages/10-hyprland.txt`, `config/hypr/xdph.conf`, `scripts/post-install-smoke.sh` | Omarchy portal setup | Public beta blocker | Portal packages are installed; validate with browser/Flatpak screen share. |
| Documentation | present | `README.md`, `BETA_SUPPORT_MATRIX.md`, `RECOVERY_AND_RESET.md`, `MILESTONE*_*.md`, `docs/` | Omarchy docs/learn menu | High-impact polish | Strong release docs; keep docs synced with menu/workflow changes. |
| Healthcheck/repair tooling | present | `scripts/doctor.sh`, `scripts/post-install-smoke.sh`, `ahr-repair`, `ahr status`, `ahr list-backups` | Omarchy update/refresh/repair patterns | Public beta blocker | Good foundation; add UX-specific checks as polish lands. |

## 4. Omarchy parity audit checklist

Use these classifications for AHR status:

- Present
- Present but rough
- Missing
- Artix/OpenRC adaptation required
- Intentionally different
- Unsupported for now
- Unknown; needs testing

Use these classifications for differences:

- Required parity
- Artix/OpenRC adaptation
- Optional polish
- Intentional difference
- Unsupported for now
- Unknown; needs testing

| Category | AHR status classification | Difference classification | AHR files to inspect | Omarchy files to compare | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Installer flow | Present | Artix/OpenRC adaptation | `install.sh`, `lib/*.sh` | `../omarchy/install/` | Preserve phase safety, backups, host policy, OpenRC paths. |
| Package installation | Present but rough | Artix/OpenRC adaptation | `packages/*.txt`, `lib/pacman.sh`, `lib/aur.sh`, `ahr-menu` Install | Omarchy package/install helpers | Do not port broad package categories until Artix package names and rollback behavior are tested. |
| Default apps | Present but rough | Required parity | `first-run.d/56-default-apps.sh`, `ahr-default-browser`, `ahr-default-terminal` | Omarchy Defaults menu and default helpers | Add editor default and broader MIME validation before calling complete. |
| Hyprland config | Present | Required parity | `config/hypr/hyprland.conf`, `config/hypr/*.lua` | `../omarchy/default/hypr/` | Runtime config is `.conf`; Lua files are source/planning notes. Keep runtime docs clear. |
| Waybar | Present but rough | Optional polish | `config/waybar/config.jsonc`, `style.css`, status helpers | `../omarchy/default/waybar/`, `../omarchy/themes/*/waybar.css` | Add safer position/theme controls only after validating reload behavior. |
| Menus | Present but rough | Required parity | `ahr-menu`, `ahr-menu-keybindings` | `../omarchy/bin/omarchy-menu` | AHR taxonomy exists; polish Capture, Toggle, Defaults, Help, and validation messages. |
| Theme switching | Present | Required parity | `ahr-theme`, `ahr-theme-lib.sh`, `default/themes/*` | `../omarchy/bin/omarchy-theme-*`, `../omarchy/themes/*` | Status command, backups, post-switch validation, doctor checks added. |
| Theme: install/remove/update | Missing | Required for stable | — | `omarchy-theme-install`, `omarchy-theme-remove`, `omarchy-theme-update` | Git remote theme management; add after validating theme engine stability and Artix git/network assumptions. |
| Theme: browser/editor/foot sync | Missing | Optional polish | — | `omarchy-theme-set-browser`, `omarchy-theme-set-vscode`, `omarchy-theme-set-foot`, `omarchy-theme-set-obsidian`, `omarchy-theme-set-gnome` | Chromium/VS Code/Cursor/Foot/Obsidian/GNOME theme sync. Safe to add incrementally per app. |
| Wallpaper/gallery | Present but rough | Optional polish | `ahr-theme bg-*`, `ahr-launch-wallpaper-session`, `scripts/wallpaper.sh` | `omarchy-theme-bg-switcher`, `../omarchy/themes/*/backgrounds/` | Add preview/gallery only if assets and fallback behavior are clean. |
| Fonts/icons/cursor | Present but rough | Optional polish | `packages/80-fonts-themes.txt`, `default/themes/*/icons.theme`, `fontconfig/fonts.conf` | Omarchy Font menu and theme files | Add font switching only after terminal/GTK/Waybar sync is designed. |
| Notifications | Present | Required parity | `config/mako/config`, notification toggle scripts | Omarchy notification helpers | Keep Mako restart/silence/dismiss reliable. |
| Screenshots | Present | Required parity | `ahr-capture-screenshot`, Hyprland Print binding | Omarchy screenshot commands | Fullscreen/window/area modes and open-after-capture implemented. |
| Screen recording | Present but rough | Optional polish | `ahr-capture-screenrecording`, Waybar recording indicator | Omarchy screenrecord menu | Add audio/webcam modes only after device detection and failure handling are tested. |
| Screensaver/suspend availability toggles | Missing | Optional polish | — | `omarchy-toggle-screensaver`, `omarchy-toggle-suspend` | State-flag toggles that hide menu items. Low-risk; add if menu structure supports conditional visibility. |
| Clipboard | Present | Required parity | `ahr-clipboard-picker`, Hyprland autostart | Omarchy clipboard bindings | Validate image history and picker backend fallback. |
| Clipboard: unified hotkeys | Missing | Optional polish | — | Omarchy Super+C/V/X clipboard via keyd/wtype | Requires keyd remapping layer; keep as intentional difference unless AHR adopts a similar approach. |
| Lock/idle | Present but rough | Required parity | `hypridle.conf`, `hyprlock.conf`, idle toggle/status | Omarchy lock/screensaver/idle helpers | Validate suspend/resume and screensaver scope. |
| Portals | Present but needs testing | Required parity | `packages/10-hyprland.txt`, `config/hypr/xdph.conf`, smoke scripts | Omarchy portal setup | Test browser and Flatpak screen sharing. |
| Audio | Present | Required parity | `packages/50-audio.txt`, `ahr-launch-audio`, Waybar pulseaudio | Omarchy audio launcher/restart | Add output/mic toggle polish if `pavucontrol`/`pamixer` behavior is reliable. |
| Network | Present | Artix/OpenRC adaptation | `packages/60-network-openrc.txt`, `ahr-launch-wifi`, `services/openrc-default.txt` | Omarchy Wi-Fi setup/restart | NetworkManager is project-selected; keep OpenRC service control. |
| Bluetooth | Present | Artix/OpenRC adaptation | `packages/60-network-openrc.txt`, `ahr-launch-bluetooth`, OpenRC services | Omarchy Bluetooth setup/restart | Validate hardware-present and hardware-absent behavior. |
| Capture: OCR/text extraction | Missing | Optional polish | — | `omarchy-capture-text-extraction` | Requires `tesseract` and language data; add after screenshot pipeline is stable. Make dependency optional. |
| Power management | Present but rough | Artix/OpenRC adaptation | laptop profile, `ahr-system-suspend`, `ahr-system-hibernate`, `power-profiles-daemon` package | Omarchy Power Profile/System Sleep | Resolve `loginctl` portability policy and test power profile UI. |
| Keybindings | Present | Required parity | `config/hypr/hyprland.conf`, `keybinds.lua`, `ahr-menu-keybindings` | Omarchy bindings and keybinding viewer | Keep viewer labels synced with runtime `.conf`. |
| Nightlight toggle | Present | Optional polish | `ahr-toggle-nightlight`, `ahr-waybar-nightlight-status`, `ahr-menu` Toggle menu, `config/waybar/config.jsonc` nightlight-indicator, `config/hypr/hyprland.conf` binding | `omarchy-toggle-nightlight` (hyprsunset 4000K/6500K) | Implemented: toggles hyprsunset 4000K/6500K, Toggle menu entry, Waybar indicator with signal 12, Super+Ctrl+N binding. |
| Notices (date/time/battery/weather) | Missing | Optional polish | — | Omarchy hotkey-triggered notification notices | Lightweight notification commands; add after notification toggle pipeline is reliable. |
| Reminders | Missing | Optional polish | — | Omarchy reminder CLI/menu (`omarchy reminder`) | Notification-based countdown timer; requires only `notify-send` and state file. |
| Help/welcome/discoverability | Present but rough | Required parity | `first-run.d/110-welcome.sh`, `docs/quick-reference.md`, Learn menu | Omarchy welcome/manual links | Add clearer "next action" affordance if tester confusion appears. |
| Update/repair tooling | Present | Artix/OpenRC adaptation | `ahr-update`, `ahr-repair`, `ahr-migrate`, `doctor.sh` | `omarchy-update`, refresh/update menus | Keep AHR update safer and narrower than Omarchy system-maintenance menus. |
| Toggle state framework | Missing | Optional polish | — | `omarchy-toggle-enabled`, `~/.local/state/omarchy/toggles/` | Shared flag-file toggle pattern; useful foundation before adding individual toggles. |
| Touchpad toggle | Missing | Optional polish | — | `omarchy-toggle-touchpad` | Enable/disable with state file; requires hardware detection helper. |
| Touchscreen toggle | Missing | Unsupported for now | — | `omarchy-toggle-touchscreen` | Hardware-dependent; defer until touchpad toggle is validated. |
| Uninstall/reset guidance | Present | Intentional difference | `RECOVERY_AND_RESET.md`, `ahr list-backups`, `ahr repair` | Omarchy remove/refresh tooling | Full uninstall remains out of scope unless explicitly accepted. |
| Documentation | Present | Required parity | `README.md`, support/release/milestone docs | Omarchy docs/learn workflow | Keep public beta docs aligned with supported scope. |

## 4.1 Manual-derived final-product backlog

The downloaded Omarchy manual makes the final product surface larger than the
beta polish surface. Keep this section as a scope ledger, not a beta blocker
list. A future implementation pass should promote items from here only after
deciding that the feature is Artix/OpenRC-safe, valuable for AHR users, and
small enough to validate.

Use these decision labels:

- Required for stable
- OpenRC adaptation
- Optional polish
- Unsupported for now
- Probably out of scope
- Unknown; needs design/testing

| Manual feature area | AHR decision | Why / constraints | Likely follow-up |
| --- | --- | --- | --- |
| ISO / full-disk installer | Unsupported for now | AHR is script-first until the installer is proven across real Artix OpenRC hosts. ISO work adds storage, bootloader, encryption, and release-engineering risk. | Keep `docs/distribution-decision.md` current; revisit only after stable script installer. |
| Full-disk encryption / boot unlock branding | Probably out of scope | Omarchy controls the whole install and boot stack; AHR starts from an existing Artix system and should not assume disk layout or bootloader. | Document as an intentional difference unless an optional ISO path is approved. |
| System snapshots / rollback | Unknown; needs design/testing | Valuable for update recovery, but risky without choosing a filesystem/snapshot backend. Artix installs may use many layouts. | Research Artix-safe snapshot strategy; keep package update rollback manual for now. |
| Channelized updates | Optional polish | Omarchy has stable/RC/edge/dev channels and mirror policy; AHR currently has repo update/migration tooling without channel semantics. | Consider `ahr update` channel metadata only after release process matures. |
| Web app install/remove | Optional polish | Manual treats web apps as first-class launchable apps. AHR has no desktop-entry/favicons/browser-profile workflow yet. | Design `ahr-webapp-*` with favicon fallback, browser choice, cleanup, and no systemd assumptions. |
| Broad app catalog | Optional polish | Omarchy documents GUIs, commercial apps, media, chat, office, and services. AHR has a smaller package/Flatpak set by design. | Add curated Artix/Flatpak app profiles gradually with availability checks. |
| AI / agent CLI workflows | Optional polish | Omarchy includes OpenCode, Claude Code, lazy npm stubs, local LLM guidance, and an Omarchy skill. This is useful but broad and fast-moving. | Add only opt-in profile/docs after deciding supported tooling and package sources. |
| Development environment installers | Optional polish | Omarchy leans on mise and broad runtime installers. AHR currently provides shell/dev basics, not language-stack management. | Consider a guarded dev profile; avoid making mise or language installers required for desktop success. |
| Gaming installers | Optional polish | Steam, RetroArch, Lutris, Heroic, Moonlight, cloud gaming, and controller support have large package and hardware test surfaces. | Keep post-beta; require package matrix and rollback/removal checks. |
| Windows VM workflow | Probably out of scope | Requires Docker/VM orchestration, storage assumptions, RDP launcher, and support burden. | Keep unsupported unless explicitly promoted to an optional profile. |
| Rich theme gallery / extra themes | Required for stable or high-value polish | The manual makes theme previews/background switching central to the Omarchy feel. AHR has a theme engine but few themes and no rich preview/install/update/remove flow. | Prioritize local gallery/status/preview before remote theme install/remove. |
| Font switching | Optional polish | Omarchy exposes font selection and theme synchronization. AHR has font packages and fixed template values. | Add only after terminal, Waybar, Mako, GTK, and fontconfig update behavior is designed. |
| Background install/gallery | High-value polish | Manual encourages per-theme background folders and easy addition. AHR has `bg-next`/`bg-set`, but not a gallery or import flow. | Add local background picker/import with validation and readable fallback. |
| Branding screensaver/about | Optional polish | Omarchy supports custom logos/screensaver/about visuals. AHR has a textual About and no branding workflow. | Keep optional; ensure no boot-stack assumptions leak in. |
| Reminder and notices | Optional polish | Manual includes reminders, date/time/weather/battery notices. AHR has some Waybar status helpers but no reminder UX. | Add lightweight notification timers only if dependency-free and easy to explain. |
| OCR / text extraction | Optional polish | Useful capture workflow but depends on OCR packages/language data and good failure messages. | Add after screenshot pipeline is stable; make dependency optional. |
| Dictation / Voxtype | Optional polish | AHR has some optional Voxtype hooks, but no complete install/remove parity. | Keep optional; document hardware/model/privacy assumptions. |
| LocalSend / share workflow | Optional polish | Manual treats sharing as a menu workflow. AHR defers LocalSend/share. | Add after package availability and network-discovery behavior are tested. |
| Transcode workflow | Optional polish | Useful but not core desktop readiness. | Defer until file-manager integration and ffmpeg UX are designed. |
| Monitor scaling / mirror / hardware menu | OpenRC adaptation | Manual includes rich monitor/laptop/hardware controls. These can blank displays or depend on specific hardware. | Add only safe, reversible monitor actions with fallback docs. |
| Keyboard/mouse/trackpad setup menu | Required for stable polish | Manual guides users to input config. AHR has config files but limited menu affordance. | Add Setup entries and docs for input/monitors before adding risky toggles. |
| System sleep toggles / hibernation setup | OpenRC adaptation | Suspend/hibernate exist in AHR, but Omarchy exposes enable/disable flows. Hibernation depends on swap/filesystem layout. | Keep suspend validated; treat hibernation setup as design-needed. |
| Fingerprint / FIDO2 auth | Optional polish | Security hardware auth is device-specific and PAM-sensitive. | Defer until tested on Artix OpenRC with clear rollback. |
| Package/AUR install/remove UX | OpenRC adaptation | AHR has generic package/AUR/Flatpak menu actions. Omarchy has richer curated package helpers. | Improve guards/previews first; add curated installers only after Artix validation. |
| Broad remove/preinstall cleanup | Probably out of scope | Removal can destroy user choices and is harder to validate than install. | Keep conservative; prefer docs and explicit package remove previews. |
| Troubleshooting/manual depth | Required for stable | Omarchy manual is broad and user-facing. AHR docs are strong but more project/release oriented. | Add user manual pages as features stabilize; avoid documenting unsupported workflows as promised. |
| Unified clipboard hotkeys (Super+C/V/X) | Optional polish | Omarchy unifies clipboard hotkeys via keyd/wtype so Super+C/V/X work everywhere. AHR uses default Ctrl+Shift+C/V in terminals. | Keep as intentional difference unless AHR adopts a similar keyd remapping layer. |
| Nightlight toggle (hyprsunset) | Optional polish | Omarchy toggles screen temperature (4000K/6500K) with Super+Ctrl+N. | ✅ Implemented in session 2026-06-07: `ahr-toggle-nightlight`, Waybar indicator, Toggle menu entry, Super+Ctrl+N binding. |
| Screensaver/suspend availability toggles | Optional polish | Omarchy can hide Suspend/Screensaver from menus via state flags. AHR always shows all power options. | Add if menu structure supports conditional item visibility. |
| Theme: browser/editor/foot sync | Optional polish | Omarchy syncs themes to Chromium, VS Code, Cursor, Foot terminal, Obsidian, and GNOME. AHR only applies theme to desktop shell/config templates. | Safe to add incrementally per app; start with one (e.g. Foot terminal). |
| Theme: install/remove/update via git | Required for stable or high-value polish | Omarchy supports `omarchy theme install <git-url>`, remove, and update. AHR has local themes only, no remote install flow. | Add after local theme engine is stable; require git availability check. |
| Toggle state framework | Optional polish | Omarchy uses `~/.local/state/omarchy/toggles/` flag files and `omarchy-toggle-enabled` for consistent toggle state. AHR toggles are ad-hoc. | Adopt if multiple toggles are implemented; keeps state queryable by Waybar and menus. |
| Touchpad toggle | Optional polish | Omarchy can enable/disable/toggle touchpad. AHR has no touchpad control. | Add after hardware detection helper is designed; safe on non-laptop hardware (no-op). |

Manual-derived stable criteria should stay narrower than "clone every manual
feature". AHR can be stable when the supported OpenRC-native desktop is
excellent, documented, and validated, while the unsupported or optional manual
features are clearly classified.

## 5. UX surface implementation checklists

Work by user-facing surface. Each future patch should update the matching subsection with evidence and validation results.

### 5.1 Launcher and app menus

Desired user experience:

- [ ] `Super+Space` opens a responsive main menu with obvious routes for Apps, Learn, Trigger, Style, Setup, Install, Remove, Update, About, and System.
- [ ] App launcher works with the best available backend and explains missing dependencies.
- [ ] Utility, power, network, Bluetooth, audio, clipboard, capture, theme, wallpaper, settings, and help actions are discoverable without reading source files.
- [ ] Every menu action either works, explains what dependency is missing, or is clearly marked unsupported.

Current files to inspect:

- `config/artix-hypr-remix/bin/ahr-menu`
- `config/artix-hypr-remix/bin/ahr-launch-apps`
- `config/artix-hypr-remix/bin/ahr-menu-keybindings`
- `config/artix-hypr-remix/bin/ahr-launch-audio`
- `config/artix-hypr-remix/bin/ahr-launch-wifi`
- `config/artix-hypr-remix/bin/ahr-launch-bluetooth`
- `config/artix-hypr-remix/bin/ahr-clipboard-picker`
- `config/hypr/hyprland.conf`
- `config/walker/config.toml`

Omarchy files to compare:

- `../omarchy/bin/omarchy-menu`
- `../omarchy/bin/omarchy-menu-keybindings`
- `../omarchy/default/hypr/bindings/`
- `../omarchy/default/walker/`

Dependencies to verify:

- [ ] `wofi`, `walker`, or `rofi`
- [ ] `hyprctl`
- [ ] `xdg-open`, `xdg-mime`, `xdg-settings`
- [ ] `pavucontrol`, `blueman-manager`, NetworkManager UI/TUI selected by AHR
- [ ] `cliphist`, `wl-clipboard`
- [ ] `grim`, `slurp`, `gpu-screen-recorder`

Safe implementation tasks:

- [x] Add dependency guards and user-facing failure text for every menu action that shells out to optional tools.
- [x] Add explicit menu entries for clipboard history (Capture menu), color picker (Capture menu; guarded by hyprpicker), screenshot modes, theme status, and wallpaper selection. Screen recording status is exposed via Waybar indicator, keybinding help via Learn menu.
- [ ] Split oversized menus only when it improves scanability; keep AHR command names stable.
- [ ] Add TTY fallback text for actions that cannot run graphically.
- [ ] Keep Omarchy-compatible aliases only after native `ahr-*` behavior exists.

Risky/deferred tasks:

- [ ] Broad Omarchy-style Install/Remove menus for gaming, Windows, AI, web apps, and development stacks.
- [ ] Hardware toggles that depend on machine-specific devices.
- [ ] Passwordless sudo or boot-flow toggles.

Validation steps:

- [ ] In Hyprland, press `Super+Space` and open each top-level menu.
- [x] Run `AHR_MENU_BACKEND=tty` — verified all menu slices dispatch, all referenced 27 bin scripts exist, `menu_backend` returns tty, all 24 functions are defined. Capture menu now includes Clipboard History and Color Picker entries.
- [ ] Temporarily hide optional commands from `PATH` and confirm graceful failure text.
- [ ] Run `./scripts/smoke-framework.sh --keep-sandbox` after script changes.

OpenRC/Artix notes:

- [ ] Use `rc-service`/`rc-update` for service actions exposed in menus.
- [ ] Avoid Omarchy systemd/UWSM/SDDM menu actions unless rewritten for AHR.

### 5.2 Theme and wallpaper/gallery UX

Desired user experience:

- [ ] User can discover available themes, preview or understand them, apply one, switch backgrounds, and recover from a broken theme.
- [ ] Selected theme persists across login and refreshes Waybar, Mako, Hyprland, terminal, GTK, icons, cursor, and fonts where supported.
- [ ] Theme switching is reversible and does not destroy user customizations without backup.

Current files to inspect:

- `config/artix-hypr-remix/bin/ahr-theme`
- `config/artix-hypr-remix/bin/ahr-theme-lib.sh`
- `config/artix-hypr-remix/bin/ahr-theme-set`
- `config/artix-hypr-remix/bin/ahr-theme-refresh`
- `config/artix-hypr-remix/bin/ahr-theme-bg-set`
- `config/artix-hypr-remix/bin/ahr-theme-bg-next`
- `config/artix-hypr-remix/bin/ahr-launch-wallpaper-session`
- `config/artix-hypr-remix/default/themes/*`
- `config/artix-hypr-remix/default/themed/*.tpl`
- `config/artix-hypr-remix/docs/theme-assets.md`

Omarchy files to compare:

- `../omarchy/themes/*`
- `../omarchy/bin/omarchy-theme-*`
- `../omarchy/bin/omarchy-font-*`
- `../omarchy/default/waybar/`

Dependencies to verify:

- [ ] `swaybg` or selected wallpaper backend
- [ ] `makoctl`, `waybar`, `hyprctl`
- [ ] `ghostty`, GTK settings tooling, icon/cursor theme packages
- [ ] Image formats used by theme backgrounds

Safe implementation tasks:

- [x] Validate theme discovery from AHR default/user dirs and Omarchy-compatible dirs.
- [x] Add status output that names current theme, current background, template render state, and missing optional assets.
- [x] Add menu path for background selection from current theme backgrounds.
- [x] Add backups before writing rendered user config files.
- [x] Add validation after switching: Waybar CSS present, Mako config present, terminal template rendered, background target readable.
- [x] Add clear TODO markers for unsupported Omarchy assets such as `swayosd.css`, `vscode.json`, or Chromium themes.

TODO: `ahr-theme status` reports swayosd.css and vscode.json as optional missing assets.
TODO: `ahr_theme_apply_targets` now creates timestamped .bak.* backups before overwriting configs.
TODO: `ahr_theme_apply_current` warns post-switch if Waybar/Mako/Ghostty configs are missing or empty.
TODO: `scripts/doctor.sh` now has `check_theme_state` section for theme health.
TODO: Chromium/Firefox browser theme files are intentionally omitted from AHR theme scope.

Risky/deferred tasks:

- [ ] Visual gallery with previews if it requires new GUI dependencies.
- [ ] Installing/removing/updating remote themes.
- [ ] Global font switcher that rewrites multiple app configs.
- [ ] GTK/icon/cursor changes that require logout or desktop database refresh unless validated.

Validation steps:

- [ ] `ahr theme list`
- [ ] `ahr theme current`
- [ ] `ahr theme set artix-dark`
- [ ] `ahr theme refresh`
- [ ] `ahr theme bg-next`
- [ ] Restart Hyprland session and confirm theme/background persists.

OpenRC/Artix notes:

- [ ] Theme code should remain user-session logic; do not add system services for theme state.

### 5.3 Install/remove/default-app workflows

Desired user experience:

- [ ] Default browser, terminal, file manager, editor, PDF viewer, image viewer, video player, archive manager, music player, and communication apps either work out of the box or have clear setup paths.
- [ ] `xdg-mime` and `xdg-settings` choices are validated before and after changes.
- [ ] Optional install/remove flows are safe, explicit, and do not assume an AUR helper.

Current files to inspect:

- `config/artix-hypr-remix/first-run.d/56-default-apps.sh`
- `config/artix-hypr-remix/bin/ahr-default-browser`
- `config/artix-hypr-remix/bin/ahr-default-terminal`
- `config/artix-hypr-remix/bin/ahr-launch-browser`
- `config/artix-hypr-remix/bin/ahr-launch-terminal`
- `config/artix-hypr-remix/bin/ahr-launch-files`
- `config/artix-hypr-remix/bin/ahr-edit-config`
- `config/artix-hypr-remix/bin/ahr-menu`
- `packages/20-terminal-shell.txt`
- `packages/30-files.txt`
- `packages/40-editors.txt`
- `flatpaks/default.txt`
- `flatpaks/optional.txt`

Omarchy files to compare:

- `../omarchy/bin/omarchy-menu` Defaults/Install/Remove sections
- `../omarchy/bin/omarchy-default-*`
- `../omarchy/bin/omarchy-install-*`
- `../omarchy/bin/omarchy-remove-*`

Dependencies to verify:

- [ ] `xdg-settings`, `xdg-mime`, `gtk-launch`
- [ ] Desktop entries for Firefox, Ghostty, Nautilus, Helix/Neovim, file-roller
- [ ] `pacman`
- [ ] `flatpak`
- [ ] `paru`/`yay` only for optional AUR paths

Safe implementation tasks:

- [x] Add `ahr-default-editor` command for setting Helix/Neovim/Vim as default $EDITOR.
- [x] Add default validation for PDF, image, video, archive, and music MIME types where installed apps exist (imv, mpv, file-roller, firefox).
- [x] Add menu setup entries for Default Editor in Setup menu.
- [ ] Add `--dry-run` or preview output for default-app changes.
- [ ] Keep install/remove menus limited to package sets validated on Artix.
- [ ] For optional apps, check package availability before install and report unsupported package names.

Risky/deferred tasks:

- [ ] Omarchy web app installer parity.
- [ ] Broad AUR-driven browser/editor/gaming/AI installers.
- [ ] Removing preinstalled apps unless ownership and rollback are clear.

Validation steps:

- [ ] `xdg-settings get default-web-browser`
- [ ] `xdg-mime query default inode/directory`
- [ ] `xdg-mime query default text/plain`
- [ ] `xdg-mime query default application/pdf`
- [ ] `xdg-mime query default image/png`
- [ ] `xdg-mime query default video/mp4`
- [ ] `xdg-mime query default application/zip`
- [ ] Open an HTTP link, directory, text file, PDF, image, video, and archive.
- [ ] Re-run `first-run.d/56-default-apps.sh` and confirm idempotency.
- [ ] Run `./scripts/doctor.sh --no-aur` and verify MIME lines appear.

OpenRC/Artix notes:

- [ ] Package install/remove actions must not call `systemctl --user`; service enable/start must use OpenRC or stay unsupported.

### 5.4 Capture/share/toggle flows

Desired user experience:

- [ ] User can capture a region, window, or full screen; start/stop recording; access clipboard history; pick colors; optionally use OCR/share flows if dependencies are supported.
- [ ] Common toggles for notifications, idle lock, night light/gamma, audio output, microphone mute, Bluetooth, network/VPN, webcam, power profile, and display modes are discoverable when safe.
- [ ] Capture outputs are saved in predictable folders and notify the user with open/share affordances where feasible.

Current files to inspect:

- `config/artix-hypr-remix/bin/ahr-capture-screenshot`
- `config/artix-hypr-remix/bin/ahr-capture-screenrecording`
- `config/artix-hypr-remix/bin/ahr-waybar-screen-recording-status`
- `config/artix-hypr-remix/bin/ahr-toggle-idle`
- `config/artix-hypr-remix/bin/ahr-toggle-notification-silencing`
- `config/artix-hypr-remix/bin/ahr-clipboard-picker`
- `config/artix-hypr-remix/bin/ahr-launch-audio`
- `config/artix-hypr-remix/bin/ahr-launch-wifi`
- `config/artix-hypr-remix/bin/ahr-launch-bluetooth`
- `config/hypr/hyprland.conf`
- `config/waybar/config.jsonc`

Omarchy files to compare:

- `../omarchy/bin/omarchy-menu` Capture/Share/Toggle/Hardware sections
- `../omarchy/bin/omarchy-capture-*`
- `../omarchy/bin/omarchy-toggle-*`
- `../omarchy/default/waybar/indicators/`

Dependencies to verify:

- [ ] `grim`, `slurp`, optional `satty`
- [ ] `gpu-screen-recorder`
- [ ] `wl-clipboard`, `cliphist`
- [ ] `hyprpicker` for color picker if supported
- [ ] OCR dependency if selected later
- [ ] `pavucontrol`, `pamixer`, `wpctl` if adding audio output toggles
- [ ] `bluetoothctl`, `nmcli`, VPN tooling if adding network toggles
- [ ] `powerprofilesctl` if adding power profile toggle

Safe implementation tasks:

- [x] Add screenshot modes: region, fullscreen, active window.
- [x] Add optional "open after capture" behavior when `xdg-open` exists.
- [x] Add capture failure messages for missing compositor, selection cancellation, and unwritable output directory.
- [x] Add menu entries for color picker only if `hyprpicker` is installed — added to Capture menu with `menu_require hyprpicker hyprpicker` guard.
- [ ] Add recording modes only after validating audio source selection and webcam detection.
- [x] Add state files under `${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix`.
- [x] Keep Waybar indicators in sync with toggle state.

Risky/deferred tasks:

- [ ] OCR if it requires heavy dependencies or unclear language packs.
- [ ] LocalSend/share workflows until package/service assumptions are tested.
- [ ] Webcam toggle/recording without device detection and privacy messaging.
- [ ] VPN toggles without knowing the supported VPN stack.
- [ ] Display toggles that can blank the only monitor.

Validation steps:

- [ ] Press Print and verify the capture picker menu appears with Area/Fullscreen/Window choices; pick Area and confirm screenshot saved under Pictures.
- [ ] Press Print and pick Fullscreen; verify fullscreen screenshot is saved.
- [ ] Press Print and pick Window; verify active window screenshot is saved.
- [ ] Run `ahr-capture-screenshot --area --open` directly and verify area capture opens after saving.
- [ ] Validate each optional tool missing path by temporarily moving `grim`, `slurp`, `jq`, or `xdg-open` out of `PATH` in a test shell; confirm graceful failure messages.
- [ ] Start/stop screen recording and confirm Waybar indicator plus saved MP4.
- [ ] Copy text and image content, then open clipboard picker.
- [ ] Toggle idle and notifications twice; confirm status returns to original.

OpenRC/Artix notes:

- [ ] Network and Bluetooth toggles must use NetworkManager/BlueZ commands plus OpenRC service checks, not systemd service commands.

### 5.5 First-login and welcome experience

Desired user experience:

- [ ] After first login the user sees a working wallpaper/background, Waybar, Mako notifications, audio, network, Bluetooth state, portals, app launcher, browser, terminal, file manager, keybinding help, and a clear "what do I do next?" affordance.
- [ ] First-run helpers are idempotent and do not re-spam the user after successful completion.
- [ ] If a component is missing, the message names the next repair/check command.

Current files to inspect:

- `config/hypr/hyprland.conf`
- `config/artix-hypr-remix/bin/first-run.sh`
- `config/artix-hypr-remix/first-run.d/*.sh`
- `config/artix-hypr-remix/docs/quick-reference.md`
- `config/artix-hypr-remix/bin/ahr-menu`
- `config/artix-hypr-remix/bin/ahr-menu-keybindings`
- `config/artix-hypr-remix/bin/ahr-launch-wallpaper-session`
- `config/waybar/config.jsonc`
- `config/mako/config`

Omarchy files to compare:

- `../omarchy/install/first-run/welcome.sh`
- `../omarchy/default/hypr/`
- `../omarchy/bin/omarchy-menu`

Dependencies to verify:

- [ ] `notify-send`
- [ ] `waybar`, `mako`, `swaybg`
- [ ] `pipewire`, `wireplumber`, `pipewire-pulse`
- [ ] `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`
- [ ] `firefox`, `ghostty`, `nautilus`, configured fallbacks

Safe implementation tasks:

- [ ] Validate first visible state on a clean install without reading source docs.
- [x] Add first-login notification pointing to `Super+Space`, keybindings, and repair command.
- [x] Add first-login health tip pointing to `ahr status`, `ahr repair --dry-run`, and `ahr doctor`. (Full "one-command health summary" deferred — the initial implementation is a notification with command suggestions rather than a self-contained summary.)
- [x] Keep first-run scripts idempotent and individually logged.
- [ ] Add expected-result screenshots or text updates when UI changes.

Risky/deferred tasks:

- [ ] Interactive onboarding wizard.
- [ ] Account/app personalization flows.
- [ ] Network setup wizard beyond selected NetworkManager tooling.

Validation steps:

- [ ] Clean install, reboot, log in through TTY.
- [ ] Clean install, reboot, log in through `greetd` greeter.
- [ ] Optional `greetd` autologin validation.
- [ ] Confirm first-run does not repeat after second login.
- [ ] `ahr repair --dry-run`

OpenRC/Artix notes:

- [ ] Login/session fixes belong in TTY/greetd/OpenRC files, not UWSM/SDDM/systemd paths.

### 5.6 Healthcheck, repair, and upgrade UX

Desired user experience:

- [ ] User can run a healthcheck, understand failures, repair known framework issues, safely reapply configs, list backups, inspect install/update state, run migrations, and recover from interrupted updates.
- [ ] Checks cover services, packages, portals, dotfiles, theme state, default apps, menu dependencies, capture tools, and backup/restore guidance.

Current files to inspect:

- `scripts/doctor.sh`
- `scripts/post-install-smoke.sh`
- `scripts/check-config-deps.sh`
- `scripts/check-openrc-portability.sh`
- `scripts/smoke-framework.sh`
- `scripts/quality-gate.sh`
- `config/artix-hypr-remix/bin/ahr-repair`
- `config/artix-hypr-remix/bin/ahr-update`
- `config/artix-hypr-remix/bin/ahr-update-available`
- `config/artix-hypr-remix/bin/ahr-migrate`
- `config/artix-hypr-remix/bin/ahr-status`
- `config/artix-hypr-remix/bin/ahr-list-backups`
- `RECOVERY_AND_RESET.md`
- `MIGRATION_POLICY.md`

Omarchy files to compare:

- `../omarchy/bin/omarchy-update`
- `../omarchy/bin/omarchy-update-available`
- `../omarchy/bin/omarchy-refresh-*`
- `../omarchy/bin/omarchy-theme-update`

Dependencies to verify:

- [ ] `pacman`, optional AUR helper, optional `flatpak`
- [ ] `rc-service`, `rc-update`
- [ ] `hyprctl`, portals, PipeWire process checks
- [ ] `xdg-mime`, `xdg-settings`
- [ ] Menu/capture/theme tools

Safe implementation tasks:

- [x] Extend doctor with default-app MIME validation (browser, terminal, file-manager, editor, PDF, image, video, archive).
- [x] Extend doctor with menu backend and capture dependency checks.
- [ ] Extend repair with detect-only checks before apply paths.
- [ ] Ensure repair never overwrites user configs without backup or explicit `--apply`.
- [ ] Add health output that names likely files to inspect.
- [ ] Keep upgrade/migration hooks idempotent.

Risky/deferred tasks:

- [ ] Full uninstall command.
- [ ] Automatic rollback of package transactions.
- [ ] Refreshing all user configs from defaults without a guided diff/backup flow.

Validation steps:

- [ ] `./scripts/quality-gate.sh --no-aur`
- [ ] `AHR_HOST_POLICY=vm ./scripts/smoke-framework.sh --keep-sandbox`
- [ ] `./scripts/doctor.sh --no-aur`
- [ ] `ahr repair --dry-run`
- [ ] `ahr migrate --status`
- [ ] `ahr update --dry-run`
- [ ] `ahr status`
- [ ] `ahr list-backups`

OpenRC/Artix notes:

- [ ] Healthcheck/repair output should prefer OpenRC service names and commands.
- [ ] Keep `check-openrc-portability.sh` authoritative or update it when a guarded elogind exception is intentionally accepted.

## 6. Prioritization

### Public beta blockers

| Item | UX surface | Why it matters | Files likely involved | Dependencies | Validation command or manual test | Risk level |
| --- | --- | --- | --- | --- | --- | --- |
| Validate lock/idle after suspend/resume | First-login, power | Bad lock/suspend behavior breaks daily laptop use | `hypridle.conf`, `ahr-system-lock`, `ahr-system-suspend`, laptop OpenRC module | `hypridle`, `hyprlock`, elogind/pm-utils | Suspend/resume on laptop, then unlock and inspect logs | Medium |
| Portal screen sharing validation | Portals/share | Browser/Flatpak screen share is expected on modern desktops | `packages/10-hyprland.txt`, `config/hypr/xdph.conf`, smoke scripts | `xdg-desktop-portal*`, PipeWire | Share screen from browser or Flatpak app | Medium |
| Resolve OpenRC portability policy for guarded `loginctl` | Power/healthcheck | Portability check and runtime suspend helper must agree | `scripts/check-openrc-portability.sh`, `ahr-system-suspend`, laptop module | elogind `loginctl`, `pm-suspend` | `scripts/check-openrc-portability.sh`; suspend test | Medium |
| Clean-install menu smoke pass | Launcher/first-login | User must discover core actions without docs | `ahr-menu`, `hyprland.conf`, docs | menu backend | Fresh install, open every top-level menu | Low |
| Healthcheck covers UX-critical commands | Healthcheck | Users need actionable repair output | `scripts/doctor.sh`, `ahr-repair` | installed framework commands | `./scripts/doctor.sh --no-aur` | Low |

### High-impact polish

| Item | UX surface | Why it matters | Files likely involved | Dependencies | Validation command or manual test | Risk level |
| --- | --- | --- | --- | --- | --- | --- |
| Add dependency guards to menu scripts | Launcher/menus | Prevents confusing silent failures | `ahr-menu`, `ahr-lib.sh` | optional tools | Hide optional command in test shell and trigger action | Low |
| Add default editor and MIME validation | Default apps | Makes app behavior feel complete | `56-default-apps.sh`, new or updated default helper, doctor | `xdg-mime`, desktop entries | Open text/PDF/image/video/archive files | Low |
| Add screenshot fullscreen/window/open-after-capture | Capture | Very visible daily workflow | `ahr-capture-screenshot`, `ahr-menu` | `grim`, `slurp`, `hyprctl`, `xdg-open` | Capture region/window/fullscreen | Medium |
| Improve theme/background status and validation | Theme/gallery | Reduces broken-theme confusion | `ahr-theme-lib.sh`, `ahr-menu`, `ahr-repair` | `waybar`, `mako`, wallpaper backend | Switch themes, reboot, repair dry-run | Medium |
| Add first-login keybinding/help affordance polish | First-login/help | Reduces "what next?" friction | `110-welcome.sh`, `quick-reference.md`, Learn menu | `notify-send`, menu backend | Clean first login without docs | Low |

### Nice-to-have polish

| Item | UX surface | Why it matters | Files likely involved | Dependencies | Validation command or manual test | Risk level |
| --- | --- | --- | --- | --- | --- | --- |
| Color picker menu | Capture | Small, useful utility | `ahr-menu`, new helper if needed | `hyprpicker`, clipboard | Pick color and paste result | Low |
| Night light/gamma toggle | Toggles | Common comfort feature | toggle helper, Waybar status, menu | tool TBD | Toggle twice, confirm state | Medium |
| Waybar position/style toggle | Theme/Waybar | Omarchy-like customization | `waybar/config.jsonc`, templates, theme scripts | `waybar`, `jq` or structured edit tool | Change position and restore | Medium |
✅ Implemented 2026-06-07: `ahr-toggle-waybar-position` toggles position between top/bottom in `config.jsonc` via `sed`, restarts Waybar. `ahr-waybar-position-status` provides Waybar indicator with / icons. Added to Toggle and Style menus, registered in `ahr` dispatcher, indicator in Waybar modules-center with signal 13. |
| Theme/gallery preview | Theme/gallery | Higher perceived polish | theme menu/helpers | preview assets, image-capable picker | Select theme/background from preview | Medium |
| Share workflow | Capture/share | Useful for screenshots/files | menu/helpers | LocalSend or selected share tool | Share clipboard/file/folder | Medium |

### Deferred / risky

| Item | UX surface | Why it matters | Files likely involved | Dependencies | Validation command or manual test | Risk level |
| --- | --- | --- | --- | --- | --- | --- |
| Web app installer parity | Install/apps | Omarchy feature, but broad scope | install helpers, desktop entry code | browser, favicon fetch, network | Install/remove test web app | High |
| Broad gaming/AI/dev installers | Install/remove | Large user-visible feature set | `ahr-menu`, package helpers | many Artix/AUR packages | VM/package availability matrix | High |
| Passwordless sudo/direct boot toggles | System/security | Privileged and potentially unsafe | menu/helpers, sudoers/startup files | sudo, greetd/TTY config | Manual recovery test | High |
| Display/hardware toggles | Hardware | Can break active session | Hyprland monitor config/helpers | device-specific tools | Test on target hardware with fallback | High |
| Full uninstall/reset command | Recovery | Easy to damage user data | repair/reset tooling | package manager, backups | VM uninstall/restore drill | High |

## 7. Implementation rules for future Codex sessions

- [ ] Implement one UX surface at a time.
- [ ] Prefer small patches that can be reviewed independently.
- [ ] Inspect current behavior before changing files.
- [ ] Compare with Omarchy, then adapt for Artix/OpenRC.
- [ ] Add dependency checks before calling tools.
- [ ] Add graceful failure messages that name missing commands and likely install paths.
- [ ] Add backups before overwriting configs or rendered templates.
- [ ] Keep scripts idempotent.
- [ ] Update this checklist after each implementation pass.
- [ ] Document changed files and validation results in the relevant section.
- [ ] Stop and document risky changes instead of forcing them.
- [ ] Avoid broad rewrites of `ahr-menu`, installer phases, or theme internals unless a narrow change cannot solve the UX gap.
- [ ] Do not port Omarchy commands that assume systemd/UWSM/SDDM/Plymouth/Limine.
- [ ] Add or update smoke/doctor checks when adding user-facing commands.
- [ ] Keep unsupported features explicit in docs and menu text.

## 8. Validation matrix

| Validation item | Command/manual action | Expected result | Failure symptoms | Likely files to inspect |
| --- | --- | --- | --- | --- |
| Fresh install | `./install.sh` on supported Artix OpenRC host | Phases complete, summary lists log/backups/next command | Preflight failure, package failure, config deployment failure | `install.sh`, `lib/checks.sh`, `lib/pacman.sh`, install log |
| Re-run installer | `./install.sh --phase 4 --user <username> -y` or documented phase retry | Existing configs backed up, phase reruns safely | Missing backups, overwritten user config, stale state | `lib/dotfiles.sh`, `lib/state.sh`, install log |
| Login to Hyprland | Reboot and log in through TTY or `greetd` | Hyprland starts with Waybar/Mako/wallpaper | Black screen, no session, missing env | `start-hyprland-session.sh`, `lib/tty.sh`, `hyprland.conf` |
| Launch menu | Press `Super+Space`; run `ahr-menu` | Main menu opens and top-level actions are visible | No picker, command not found, blank menu | `ahr-menu`, `ahr-launch-apps`, `config/walker/config.toml` |
| Switch theme | `ahr theme set artix-dark`; menu Style > Theme Set | Theme state updates and UI reloads | Missing theme, stale Waybar/Mako, broken background | `ahr-theme-lib.sh`, `default/themes/*`, `default/themed/*` |
| Switch wallpaper | `ahr theme bg-next`; menu background action | Background changes and persists | Symlink missing, unreadable image, wallpaper backend absent | `ahr-theme-bg-next`, `ahr-launch-wallpaper-session` |
| Take screenshot | Press Print for mode picker (area/fullscreen/window) or run `ahr-capture-screenshot` with `--area`/`--fullscreen`/`--window` | PNG saved in Pictures and notification appears | Selection fails, no file, missing `grim`/`slurp`/`jq` | `ahr-capture-picker`, `ahr-capture-screenshot`, `packages/10-hyprland.txt` |
| Use clipboard history | Copy text/image, run `ahr-clipboard-picker` | Recent clipboard item can be selected | Empty picker, missing watchers | `hyprland.conf`, `ahr-clipboard-picker`, `cliphist` package |
| Lock and unlock | `ahr-system-lock` or keybinding | Hyprlock appears and unlocks | Lock fails, wrong auth, blank lock screen | `ahr-system-lock`, `hyprlock.conf` |
| Idle behavior | Wait for idle timeout; toggle idle twice | Lock/DPMS behavior works and state restores | Never locks, cannot resume, stale Waybar state | `hypridle.conf`, `ahr-toggle-idle`, Waybar idle helper |
| Audio works | Play audio, adjust volume, open audio control | PipeWire output works; Waybar audio responds | No audio devices, mixer missing | `packages/50-audio.txt`, Hyprland autostart, `ahr-launch-audio` |
| Network works | Connect/disconnect through selected network UI | NetworkManager connection works | No applet/UI, service not running | `packages/60-network-openrc.txt`, `services/openrc-default.txt`, `ahr-launch-wifi` |
| Bluetooth works if hardware exists | Open Bluetooth menu/control | Devices can pair/connect or no-controller state is clear | Service missing, UI missing, no adapter handling | `packages/60-network-openrc.txt`, OpenRC service checks, `ahr-launch-bluetooth` |
| Screen sharing portal works | Share screen from browser/Flatpak app | Portal picker appears and stream works | No picker, black stream, PipeWire/portal errors | `packages/10-hyprland.txt`, `config/hypr/xdph.conf`, smoke scripts |
| Default browser opens links | `xdg-open https://example.com` | Supported browser opens | Wrong app, no app, xdg failure | `ahr-default-browser`, `56-default-apps.sh` |
| File manager opens directories | `xdg-open "$HOME"` | File manager opens directory | Wrong app, no handler | `56-default-apps.sh`, `ahr-launch-files` |
| Power menu actions work | Menu System > lock/logout/suspend/reboot with confirmations | Action executes or explains unsupported state | Wrong command, systemd call, no confirmation | `ahr-menu`, `ahr-system-*`, OpenRC portability check |
| Healthcheck passes | `./scripts/doctor.sh --no-aur` | Required commands/services/configs pass or warn clearly | Missing commands, false positives, unclear output | `scripts/doctor.sh`, `scripts/check-config-deps.sh` |
| Repair/reapply does not destroy user changes | `ahr repair --dry-run`; review before `--apply` | Detect-only by default, backups before changes | Silent overwrite, missing backup, vague repair | `ahr-repair`, `RECOVERY_AND_RESET.md`, backup helpers |

## 9. Definition of done

Beta polish is complete when:

- [ ] Safe repeatable install works on supported Artix OpenRC hosts.
- [ ] First login is polished: wallpaper/background, Waybar, notifications, audio, network, portals, launcher, and help affordance all work.
- [ ] Rich menus cover common desktop actions without requiring source-code knowledge.
- [ ] Theme and wallpaper gallery/state workflows work, persist, and can be repaired.
- [ ] Capture/share/toggle flows are discoverable; unsupported flows are documented.
- [ ] Default apps are configured for browser, terminal, file manager, editor, and common MIME types.
- [ ] OpenRC services are validated; no systemd-only assumptions are present in runtime paths.
- [ ] Documentation explains the supported base system, startup modes, optional profiles, repair paths, and unsupported features.
- [ ] Healthcheck and repair paths exist for common beta failures.
- [ ] Known unsupported features are documented instead of hidden in broken menus.

## 10. Immediate next-session starter tasks

- [x] Add or improve beta healthcheck coverage for menu dependencies, default apps, and capture tools.
- [x] Add dependency guards and clearer failure messages to `ahr-menu` actions.
- [x] Add default editor validation/setup and broaden safe `xdg-mime` defaults.
- [x] Add screenshot/capture menu polish for fullscreen/window/open-after-capture behavior.
- [x] Improve theme/wallpaper state reporting and validation after switching.
- [x] Add or refine first-login keybinding/help menu entry based on a clean-install usability pass.
- [x] Add more Omarchy parity table entries from direct inspection of `omarchy-capture-*`, `omarchy-toggle-*`, `omarchy-theme-*`, and `the-omarchy-manual.md`.
- [x] Implement nightlight toggle: create `ahr-toggle-nightlight` using `hyprsunset` (4000K/6500K), add to Toggle menu and Waybar indicator, register in dispatcher.

TODO markers for future inspection/testing:

- [ ] TODO: Confirm exact Omarchy commit currently used for parity after each reference update.
- [ ] TODO: `ahr-theme status` includes swayosd.css and vscode.json in missing-optional-assets output — confirm this is correct for AHR scope.
- [ ] TODO: Add `ahr theme status` to doctor.sh's check_theme_state once the command is installed in a real user config.
- [ ] TODO: Validate optional AUR package availability on a real Artix host with an AUR helper.
- [ ] TODO: Decide whether guarded elogind `loginctl` is accepted for suspend or replaced with a pure OpenRC/pm-utils path.
- [ ] TODO: Capture final first-login screenshots once the UI polish pass is complete.

### Session 2026-06-07 (third pass): Clean-install menu smoke pass

**What was done:**

- Performed a structured menu smoke pass: syntax-checked `ahr-menu`, verified all 24 shell functions are defined, confirmed all 27 referenced bin scripts exist and are executable.
- Added **Clipboard History** entry to the Capture menu — runs `ahr-clipboard-picker` with `cliphist` guard and TTY fallback (already present in the picker script).
- Added **Color Picker** entry to the Capture menu — runs `hyprpicker -az` (auto-copy to clipboard via `-a`, no zoom via `-z`) with `menu_require hyprpicker hyprpicker` guard and `wl-copy` requirement. Not added to package lists since it's an optional AUR/community tool.
- Ran `AHR_MENU_BACKEND=tty` smoke test on all menu slices (help, learn, trigger, style, setup, install, remove, update, system). All dispatch correctly.
- Menu is fully functional without Hyprland or graphical backends for the subset of actions that support TTY fallback (menu navigation, clipboard picker TTY mode).

**Files changed:** `ahr-menu` (Capture menu options + cases for Clipboard History and Color Picker)

### Session 2026-06-07: Add dependency guards and clearer failure messages to `ahr-menu` actions

**What was done (initial pass):**

- Added `ahr_require()` to `ahr-lib.sh` — a standardized helper that checks for a command on PATH and prints an install hint (`sudo pacman -S <package>`) if missing. Returns 1 so callers can decide how to respond (menu pre-check, fallback, etc.).
- Added `menu_require()` to `ahr-menu` — wraps `ahr_require` with a notification + stderr message and returns to the menu instead of exiting.
- Updated all capture/toggle/launch/system commands to use `ahr_require` for friendlier failure messages with explicit package install hints instead of bare `ahr_fail` messages.
- Added pre-check guards in `ahr-menu` sub-menus:
  - **Capture menu**: checks `grim`+`slurp` / `grim` / `grim`+`jq` before screenshot commands, `gpu-screen-recorder` before recording
  - **Toggle menu**: checks `hypridle` before "Idle Lock"
  - **Setup menu**: checks for audio/network/bluetooth control apps before offering their menu entries
  - **System menu**: checks for `hyprlock`/`swaylock` before "Lock Screen", `grim`+`slurp` before "Capture Screenshot", `gpu-screen-recorder` before recording; in-menu message for `hyprctl`-unavailable logout
- Added `require_capture_dep` helper in `ahr-capture-screenshot` that sends a notification on missing deps (covers the case where stderr is discarded by `nohup >/dev/null 2>&1`).
- Added grim pre-flight check to `ahr-capture-picker` (PrtSc key handler).

**Post-review fixes (same session):**

- `menu_require` was calling `run_terminal_script` which `exit 0`s on success, killing the menu. Changed to direct stderr `printf` + notification + `return 1` — no terminal spawning.
- `ahr-toggle-waybar` and `ahr-capture-screenrecording` had bare `ahr_require` calls under `set -e`, making subsequent `ahr_notify`+`exit 1` lines unreachable. Wrapped in `if ! ahr_require ...; then ahr_notify ...; exit 1; fi`.
- Screenshot dependencies in `show_system_menu`'s inline "Capture Screenshot" and "Toggle Screen Recording" had no pre-check guards. Added `menu_require` calls.
- Screenshot background actions in `show_capture_menu` (Area/Fullscreen/Window) also lacked pre-check guards — added `menu_require` for `grim`/`slurp`/`jq`.

**Files changed:** `ahr-lib.sh`, `ahr-menu`, `ahr-capture-screenshot`, `ahr-capture-screenrecording`, `ahr-capture-picker`, `ahr-toggle-idle`, `ahr-toggle-waybar`, `ahr-launch-audio`, `ahr-launch-wifi`, `ahr-launch-bluetooth`, `ahr-clipboard-picker`, `ahr-system-lock`, `ahr-system-suspend`, `ahr-system-hibernate`, `ahr-system-reboot`

### Session 2026-06-07 (second pass): First-login and help affordance polish

**What was done (initial pass):**

- Expanded `110-welcome.sh` first-login notification with more keybindings (Super+P clipboard, Print screenshot), a pointer to the Learn menu, and a 12-second-delayed health-tip notification pointing to `ahr status`, `ahr repair --dry-run`, and `scripts/doctor.sh --no-aur`.
- Added `show_getting_started()` function to `ahr-menu` — a curated terminal guide showing essential keybindings, menu structure, key CLI commands, and where to get further help.
- Added "Getting Started" as the first entry in the Learn menu (before Keybindings) for immediate discoverability.
- Added a "Health & Repair" section to `quick-reference.md` covering `ahr status`, `ahr repair --dry-run`, `doctor.sh`, and config backup listing.

**Files changed (initial):** `first-run.d/110-welcome.sh`, `ahr-menu`, `docs/quick-reference.md`

**Post-review fixes (same session):**

1. **`ahr-status` local-bind error (finding 1a):** `local theme_globs=(...)` at line 120 was outside any function, causing `local: can only be used in a function` at runtime. Removed `local` — the variable is only used once within the same block.
2. **Unused capture in `110-welcome.sh` (finding 1b):** `ahr_status="$(ahr status --quiet 2>/dev/null || true)"` captured output but never used it. Removed the line entirely.
3. **Race condition in health-tip guard (finding 3):** The `HEALTH_NOTIFIED` guard file was touched *after* the 12-second sleep inside the background subshell, so two invocations within 12s could both schedule the tip. Fixed by switching to `$XDG_RUNTIME_DIR` (session-scoped, tmpfs) and creating/touching the guard *before* spawning the background subshell.
4. **Doctor refs broken post-install (finding 2):** The notification, Getting Started guide, and quick-reference all referenced `scripts/doctor.sh --no-aur`, which doesn't exist in the deployed `~/.config/artix-hypr-remix` tree. Created `bin/ahr-doctor` — a lightweight installed-framework health check covering required commands, desktop runtime, OpenRC services, capture tools, menu backends, MIME defaults, theme state, and framework command deployment. Registered as `ahr doctor` in the dispatcher. Updated all three reference points to use `ahr doctor`.
5. **Checklist overstatement (finding 4):** The health-summary completion claim was downgraded from "one-command health summary" to "health tip with command suggestions" to accurately reflect the implementation.

**Files changed (fixes):** `ahr-status`, `ahr-doctor` (new), `ahr`, `first-run.d/110-welcome.sh`, `ahr-menu`, `docs/quick-reference.md`, `BETA_POLISH_CHECKLIST.md`

### Session 2026-06-07 (fourth pass): Omarchy parity table expansion from direct inspection

**What was done:**

- Inspected all Omarchy capture/toggle/theme bin scripts (`omarchy-capture-*`, `omarchy-toggle-*`, `omarchy-theme-*`) and the downloaded Omarchy manual (`the-omarchy-manual.md`) for parity gaps.
- Added **10 new rows** to the section 4 parity audit table documenting missing AHR features:
  - **Capture**: OCR/text extraction — Missing / Optional polish
  - **Clipboard**: unified hotkeys (Super+C/V/X) — Missing / Optional polish
  - **Screensaver/suspend availability toggles** — Missing / Optional polish
  - **Theme**: install/remove/update via git — Missing / Required for stable
  - **Theme**: browser/editor/foot sync — Missing / Optional polish
  - **Nightlight toggle** (hyprsunset) — Missing / Optional polish
  - **Notices** (date/time/battery/weather) — Missing / Optional polish
  - **Reminders** — Missing / Optional polish
  - **Toggle state framework** — Missing / Optional polish
  - **Touchpad toggle** — Missing / Optional polish
  - **Touchscreen toggle** — Missing / Unsupported for now
- Added **8 new entries** to the section 4.1 manual-derived backlog for broader feature gaps.
- Marked the Omarchy parity inspection starter task as complete.
- Added a new starter task: implement nightlight toggle (`ahr-toggle-nightlight` via `hyprsunset`).

**Files changed:** `BETA_POLISH_CHECKLIST.md`

### Session 2026-06-07 (fifth pass): Implement nightlight toggle

**What was done:**

- Created `ahr-toggle-nightlight` — toggles `hyprsunset` between 4000K (night) and 6500K (day). Starts `hyprsunset` if not running. Uses state file under `$XDG_STATE_HOME/artix-hypr-remix/toggles/nightlight` for Waybar indicator. Sends signal 12 to Waybar on state change.
- Created `ahr-waybar-nightlight-status` — outputs Waybar JSON with  (active) or  (inactive) icon with tooltip, respecting both state file and `hyprctl hyprsunset temperature` live query.
- Added **Nightlight** entry to the Toggle menu in `ahr-menu` (menu_select list + case dispatch).
- Added `custom/nightlight-indicator` to `config/waybar/config.jsonc` — placed in modules-center, signal 12, 30-second interval.
- Registered `toggle-nightlight` in the `ahr` dispatcher (usage text, case dispatch, list command).
- Added keybinding `$mod CTRL, n` → `ahr-toggle-nightlight` in `hyprland.conf` (matches Omarchy's Super+Ctrl+N).

**Files changed:** `ahr-toggle-nightlight` (new), `ahr-waybar-nightlight-status` (new), `ahr-menu`, `ahr`, `config/waybar/config.jsonc`, `config/hypr/hyprland.conf`, `BETA_POLISH_CHECKLIST.md`

**Post-review fixes (same session):**

1. **RTMIN signal mismatch (finding P2):** Script sent `-RTMIN+11` but Waybar expected signal 12. Changed to `-RTMIN+12`.
2. **Missing package dependency (finding P2):** `hyprsunset` was absent from `packages/10-hyprland.txt`. Added it.
3. **Missing CSS selectors (finding P3):** `#custom-nightlight-indicator` was not in `style.css` or `waybar.css.tpl` selector groups. Added to base layout, left/right variants, and active state groups.
4. **Stale state file on reboot (finding P2):** Status script trusted state file before live `hyprctl` query. Reordered to check `pgrep -x hyprsunset` first, then live temperature, then state file as fallback.
5. **Alert color mismatch (open question):** Nightlight active was grouped with red alerts. Moved to its own warm peach accent (`#f5a97f`).
6. **Extra brace in template (finding P2):** `waybar.css.tpl` had a dangling `}` after the nightlight rule. Removed.

**Validated on Artix laptop (2026-06-07):**
- `ahr toggle-nightlight` → notification + Waybar  icon appears
- `Super+Ctrl+N` keybinding works
- Toggle menu entry works
- Toggling again switches back to 
- `pkill hyprsunset` + wait → Waybar indicator shows inactive (state file no longer trusted over live state)

### Session 2026-06-07 (sixth pass): Waybar position/style toggle

**What was done:**

- Created `ahr-toggle-waybar-position` — toggles `position` in `~/.config/waybar/config.jsonc` between `"top"` and `"bottom"` via `sed`, writes state file under `$XDG_STATE_HOME/artix-hypr-remix/toggles/waybar-position`, restarts Waybar, sends notification.
- Created `ahr-waybar-position-status` — outputs Waybar JSON with  (top) or  (bottom) icon and tooltip. Prefers live config state over state file for accuracy.
- Added `custom/waybar-position-indicator` to `config/waybar/config.jsonc` — placed in modules-center after nightlight indicator, signal 13, 30-second interval.
- Added **Waybar Position** entry to both the **Toggle menu** (between Nightlight and Back) and the **Style menu** (between Toggle Waybar and Restart Waybar) in `ahr-menu`.
- Registered `toggle-waybar-position` in the `ahr` dispatcher (usage text, case dispatch, list command).

**Files changed:** `ahr-toggle-waybar-position` (new), `ahr-waybar-position-status` (new), `ahr-menu`, `ahr`, `config/waybar/config.jsonc`, `BETA_POLISH_CHECKLIST.md`

**Post-review fixes (same session, five findings resolved):**

1. **P1: `namespace-install.sh` missing command.** Added `ahr-toggle-waybar-position` to the `commands` array in `namespace-install.sh` so the deployed `~/.local/bin/ahr` dispatcher can find it.
2. **P2: Stale state could override live config in status helper.** Fixed `ahr-waybar-position-status` to detect *both* `"top"` and `"bottom"` from the live config first, and only fall back to the state file when the config is missing or has no recognizable position.
3. **P3: Existing installs need a migration.** Created `migrations/20260607-waybar-position-indicator.sh` — backs up `~/.config/waybar/config.jsonc`, adds `custom/waybar-position-indicator` to `modules-center` and inserts the indicator block after the nightlight-indicator block, then re-runs `namespace-install.sh --quiet`.
4. **P4 (second review): Migration sed block insertion was a no-op.** Replaced the complex sed loop with a two-step approach: find the nightlight-indicator block's closing line via `sed -n` with a range + `=` line-number output, then use `sed -i` with the `r` (read file) command and a temp file to insert the new block cleanly. Added a `grep` post-check that fails+restores from backup if the block is still absent.
5. **P5 (second review): Idempotency check skipped namespace reinstall.** Changed the early `exit 0` on config-already-patched to a `patched` boolean flag. The namespace installer always runs at the end, so a half-applied migration gets its missing `~/.local/bin/ahr-toggle-waybar-position` symlink even when the config is already up to date.
6. **P6 (third review): Only block insertion was verified, not module-center registration.** The post-check verified the block definition existed but not whether `modules-center` included the new module. If the single-line sed for the array failed (e.g., multi-line or reordered config), the migration would still report success. Fixed: the `modules-center` sed was changed from targeting a specific last-element pattern to finding the array's closing `]` directly (works for single-line and multi-line arrays). The post-check now verifies **both** that the block exists and that the module name appears in the `modules-center` array; if either is missing, the backup is restored and the migration exits 1.
7. **P7 (third review): Migration hard-failed if nightlight-indicator block was absent.** Older installs that never received the nightlight config update would fail the migration entirely. Fixed: the insertion anchor now tries `custom/nightlight-indicator` first, then falls back to `custom/notification-silencing-indicator`. If neither anchor is found, the migration skips config patching gracefully (still refreshes namespace).
8. **P8 (fourth review): Unescaped `/` in sed address crashed with `set -e` before backup restore.** The anchor variable interpolated into a sed `/pattern/` address without escaping the `/` in `custom/nightlight-indicator`. Fixed: `${anchor//\//\\/}` escapes `/` → `\/` before building the sed expression. The anchor-finding sed now also has `|| true` to prevent `set -e` from aborting before the graceful skip path.
9. **P9 (fourth review): `modules-center` extraction regex did not match space after `:`.** `grep -o '"modules-center":\[...\]'` missed `"modules-center": [...]` (space after colon) and multiline arrays. Fixed: switched to `sed -n '/"modules-center"[[:space:]]*:[[:space:]]*\[/,/\]/p'` which handles any whitespace and multiline layouts.
10. **P10 (fourth review): Idempotency check was too loose.** `grep -q 'custom/waybar-position-indicator'` matched any occurrence (e.g., the block definition alone without the array entry). Fixed: pre-check now verifies **both** the `modules-center` array includes the module name **and** the block definition exists before declaring "already fully patched". Attempted patches are tracked with `tried_array`/`tried_block` booleans so verification only checks what was actually changed.
11. **P11 (fifth review): Multiline with trailing comma produced duplicate `]` insertion.** The single `s/\]/.../` substitution ran even after the multiline-with-comma `s/,[[:space:]]*\n[[:space:]]*\]/.../` had already matched, producing two copies of the new module. Fixed: added `t` (test/branch on success) after the multiline substitution so the fallback `s/\]/.../` is skipped when the multiline pattern already matched. Verified on single-line, multiline-no-comma, and multiline-with-comma.
12. **P12 (fifth review): "No anchor" path left partial config and claimed patched.** When neither anchor block was found, the array entry was kept but no block definition was inserted, and `patched=true` was still set. Fixed: the no-anchor branch now restores the backup, resets `tried_array`/`tried_block`, and skips setting `patched=true`. The namespace installer still runs, and the migration exits cleanly with "config not modified".
13. **P13 (sixth review): Block insertion assumed anchor closing brace always has trailing comma.** If the anchor block's closing `}` was bare (no `,`), the inserted new block would create invalid JSON (`}` immediately followed by a new property with no separator). Fixed: before inserting, `sed -i "${insert_after}s/}[[:space:]]*$/},/"` ensures the anchor closing line ends with `},`. When it already has a comma (normal case), the substitution is a no-op. Verified on both `}` and `},` inputs.
14. **P14 (seventh review): Trailing comma on last block before root `}`.** The inserted block always ended with `},`. If the anchor was the last top-level block, the result was a trailing comma before the root `}`, which `jq` rejects. Fixed: the block file now ends with `}` (no comma). After insertion, the migration checks if the line after the new block is the root closing `}` — if not (another block follows), a trailing comma is added to the new block's closing line. Both cases confirmed valid with `jq`.

**Validation plan (run on target):**
- `ahr toggle-waybar-position` → notification + Waybar  icon appears, bar moves to bottom
- Toggle menu entry works
- Style menu entry works
- Toggling again switches back to top
- Indicator updates within 30s or on signal 13
- `ahr migrate --dry-run` shows the new migration pending; `ahr migrate` applies it
- `ahr toggle-waybar-position` works after migration completes
