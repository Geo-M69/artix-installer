# Screenshots & Expected-Result Artifacts

This directory should contain screenshots or expected-result descriptions for the beta release. Screenshots help users quickly understand what the desktop looks like after a successful install and provide a visual reference for validation.

## Required Screenshots (Before Beta Tag)

| # | Screenshot | What to capture | Status |
|---|-----------|-----------------|--------|
| 1 | First-login desktop | Clean Hyprland session after first boot: Waybar visible, Mako notification area, empty desktop with wallpaper/theme | ✅ Captured (2026-06-14, NVIDIA laptop, nord theme) |
| 2 | App launcher | `Super+Space` or `ahr-launch-apps` showing the app launcher with desktop apps and search | ✅ Captured (2026-06-14, NVIDIA laptop, Walker backend) |
| 3 | Control menu | `Super+Alt+Space` or `ahr-menu` showing the main menu with all top-level slices | ✅ Captured (2026-06-14, NVIDIA laptop, Walker backend) |
| 4 | Waybar detail | Waybar showing workspaces, clock, system tray, audio/network indicators, battery (if laptop) | ✅ Captured (2026-06-14, NVIDIA laptop, nord theme) |
| 5 | Theme showcase | Desktop with `nord` theme applied; terminal open showing themed colors | ✅ Captured (2026-06-14, NVIDIA laptop, nord theme) |
| 6 | Update workflow | Terminal output of `ahr update --dry-run` showing update checks | ✅ Captured (2026-06-14, NVIDIA laptop, Ghostty terminal) |
| 7 | greetd login screen | `greetd` tuigreet greeter prompt on VT7 (if `greetd` mode is documented as tested) | ❌ Not yet captured (requires greetd session) |

## How To Capture

From a running Hyprland session:

```bash
# Full screenshot
grim ~/screenshot-full-$(date +%Y%m%d-%H%M%S).png

# Area select (click and drag)
grim -g "$(slurp)" ~/screenshot-area-$(date +%Y%m%d-%H%M%S).png

# Focused window
grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" ~/screenshot-window-$(date +%Y%m%d-%H%M%S).png
```

## Naming Convention

```
screenshot-<number>-<description>-<host>-<date>.png
```

Example: `screenshot-01-first-login-geoartix-20260605.png`

## Expected Results (Text Descriptions)

If screenshots are not yet available, the following text descriptions document what a successful first login should look like:

### First Login (TTY Mode)
1. Boot completes to TTY login prompt.
2. User logs in with their desktop user credentials.
3. `~/.bash_profile` (or `~/.zprofile`) detects VT1 and launches Hyprland via `start-hyprland-session.sh`.
4. Hyprland starts: `nord` theme is active, Waybar appears at the top with workspaces, clock, and system tray.
5. Mako notification daemon displays a first-run welcome notification (if first-run tasks are pending).
6. Wallpaper (solid color fallback if no background image is symlinked) is visible.
7. `Super+Space` opens the application launcher (Walker if available, else wofi/rofi fallback).
8. `Super+Return` opens the terminal (default terminal emulator).
9. `Super+Q` closes the focused window.

### First Login (Greetd Mode)
1. Boot completes to greetd tuigreet greeter on VT7.
2. User selects their desktop user and enters password.
3. greetd launches Hyprland via `start-hyprland-session.sh`.
4. Same desktop state as TTY mode (theme, Waybar, Mako, launcher, etc.).

## Post-Beta Plans

- Automated screenshot capture as part of CI/smoke validation (future).
- Gallery in README linking to this directory.
