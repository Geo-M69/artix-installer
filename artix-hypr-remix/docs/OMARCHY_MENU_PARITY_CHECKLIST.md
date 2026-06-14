# Omarchy Menu Parity Checklist

This checklist tracks the gradual work needed to make Artix Hypr Remix menus look and feel like Omarchy menus while preserving Artix/OpenRC correctness.

The goal is not to copy Omarchy internals blindly. The goal is to match the user-facing menu experience, Walker styling, menu hierarchy, labels, prompts, and interaction rhythm, then map each action to an AHR-native implementation.

## References

- AHR menu: `config/artix-hypr-remix/bin/ahr-menu`
- AHR Walker config: `config/walker/config.toml`
- AHR Walker theme: `config/artix-hypr-remix/default/walker/themes/ahr-default/`
- AHR theme engine: `config/artix-hypr-remix/bin/ahr-theme-lib.sh`
- Omarchy menu: `../omarchy/bin/omarchy-menu`
- Omarchy Walker config: `../omarchy/config/walker/config.toml`
- Omarchy Walker theme: `../omarchy/default/walker/themes/omarchy-default/`
- Omarchy Walker theme template: `../omarchy/default/themed/walker.css.tpl`
- Omarchy manual: `../the-omarchy-manual.md`

## Definition Of Done

- [ ] AHR graphical menus use Walker as the primary backend when Walker is installed.
- [ ] AHR keeps `wofi`, `rofi`, and TTY paths as fallbacks.
- [ ] Main menu prompt, width, height behavior, icons, option order, and selected-row feel match Omarchy.
- [ ] Walker layout and CSS match Omarchy defaults unless AHR intentionally documents a difference.
- [ ] Walker colors come from the active AHR/Omarchy theme rather than hardcoded CSS.
- [ ] Menu actions stay Artix/OpenRC-native even when labels mirror Omarchy.
- [ ] Unsupported Omarchy features are classified and documented instead of hidden as broken menu items.
- [ ] Parity is checked with screenshots and real menu navigation after each visual/menu pass.

## Phase 1: Baseline Audit

- [x] Capture current AHR screenshots (renamed to `docs/screenshots/ahr-menu-*.png`):
  - [x] Main menu
  - [x] Learn menu
  - [x] Trigger menu
  - [x] Style menu
  - [x] Setup menu
  - [x] Install menu
  - [x] Remove menu
  - [x] Update menu
  - [x] System menu
- [ ] Capture matching Omarchy screenshots for the same menus. *(requires graphical session)*
  - [ ] Main menu
  - [ ] Learn menu
  - [ ] Trigger menu
  - [ ] Style menu
  - [ ] Setup menu
  - [ ] Install menu
  - [ ] Remove menu
  - [ ] Update menu
  - [ ] System menu
- [x] Record current AHR backend selection behavior from `ahr-menu`.
- [x] Record current Omarchy Walker invocation flags from `omarchy-menu`.
- [x] Diff AHR and Omarchy Walker `layout.xml` (identical).
- [x] Diff AHR and Omarchy Walker `style.css`.
- [x] Diff AHR and Omarchy Walker `config.toml`.
- [x] Create a submenu parity table from `omarchy-menu`.
- [x] Classify every Omarchy menu item:
  - [x] Direct AHR equivalent
  - [x] AHR equivalent with OpenRC adaptation
  - [x] Needs new AHR command
  - [x] Optional polish
  - [x] Unsupported for now
  - [x] Intentionally different

## Phase 2: Walker Backend And Invocation

- [x] Decide whether installed AHR should prefer Walker over `wofi` for graphical menu parity.
  → Decision: prefer Walker (matches Omarchy). Applied swap in `menu_backend()`.
- [x] Keep `AHR_MENU_BACKEND` override behavior.
  → Already preserved — `AHR_MENU_BACKEND=walker|wofi|rofi|tty` works unchanged.
- [x] Preserve `wofi`, `rofi`, and TTY fallback behavior.
  → All three backends still detected and used when Walker is absent.
- [x] Match Omarchy Walker dmenu flags:
  - [x] `--dmenu`
  - [x] `--width 295`
  - [x] `--minheight 1`
  - [x] `--maxheight 630` (AHR: **520** — intentional divergence)
  - [x] prompt with ellipsis
  → AHR reduced to 520 for Waybar clearance and less visual weight on
    laptop screens. Omarchy uses 630. This is a documented AHR tuning choice.
