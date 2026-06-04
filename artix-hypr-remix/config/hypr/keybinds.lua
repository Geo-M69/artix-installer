-- Hyprland keybind source-of-truth (Lua).
return {
  -- Launchers and core apps.
  { mods = { "SUPER" }, key = "RETURN", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-launch-terminal" },
  { mods = { "SUPER" }, key = "SPACE", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-menu" },
  { mods = { "SUPER", "ALT" }, key = "SPACE", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-menu" },
  { mods = { "SUPER" }, key = "K", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-menu-keybindings" },
  { mods = { "SUPER", "SHIFT" }, key = "RETURN", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-launch-browser" },
  { mods = { "SUPER", "SHIFT" }, key = "F", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-launch-files" },

  -- Window controls.
  { mods = { "SUPER" }, key = "W", action = "close_window" },
  { mods = { "SUPER" }, key = "Q", action = "close_window" },
  { mods = { "SUPER", "SHIFT" }, key = "Q", action = "exit" },
  { mods = { "SUPER" }, key = "F", action = "fullscreen" },
  { mods = { "SUPER", "ALT" }, key = "F", action = "exec", command = "hyprctl dispatch fullscreen 1" },
  { mods = { "SUPER", "CTRL" }, key = "F", action = "exec", command = "hyprctl dispatch fullscreenstate 0 2" },
  { mods = { "SUPER" }, key = "J", action = "toggle_split" },
  { mods = { "SUPER" }, key = "V", action = "toggle_floating" },
  { mods = { "SUPER" }, key = "T", action = "toggle_floating" },
  { mods = { "SUPER", "CTRL" }, key = "T", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-launch-terminal -e btop" },
  { mods = { "SUPER", "CTRL" }, key = "L", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-system-lock" },
  { mods = { "SUPER" }, key = "O", action = "exec", command = "hyprctl dispatch togglefloating && hyprctl dispatch pin" },
  { mods = { "SUPER" }, key = "S", action = "exec", command = "hyprctl dispatch togglespecialworkspace scratchpad" },
  { mods = { "SUPER", "ALT" }, key = "S", action = "exec", command = "hyprctl dispatch movetoworkspace special:scratchpad" },
  { mods = { "SUPER" }, key = "L", action = "exec", command = "hyprctl keyword general:layout \"$(hyprctl getoption general:layout | grep -q 'str: \\\"dwindle\\\"' && echo master || echo dwindle)\"" },
  { mods = { "SUPER" }, key = "G", action = "exec", command = "hyprctl dispatch togglegroup" },
  { mods = { "SUPER", "ALT" }, key = "G", action = "exec", command = "hyprctl dispatch moveoutofgroup" },
  { mods = { "SUPER", "CTRL" }, key = "LEFT", action = "exec", command = "hyprctl dispatch changegroupactive b" },
  { mods = { "SUPER", "CTRL" }, key = "RIGHT", action = "exec", command = "hyprctl dispatch changegroupactive f" },
  { mods = { "SUPER", "CTRL" }, key = "UP", action = "exec", command = "hyprctl dispatch changegroupactive b" },
  { mods = { "SUPER", "CTRL" }, key = "DOWN", action = "exec", command = "hyprctl dispatch changegroupactive f" },
  { mods = { "SUPER", "ALT" }, key = "LEFT", action = "exec", command = "hyprctl dispatch moveintogroup l" },
  { mods = { "SUPER", "ALT" }, key = "RIGHT", action = "exec", command = "hyprctl dispatch moveintogroup r" },
  { mods = { "SUPER", "ALT" }, key = "UP", action = "exec", command = "hyprctl dispatch moveintogroup u" },
  { mods = { "SUPER", "ALT" }, key = "DOWN", action = "exec", command = "hyprctl dispatch moveintogroup d" },
  { mods = { "SUPER", "ALT" }, key = "1", action = "exec", command = "hyprctl dispatch changegroupactive 1" },
  { mods = { "SUPER", "ALT" }, key = "2", action = "exec", command = "hyprctl dispatch changegroupactive 2" },
  { mods = { "SUPER", "ALT" }, key = "3", action = "exec", command = "hyprctl dispatch changegroupactive 3" },
  { mods = { "SUPER", "ALT" }, key = "4", action = "exec", command = "hyprctl dispatch changegroupactive 4" },
  { mods = { "CTRL", "ALT" }, key = "DELETE", action = "exec", command = "while hyprctl clients | grep -q '^Window'; do hyprctl dispatch killactive; done" },

  -- Workspaces.
  { mods = { "SUPER" }, key = "TAB", action = "workspace_next" },
  { mods = { "SUPER", "SHIFT" }, key = "TAB", action = "workspace_prev" },
  { mods = { "SUPER", "CTRL" }, key = "TAB", action = "workspace_previous" },
  { mods = { "SUPER", "SHIFT", "ALT" }, key = "1", action = "exec", command = "hyprctl dispatch movetoworkspacesilent 1" },
  { mods = { "SUPER", "SHIFT", "ALT" }, key = "2", action = "exec", command = "hyprctl dispatch movetoworkspacesilent 2" },
  { mods = { "SUPER", "SHIFT", "ALT" }, key = "3", action = "exec", command = "hyprctl dispatch movetoworkspacesilent 3" },
  { mods = { "SUPER", "SHIFT", "ALT" }, key = "4", action = "exec", command = "hyprctl dispatch movetoworkspacesilent 4" },
  { mods = { "SUPER", "SHIFT", "ALT" }, key = "5", action = "exec", command = "hyprctl dispatch movetoworkspacesilent 5" },

  -- Clipboard.
  { mods = { "SUPER" }, key = "P", action = "exec", command = "bash ~/.config/artix-hypr-remix/bin/ahr-clipboard-picker" },

  -- Notifications.
  { mods = { "SUPER" }, key = "COMMA", action = "exec", command = "makoctl dismiss" },
  { mods = { "SUPER", "SHIFT" }, key = "COMMA", action = "exec", command = "makoctl dismiss --all" },
  { mods = { "SUPER", "ALT" }, key = "COMMA", action = "exec", command = "makoctl invoke" },
  { mods = { "SUPER", "SHIFT", "ALT" }, key = "COMMA", action = "exec", command = "makoctl restore" },

  -- Screenshot.
  { mods = {}, key = "PRINT", action = "exec", command = "grim -g \"$(slurp)\" \"$HOME/Pictures/screenshot-$(date +%s).png\"" },

  -- Media and device keys.
  { mods = {}, key = "XF86AudioRaiseVolume", action = "exec", command = "pamixer -i 5" },
  { mods = {}, key = "XF86AudioLowerVolume", action = "exec", command = "pamixer -d 5" },
  { mods = {}, key = "XF86AudioMute", action = "exec", command = "pamixer -t" },
  { mods = {}, key = "XF86AudioMicMute", action = "exec", command = "pamixer --default-source -t" },
  { mods = {}, key = "XF86MonBrightnessUp", action = "exec", command = "brightnessctl set +5%" },
  { mods = {}, key = "XF86MonBrightnessDown", action = "exec", command = "brightnessctl set 5%-" },
  { mods = {}, key = "XF86AudioNext", action = "exec", command = "playerctl next" },
  { mods = {}, key = "XF86AudioPrev", action = "exec", command = "playerctl previous" },
  { mods = {}, key = "XF86AudioPlay", action = "exec", command = "playerctl play-pause" },
  { mods = {}, key = "XF86AudioPause", action = "exec", command = "playerctl play-pause" },
}
