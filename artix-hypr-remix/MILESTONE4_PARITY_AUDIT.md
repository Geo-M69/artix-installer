# Milestone 4 Parity Audit

This document tracks the Workstream A feature-by-feature comparison between Omarchy and Artix Hypr Remix.

## Reference

- Omarchy checkout: `../omarchy`
- Omarchy commit: `8075b8b0dcd870ae3853bee99259bb41e8759c3f`
- Omarchy describe: `v3.4.2-720-g8075b8b0`
- Omarchy worktree status at audit start: clean
- Audit date: 2026-06-04

Reference files used in the initial pass:

- `../omarchy/bin/omarchy-menu`
- `../omarchy/bin/omarchy-menu-keybindings`
- `../omarchy/default/hypr/bindings/utilities.lua`
- `../omarchy/default/hypr/bindings/clipboard.lua`
- `../omarchy/config/hypr/bindings.lua`
- `../omarchy/install/first-run/welcome.sh`
- `../omarchy/bin/omarchy-update`
- `../omarchy/bin/omarchy-update-available`
- `../omarchy/bin/omarchy-webapp-install`
- `config/artix-hypr-remix/bin/ahr-menu`
- `config/hypr/hyprland.conf`
- `config/artix-hypr-remix/first-run.d/110-welcome.sh`
- `COMMAND_NAMESPACE.md`

## Classification Legend

- Required parity: expected for an Omarchy-equivalent daily desktop experience.
- Artix/OpenRC adaptation: same user outcome, different implementation because Artix does not use systemd.
- Optional polish: useful UX, not beta-blocking.
- Intentional difference: deliberate AHR scope or taste choice.
- Unsupported for now: explicitly deferred.
- Unknown: needs more source audit or user testing.

## Top-Level Parity Table

| Area | Classification | Omarchy Reference | AHR Status | Gap | Milestone 4 Action |
| --- | --- | --- | --- | --- | --- |
| Main menu structure | Required parity | `omarchy-menu` top menu: Apps, Learn, Trigger, Style, Setup, Install, Remove, Update, About, System | Partial | AHR now has Applications, Learn, Trigger, Style, Setup, Install, Remove, Update, System; About remains absent | Decide whether About belongs in beta and keep menu taxonomy coherent. |
| Learn menu | Required parity | Learn exposes keybindings, tmux keybindings, Omarchy manual, Hyprland, Arch, Neovim, Bash | Partial | AHR now has Learn with keybindings, command help, and an installed quick reference | Decide which external references belong in beta. |
| Keybinding viewer | Required parity | `omarchy-menu-keybindings` dynamically reads active Hyprland bindings and provides searchable Walker UI | Present | AHR has a config-derived searchable/plain keybinding viewer | Keep labels validated as bindings evolve. |
| Trigger menu | Required parity | Reminder, Capture, Transcode, Share, Toggle, Hardware | Partial | AHR now has Trigger with Capture and Toggle; reminders/transcode/share/hardware remain absent or scoped down | Decide which missing Trigger workflows are beta-worthy. |
| Capture workflow | Required parity | Screenshot, screenrecording with audio/webcam modes, OCR, color picker | Partial | AHR has screenshot and screenrecord toggle; no OCR/color picker/audio/webcam menu path | Add capture submenu; defer OCR/webcam if needed. |
| Reminder workflow | Optional polish | Set/show/clear reminders from menu and keybindings | Absent | No AHR reminder command | Defer or implement lightweight timer notifications. |
| Transcode workflow | Optional polish | Menu/CLI transcode plus file-manager integration | Absent | No AHR transcode command or file-manager hook | Mark optional unless beta scope expands. |
| Share workflow | Optional polish | LocalSend clipboard/file/folder/receive menu | Absent | No AHR share menu | Optional; document unsupported if deferred. |
| Toggle workflow | Required parity | Screensaver, nightlight, idle lock, notifications, top bar, layout, gaps, monitor scaling, direct boot, passwordless sudo | Partial | AHR has idle and notification toggles; lacks top bar, nightlight, gaps/layout persistence, direct boot, passwordless sudo UX | Add safe toggles where OpenRC-compatible; defer risky privilege toggles. |
| Hardware menu | Artix/OpenRC adaptation | Laptop display, mirror display, hybrid GPU, touchpad, touchscreen, haptics | Partial | AHR has hardware profiles and startup validation, not an interactive hardware menu | Add only hardware actions validated on Artix; document unsupported hardware toggles. |
| Style menu | Required parity | Theme, unlock, font, background, Waybar, corners, Hyprland, screensaver, about | Partial | AHR now has Style with theme status/set/refresh/background/Waybar/Mako actions; no font, unlock, corners, screensaver/about branding UX | Keep richer branding as optional polish unless beta testing proves it blocks orientation. |
| Theme switcher | Required parity | Visual theme/background switchers, theme install/update/remove, live reload across apps | Partial | AHR has CLI/menu theme status/set/refresh/bg-next/bg-set and installed asset docs; rich previews/install/update/remove are deferred | Validate state persistence; keep gallery/previews as post-beta polish. |
| Defaults setup | Required parity | Browser, terminal, editor defaults | Partial | AHR supports browser and terminal; no default editor helper | Add `ahr-default-editor` or document intentional omission. |
| Setup config editing | Required parity | Menu opens Hyprland, Hypridle, Hyprlock, Hyprsunset, SwayOSD, Walker, Waybar, XCompose configs | Partial | AHR setup menu does not expose config editing paths comprehensively | Add Config submenu with editor fallback. |
| Install menu breadth | Optional polish | Package, AUR, Web App, TUI, Service, Style, Development, Editor, Terminal, Browser, AI, Gaming, Windows | Partial | AHR has Docker/printing/browser-ish pieces but much narrower install UX | Keep beta scope narrow; add Browser/Terminal/Editor only if package paths are Artix-safe. |
| Web app workflow | Unsupported for now | `omarchy-webapp-install` creates desktop launchers with icons/favicons | Mostly absent | AHR has no web app installer | Keep unsupported for now unless user requests it for beta. |
| Browser install/default flow | Required parity | Install Browser plus Setup Default Browser | Partial | AHR can set browser defaults; install flow is not equivalent | Add Artix-safe browser install menu or document package assumptions. |
| Terminal install/default flow | Required parity | Install Terminal plus Setup Default Terminal | Partial | AHR can set terminal defaults; install flow is not equivalent | Add Artix-safe terminal install menu or document package assumptions. |
| Editor install/default flow | Optional polish | Install Editor plus Setup Default Editor | Absent | No AHR default-editor command | Decide whether editor default belongs in beta. |
| Remove menu breadth | Optional polish | Package, Web App, TUI, Development, Theme, Browser, Dictation, Gaming, Windows, Preinstalls, Security | Partial | AHR remove menu is much narrower | Keep destructive removals conservative; do not copy broad removal without tests. |
| Update menu | Required parity | Omarchy update, channel, config refresh, extra themes, process restart, hardware restart, firmware, password, timezone, time | Partial | AHR update menu has full/update+flatpak/migrations/check with clearer scope prompts; channel/firmware/password remain out of scope | Add process restart/config refresh actions only when they map safely to AHR; keep channel/firmware/password scoped out. |
| Update command UX | Required parity | `omarchy-update` logs through PTY, confirms, snapshots, updates git/system/packages | Partial | AHR update has clearer availability output, JSON counters, menu prompts, locks, and logs; it does not yet provide guided repair for interrupted updates | Carry interrupted-update and skipped-migration repair UX into Milestone 5. |
| System menu | Required parity | Screensaver, lock, suspend, hibernate, logout, restart, shutdown | Partial | AHR has lock/reboot/app launcher/capture actions; shutdown/logout/suspend are incomplete | Add OpenRC-safe logout/shutdown/suspend handling if reliable. |
| First-run welcome | Required parity | Notification highlights Super+K, Super+Space, Super+Alt+Space | Present | AHR welcome now highlights menu, keybinding help, and terminal | Keep in sync with first-login UX changes. |
| Command aliases | Artix/OpenRC adaptation | Many `omarchy-*` commands expected by bindings/menu | Partial | AHR has an expanded safe compatibility alias layer, but does not alias commands without native behavior | Keep omissions explicit; add aliases only after native AHR commands exist. |
| User menu extensions | Optional polish | Sources `~/.config/omarchy/extensions/menu.sh` | Absent | AHR has no menu extension hook | Consider `~/.config/artix-hypr-remix/extensions/menu.sh` later. |
| Waybar weather | Optional polish | Weather status and notification support | Partial | AHR has Waybar weather status helper; no notification/menu trigger parity | Add Trigger > Weather only if useful. |
| Voice/dictation | Optional polish | Voxtype install/config/status/remove | Partial | AHR has optional Voxtype config/model/status pieces, no install/remove parity | Keep optional and non-blocking. |
| Systemd/UWSM/SDDM paths | Artix/OpenRC adaptation | Omarchy depends on systemd/UWSM/SDDM for many paths | Intentional difference | AHR uses OpenRC, TTY, and greetd | Document adaptations; do not port systemd-only behavior directly. |

