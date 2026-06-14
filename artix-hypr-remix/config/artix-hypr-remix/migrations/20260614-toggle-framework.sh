#!/usr/bin/env bash
# Migration: deploy toggle framework (ahr-toggle-lib.sh, ahr-toggle) and
# ensure existing toggle state files are in the correct location.
set -euo pipefail

framework_root="$HOME/.config/artix-hypr-remix"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/toggles"

echo "Migration 20260614-toggle-framework: Deploying toggle framework"

# 0. Patch hyprland.conf: replace unconditional exec-once = hypridle with
#    ahr-restore-idle so the toggle state persists across reboots.
hyprland_conf="$HOME/.config/hypr/hyprland.conf"
if [[ -f "$hyprland_conf" ]]; then
  if grep -qE '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*hypridle([[:space:]]|#|$)' "$hyprland_conf" 2>/dev/null; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    cp "$hyprland_conf" "${hyprland_conf}.bak.${timestamp}"
    echo "  Backed up hyprland.conf to ${hyprland_conf}.bak.${timestamp}"
    sed -i 's/^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*hypridle[[:space:]#].*$/exec-once = bash ~\/.config\/artix-hypr-remix\/bin\/ahr-restore-idle/' "$hyprland_conf"
    # Also handle bare line with no trailing whitespace/comment
    sed -i 's/^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*hypridle[[:space:]]*$/exec-once = bash ~\/.config\/artix-hypr-remix\/bin\/ahr-restore-idle/' "$hyprland_conf"
    # Verify
    if grep -qE '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*hypridle' "$hyprland_conf" 2>/dev/null; then
      echo "  WARN: replacement may have failed — restoring backup"
      cp "${hyprland_conf}.bak.${timestamp}" "$hyprland_conf"
    else
      echo "  Patched hyprland.conf: hypridle -> ahr-restore-idle"
    fi
  else
    echo "  hyprland.conf: no unconditional exec-once = hypridle found (already patched or not present)"
  fi
else
  echo "  hyprland.conf not found at $hyprland_conf — skipping"
fi

# 1. Ensure namespace installer includes new commands and run it
nsinstall="$framework_root/bin/namespace-install.sh"
if [[ -x "$nsinstall" ]]; then
  echo "  Re-running namespace installer to register new commands..."
  "$nsinstall" --quiet
  echo "  Namespace installer done."
else
  echo "  WARN: namespace-install.sh not found at $nsinstall"
fi

# 2. Ensure toggle state directory exists
if [[ ! -d "$state_dir" ]]; then
  mkdir -p "$state_dir"
  echo "  Created toggle state directory: $state_dir"
fi

# 3. Ensure existing toggle files are present. Seed the idle flag so that
#    existing users who never toggled idle continue to have it on by default.
#    (ahr-restore-idle checks the flag; without seeding, idle would be off
#    after upgrade until the user manually toggles it.)
for toggle_name in nightlight idle notification-silencing; do
  if [[ -f "$state_dir/$toggle_name" ]]; then
    echo "  Toggle '$toggle_name' — enabled"
  else
    if [[ "$toggle_name" == "idle" ]] && [[ ! -f "$state_dir/idle-off" ]]; then
      : > "$state_dir/idle"
      echo "  Toggle 'idle' — seeded (enabled by default)"
    elif [[ "$toggle_name" == "idle" ]] && [[ -f "$state_dir/idle-off" ]]; then
      echo "  Toggle 'idle' — not seeding (disabled via idle-off flag)"
    else
      echo "  Toggle '$toggle_name' — disabled (default)"
    fi
  fi
done

# 4. waybar-position is special — it stores a value, not just a flag
if [[ -f "$state_dir/waybar-position" ]]; then
  pos="$(cat "$state_dir/waybar-position" 2>/dev/null || true)"
  echo "  Waybar position — ${pos:-unknown}"
else
  echo "  Waybar position — default (top)"
fi

echo "Migration 20260614-toggle-framework complete."