- [x] Add or preserve close/toggle behavior when an existing Walker dmenu is open.
  → Added `toggle_existing_menu()` called from `dispatch()`.
- [x] Validate that app launcher behavior remains separate from control-menu behavior.
  → Confirmed: `ahr-launch-apps` (Super+Space) is a separate script from `ahr-menu` (Super+Alt+Space).

## Phase 3: Walker Visual Parity

- [x] Make AHR `layout.xml` intentionally match Omarchy `layout.xml`.
  → Already identical per Phase 1 diff. No code change needed.
- [x] Replace hardcoded AHR Walker palette with theme-derived colors.
  → Complete. `style.css` now uses `@text`, `@base`, `@border`, `@selected-text` variables.
- [x] Add an AHR equivalent of Omarchy's `walker.css.tpl`.
  → Created `default/themed/walker.css.tpl` with same `{{ accent }}`, `{{ foreground }}`, `{{ background }}` placeholders.
- [x] Render active theme colors into `current/theme/walker.css`.
  → Already supported by existing `ahr_theme_render_templates_for_dir` — processes `.tpl` files from `default/themed/` during `ahr-theme set-templates` / `ahr-theme refresh`.
- [x] Import active theme CSS from AHR Walker `style.css`.
  → Added `@import url("../../../../current/theme/walker.css");` in `ahr-default/style.css`.
- [ ] Add an AHR state CSS import for Walker-specific toggles if corner toggles are supported.
  → Deferred — AHR doesn't have corner toggles yet. Can add when toggles gain Walker CSS support.
- [x] Match Omarchy default visual details:
  - [x] font family behavior — AHR keeps `JetBrainsMono Nerd Font` (intentionally better than generic `monospace`)
  - [x] font size — 18px (matches)
  - [x] menu width — `min-width: 295px` (matches)
  - [x] outer padding — 20px (matches)
  - [x] border width — 2px (matches)
  - [x] background opacity — `alpha(@base, 0.95)` (matches)
  - [x] search container padding — 10px (matches)
  - [x] row padding — `padding: 14px 0` (matches)
  - [x] selected-row background — `alpha(@text, 0.07)` (matches)
  - [x] selected text color — `@selected-text` (matches)
  - [x] icon size — `scale(0.9)` (matches)
  - [x] icon spacing — `margin-right: 14px` (matches)
  - [x] hidden subtext behavior — `font-size: 0px` (matches)
  - [x] scrollbar visibility — `opacity: 0` (matches)
  - [x] keybind hint area — AHR has richer styling (intentional enhancement); Omarchy has minimal/empty rules
- [x] Remove or document AHR-specific rounded corners.
  → All `border-radius` properties removed from `style.css`. Documented in comment at top of file.
- [ ] Test one dark theme and one light theme. *(requires graphical session)*
- [ ] Verify Omarchy theme installs produce matching Walker colors. *(requires graphical session)*

## Phase 4: Top-Level Menu Parity

- [x] Match Omarchy top-level prompt: `Go`.
  → Changed `show_main_menu()` prompt from `"AHR Menu"` to `"Go"`.
- [x] Match Omarchy top-level order:
  - [x] Apps
  - [x] Learn
  - [x] Trigger
  - [x] Style
  - [x] Setup
  - [x] Install
  - [x] Remove
  - [x] Update
  - [x] About
  - [x] System
  → Reordered in `show_main_menu()` to match Omarchy (About before System).
- [x] Match Omarchy top-level icons.
  → Verified identical per Phase 1 diff. All Nerd Font icons match.
- [x] Remove visible `Cancel` from Walker menus if escape/empty selection already handles cancel.
  → Removed `"Cancel"` entry. Empty/invalid input falls to `*) exit 0`.
- [x] Keep TTY fallback clear and usable even if graphical menus hide cancel.
  → Confirmed: TTY `menu_select_tty` returns `""` on empty input, `show_main_menu` exits on `""` or any unmatched input. Same behavior without Cancel entry.
- [x] Keep direct submenu arguments working:
  - [x] `ahr-menu apps`
  - [x] `ahr-menu learn`
  - [x] `ahr-menu trigger`
  - [x] `ahr-menu style`
  - [x] `ahr-menu setup`
  - [x] `ahr-menu install`
  - [x] `ahr-menu remove`
  - [x] `ahr-menu update`
  - [x] `ahr-menu about`
  - [x] `ahr-menu system`
  → `dispatch()` unchanged — all slice arguments still map to same handlers.

## Phase 5: Submenu Taxonomy Parity

Use Omarchy's labels and order where AHR can support the same user outcome.