## Workstream A Findings

- The largest Milestone 4 gap is not core desktop functionality; it is information architecture. AHR has the right pieces, but Omarchy presents them through clearer Learn, Trigger, Style, Setup, Update, and System routes.
- Keybinding discoverability was a beta-relevant gap; AHR now has `ahr-menu-keybindings` and an Omarchy-compatible alias.
- AHR should not blindly port Omarchy's broad Install/Remove menus. Many entries imply Arch/AUR/systemd assumptions or large product-scope choices.
- A2 command namespace coverage now exposes additional safe Omarchy-compatible aliases for top-level `omarchy`, app launcher, Bluetooth, Waybar toggle/restart, Mako restart, and notification dismiss.
- Remaining Omarchy command aliases are intentionally omitted when they would imply unsupported features such as web apps, reminders, transcoding, broad package installers, systemd power/session flows, SDDM/Plymouth/Limine refreshes, or hardware-specific toggles.
- Keybinding help, initial Learn menu support, and installed quick reference are implemented; next UX work should continue Trigger/Style taxonomy.
- Richer Omarchy features such as web apps, reminders, transcoding, LocalSend share, OCR, screensaver branding, and Windows/gaming install flows should be optional or unsupported unless explicitly pulled into beta scope.

## Recommended Workstream A Closure Criteria

- [x] Add `MILESTONE4_PARITY_AUDIT.md` to README/roadmap references.
- [x] Update `MILESTONE4_KICKOFF.md` with the pinned Omarchy reference.
- [x] Mark Workstream A1 initial source audit complete.
- [x] Mark Workstream A2 command namespace coverage complete for the safe-alias pass.
- [x] Create implementation tasks for Learn menu, keybinding viewer, Trigger/Style menu taxonomy, and first-run welcome copy.
