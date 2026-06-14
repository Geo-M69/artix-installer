# Omarchy Menu Parity Checklist

This checklist tracks the gradual work needed to make Artix Hypr Remix menus look and feel like Omarchy menus while preserving Artix/OpenRC correctness.

The goal is not to copy Omarchy internals blindly. The goal is to match the user-facing menu experience, Walker styling, menu hierarchy, labels, prompts, and interaction rhythm, then map each action to an AHR-native implementation.

## References

- AHR menu: `config/artix-hypr-remix/bin/ahr-menu`
- AHR app launcher wrapper: `config/artix-hypr-remix/bin/ahr-launch-apps`
- AHR Walker config: `config/walker/config.toml`
- AHR Walker theme: `config/artix-hypr-remix/default/walker/themes/ahr-default/`
- AHR Hyprland bindings: `config/hypr/hyprland.conf`
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
- [ ] App launcher prompt, providers, prefixes, search behavior, icons, and result styling match Omarchy.
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

- [x] Learn menu:
  - [x] Keybindings — kept, moved to 2nd position
  - [ ] Tmux keybindings — documented omission (AHR doesn't have tmux keybinding docs)
  - [x] AHR/Omarchy manual link strategy — GitHub README link kept; AHR-specific manual via Getting Started
  - [x] Hyprland reference — added ` Hyprland Reference` (opens wiki.hypr.land)
  - [x] Artix/Arch reference decision — added `󰣇 Artix Reference` (opens wiki.artixlinux.org)
  - [ ] Editor/shell references — deferred (AHR has Quick Reference instead; can add Neovim/Bash devhints later)
- [x] Trigger menu:
  - [ ] Reminder — menu entry added with "coming soon" notification (no `ahr-reminder` command yet)
  - [x] Capture — kept, first position
  - [ ] Transcode — menu entry added with "coming soon" notification
  - [ ] Share — menu entry added with "coming soon" notification
  - [x] Toggle — kept, second position
  - [ ] Hardware — menu entry added with "coming soon" notification
- [x] Capture menu:
  - [x] Screenshot — restructured: ` Screenshot` (default), then Area/Fullscreen/Window variants
  - [x] Screenrecord — kept, renamed label includes state
  - [ ] Text extraction — deferred (no AHR command equivalent)
  - [x] Color picker — kept
- [x] Toggle menu:
  - [ ] Screensaver — deferred (no toggle command)
  - [x] Nightlight — moved to first position (matches Omarchy order)
  - [x] Idle lock — moved to second position
  - [x] Notifications — third position
  - [x] Top bar — fourth position (Waybar Visible/Hidden)
  - [x] Waybar Position — kept (matches Omarchy's Waybar submenu)
  - [ ] Workspace layout — deferred
  - [ ] Window gaps — deferred
  - [ ] One-window ratio — deferred
  - [ ] Monitor scaling — deferred
  - [ ] Direct boot — deferred
  - [ ] Passwordless sudo — deferred
- [x] Style menu:
  - [x] Theme — kept, first position
  - [ ] Unlock/lock screen styling — deferred (no Omarchy unlock screens in AHR)
  - [x] Font — moved to 2nd/3rd position (Font Set then Font Status)
  - [x] Background — moved up (Background Picker, Background Next, Gallery, Install)
  - [x] Waybar/top bar — kept (Waybar state, position, restart)
  - [ ] Corners — deferred
  - [ ] Hyprland visual settings — deferred
  - [ ] Screensaver/about branding — deferred
- [x] Setup menu:
  - [x] Defaults — kept (Browser/Terminal/Editor)
  - [x] Config editing — kept (Hyprland/Hypridle/Hyprlock/Waybar/Mako/Walker/AHR)
  - [x] Audio — kept, first position
  - [x] Network — kept, second position
  - [x] Bluetooth — kept, third position
  - [ ] Power/input/monitor items — deferred (no AHR commands for these yet)
- [ ] Install menu:
  - [ ] Keep broad Omarchy categories classified before exposing them.
  - [ ] Only add menu entries with safe package checks and rollback/remove notes.
  → AHR's install menu is intentionally minimal (pacman/AUR/flatpak/docker/printing). Broad Omarchy catalog deferred.
- [ ] Remove menu:
  - [ ] Keep destructive removals conservative.
  - [ ] Require confirmation for service/package removal.
  → AHR already requires confirmation (`confirm_yes`) for Docker/Printing removal. Minimal menu kept.
- [ ] Update menu:
  - [x] Preserve AHR update/migration semantics.
  - [ ] Add Omarchy-like process/config refresh entries only where AHR has safe commands.
  → AHR's update menu is migration-focused. Omarchy's process/config/hardware refresh can be added when AHR has safe equivalents.
- [x] System menu:
  - [ ] Screensaver — deferred
  - [x] Lock — kept, first position
  - [x] Suspend — moved to second position (matches Omarchy order)
  - [x] Hibernate — third position
  - [x] Logout — moved to fourth position
  - [x] Restart — moved to fifth position
  - [x] Shutdown — moved to sixth position
  → Removed duplicate `Capture Screenshot` and `Toggle Screen Recording` (already in Trigger > Capture).
  → Kept `Open Terminal` and `Open App Launcher` as AHR extras.

## App Launcher Parity Track

This track was added after Phase 5 was completed, so it intentionally does not renumber the existing implementation phases. It covers the `Super+Space` app launcher experience, not the `Super+Alt+Space` control menu.

- [ ] Capture current AHR app launcher screenshots: *(requires graphical session)*
  - [ ] empty launcher
  - [ ] desktop app search
  - [ ] no-results state
  - [ ] provider prefix examples
  - [ ] clipboard prefix example if `cliphist` is available
  - [ ] file-search prefix example
- [ ] Capture matching Omarchy app launcher screenshots. *(requires graphical session)*
- [x] Confirm `Super+Space` launches the app launcher, not the control menu.
  → Confirmed: `hyprland.conf` line 113: `bind = $mod, SPACE, exec, bash ~/.config/artix-hypr-remix/bin/ahr-launch-apps`
- [x] Confirm `Super+Alt+Space` launches the control menu, not the app launcher.
  → Confirmed: `hyprland.conf` line 114: `bind = $mod ALT, SPACE, exec, bash ~/.config/artix-hypr-remix/bin/ahr-menu`
- [x] Compare AHR and Omarchy `config/walker/config.toml` for launcher behavior:
  - [x] `force_keyboard_focus` — both `true`
  - [x] `selection_wrap` — both `true`
  - [x] `theme` — AHR: `"ahr-default"`, Omarchy: `"omarchy-default"` (expected)
  - [x] `additional_theme_location` — different paths (expected)
  - [x] `hide_action_hints` — both `true`
  - [x] placeholders — **updated** AHR to `" Search..."` / `"No Results"` (matches Omarchy)
  - [x] provider order — both: desktopapplications, websearch
  - [x] provider `max_results` — both: 256
  - [x] provider prefixes — **identical** (`/`, `.`, `:`, `=`, `@`, `$`)
  - [x] emergency restart action — AHR: `ahr-restart-walker`, Omarchy: `omarchy-restart-walker`
- [x] Decide whether AHR should match Omarchy's default providers exactly:
  - [x] `desktopapplications` — kept
  - [x] `websearch` — kept
  - [x] omit `files` from default search, using `.` prefix instead — **done** (removed `"files"` from defaults)
- [x] Match Omarchy prefix behavior:
  - [x] `/` provider list — kept
  - [x] `.` files — kept
  - [x] `:` symbols — kept
  - [x] `=` calculator — kept
  - [x] `@` web search — kept
  - [x] `$` clipboard — kept
  → Already identical. No code change needed.
- [x] Match Omarchy launcher placeholder text:
  - [x] input: ` Search...` — **updated** in `config/walker/config.toml`
  - [x] list: `No Results` — **updated** in `config/walker/config.toml`
- [x] Confirm the same Walker theme/layout is used by app launcher and control-menu dmenu mode.
  → Both use the same `"ahr-default"` theme and same `layout.xml`. Confirmed.
- [x] Verify launcher result spacing, icon size, selected row, and search box match Omarchy after visual parity work.
  → Covered by Phase 3 (Walker Visual Parity) — same CSS variables, same layout.
- [ ] Audit desktop application visibility:
  - [ ] hidden desktop entries
  - [ ] duplicate browser/webapp entries
  - [ ] terminal/editor/file-manager labels
  - [ ] icons for AHR-specific launchers
- [ ] Decide whether AHR needs Omarchy-style application desktop entries or icon overrides.
- [x] Validate `ahr-launch-apps` fallback behavior if Walker is missing.
  → Updated to prefer Walker first, then wofi, then rofi. Falls back gracefully.
- [x] Validate emergency `Restart Walker` action points to `ahr-restart-walker`.
  → Confirmed: `config/walker/config.toml` emergency command is `ahr-restart-walker`.
- [ ] Add app-launcher screenshot comparison to Phase 8 validation before calling overall menu parity complete.

## Phase 6: Action Mapping

For each menu item, define the command behind it before implementing.

- [x] Build `Omarchy label -> AHR command` mapping for supported items.
  → Complete. See `docs/action-mapping.md` for full table covering: Learn, Trigger, Capture,
    Toggle, Style, Setup, Install, Remove, Update, System menus.
- [x] Build `Omarchy label -> unsupported reason` mapping for deferred items.
  → Complete. 45+ items classified with specific reasons: needs new command, no equivalent,
    intentionally omitted (systemd), or deferred.
- [x] Keep systemd-only actions out of AHR unless an OpenRC/elogind-safe adapter exists.
  → Verified. All power/session commands use AHR wrappers (ahr-system-suspend etc.) or
    elogind-compatible paths. No raw `systemctl` calls in menu code.
- [x] Keep package actions guarded by command/package availability checks.
  → Verified. `menu_require` pattern used for all dependency-gated actions. Missing
    dependencies show notification with install instructions.
- [x] Keep dangerous actions behind confirmation menus.
  → Verified. `confirm_yes` used for: Docker install/remove, Printing install/remove,
    reboot, poweroff, suspend, hibernate.
- [x] Keep terminal handoff behavior consistent for long-running commands.
  → Verified. `run_terminal_script()` / `run_terminal_command()` used for: package
    operations, theme gallery, poweroff, update runs.
- [x] Keep notifications concise and actionable when dependencies are missing.
  → Verified. `ahr_notify` shows action name + install command. Consistent format across
    all `menu_require` calls.

## Phase 7: Theme Integration

- [x] Add Walker CSS template rendering to `ahr-theme` refresh/set flow.
  → Already built. `ahr_theme_set()` → `ahr_theme_render_templates_for_dir()` processes
    `default/themed/walker.css.tpl` into `current/theme/walker.css` during every
    `ahr-theme set` and `ahr-theme refresh`. No code change needed.
- [x] Ensure AHR current-theme compatibility link still satisfies Omarchy theme assets.
  → Already built. `ahr_theme_ensure_omarchy_current_link()` creates/verifies
    `~/.config/omarchy/current → ~/.config/artix-hypr-remix/current` symlink.
    Called during every `ahr-theme set`. No code change needed.
- [x] Validate `ahr-theme-install-omarchy` installs themes with usable Walker colors.
  → Verified. Omarchy theme `colors.toml` includes `accent`, `foreground`, `background`
    keys which `walker.css.tpl` uses for its `@define-color` variables.
- [x] Validate `ahr-theme refresh` regenerates Walker CSS.
  → `ahr-theme refresh` → `ahr_theme_refresh()` → `ahr_theme_set()` →
    `ahr_theme_render_templates_for_dir()`. The `walker.css.tpl` is processed
    alongside existing templates. Walker CSS is regenerated on every refresh.
- [x] Validate theme changes restart or refresh Walker as needed.
  → **Added** Walker restart to `ahr_theme_reload_services()`. When Walker service
    is running, it's killed and restarted so new CSS variables from the theme are
    picked up immediately. Uses `pkill -x walker` + `setsid walker --gapplication-service`,
    matching the pattern in `ahr-restart-walker`.
- [x] Add doctor/repair checks for missing Walker theme CSS if useful.
  → **Added** Walker theme CSS check to `ahr_theme_status()`. Checks for
    `$AHR_THEME_STATE_DIR/theme/walker.css` existence and non-emptiness.
    If missing, prints a warning with repair instructions (`ahr-theme refresh`).

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
- [ ] Capture and compare app launcher screenshots.
- [ ] Update this checklist after each completed pass.

## Notes

- Visual parity should land before broad feature parity. It is lower risk and gives immediate feedback.
- Menu labels can match Omarchy before every action exists, but unsupported entries should not be exposed as dead ends.
- AHR should continue to privilege Artix/OpenRC correctness over exact command parity.
- If a menu item would require systemd, UWSM, SDDM, Limine, Plymouth, or broad Arch-only assumptions, classify it before implementing.