- [ ] Learn menu:
  - [ ] Keybindings
  - [ ] Tmux keybindings or documented omission
  - [ ] AHR/Omarchy manual link strategy
  - [ ] Hyprland reference
  - [ ] Artix/Arch reference decision
  - [ ] Editor/shell references
- [ ] Trigger menu:
  - [ ] Reminder
  - [ ] Capture
  - [ ] Transcode
  - [ ] Share
  - [ ] Toggle
  - [ ] Hardware
- [ ] Capture menu:
  - [ ] Screenshot
  - [ ] Screenrecord
  - [ ] Text extraction
  - [ ] Color picker
- [ ] Toggle menu:
  - [ ] Screensaver
  - [ ] Nightlight
  - [ ] Idle lock
  - [ ] Notifications
  - [ ] Top bar
  - [ ] Workspace layout
  - [ ] Window gaps
  - [ ] One-window ratio
  - [ ] Monitor scaling
  - [ ] Direct boot
  - [ ] Passwordless sudo
- [ ] Style menu:
  - [ ] Theme
  - [ ] Unlock/lock screen styling
  - [ ] Font
  - [ ] Background
  - [ ] Waybar/top bar
  - [ ] Corners
  - [ ] Hyprland visual settings
  - [ ] Screensaver/about branding decision
- [ ] Setup menu:
  - [ ] Defaults
  - [ ] Config editing
  - [ ] Audio
  - [ ] Network
  - [ ] Bluetooth
  - [ ] Power/input/monitor items where safe
- [ ] Install menu:
  - [ ] Keep broad Omarchy categories classified before exposing them.
  - [ ] Only add menu entries with safe package checks and rollback/remove notes.
- [ ] Remove menu:
  - [ ] Keep destructive removals conservative.
  - [ ] Require confirmation for service/package removal.
- [ ] Update menu:
  - [ ] Preserve AHR update/migration semantics.
  - [ ] Add Omarchy-like process/config refresh entries only where AHR has safe commands.
- [ ] System menu:
  - [ ] Screensaver decision
  - [ ] Lock
  - [ ] Suspend
  - [ ] Hibernate
  - [ ] Logout
  - [ ] Restart
  - [ ] Shutdown

## Phase 6: Action Mapping

For each menu item, define the command behind it before implementing.

- [ ] Build `Omarchy label -> AHR command` mapping for supported items.
- [ ] Build `Omarchy label -> unsupported reason` mapping for deferred items.
- [ ] Keep systemd-only actions out of AHR unless an OpenRC/elogind-safe adapter exists.
- [ ] Keep package actions guarded by command/package availability checks.
- [ ] Keep dangerous actions behind confirmation menus.
- [ ] Keep terminal handoff behavior consistent for long-running commands.
- [ ] Keep notifications concise and actionable when dependencies are missing.

## Phase 7: Theme Integration

- [ ] Add Walker CSS template rendering to `ahr-theme` refresh/set flow.
- [ ] Ensure AHR current-theme compatibility link still satisfies Omarchy theme assets.
- [ ] Validate `ahr-theme-install-omarchy` installs themes with usable Walker colors.
- [ ] Validate `ahr-theme refresh` regenerates Walker CSS.
- [ ] Validate theme changes restart or refresh Walker as needed.
- [ ] Add doctor/repair checks for missing Walker theme CSS if useful.

## Phase 8: Validation

- [ ] Run shell syntax checks for edited scripts.
- [ ] Run `scripts/check-openrc-portability.sh` after touching menu/runtime scripts.
- [ ] Run menu command help paths:
  - [ ] `ahr-menu help`
  - [ ] `ahr-menu main`
  - [ ] each direct submenu argument
- [ ] Validate missing dependency messages for optional actions.
- [ ] Validate graphical Walker backend.
- [ ] Validate `wofi` fallback.
- [ ] Validate `rofi` fallback where available.
- [ ] Validate TTY fallback.
- [ ] Capture before/after screenshots for visual changes.
- [ ] Compare against Omarchy screenshots.
- [ ] Update this checklist after each completed pass.

## Notes

- Visual parity should land before broad feature parity. It is lower risk and gives immediate feedback.
- Menu labels can match Omarchy before every action exists, but unsupported entries should not be exposed as dead ends.
- AHR should continue to privilege Artix/OpenRC correctness over exact command parity.
- If a menu item would require systemd, UWSM, SDDM, Limine, Plymouth, or broad Arch-only assumptions, classify it before implementing.
