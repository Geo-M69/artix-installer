-- Hyprland keybind source-of-truth (Lua).
return {
  -- Launchers and core apps.
  { mods = { "SUPER" }, key = "RETURN", action = "exec", command = "ghostty" },
  { mods = { "SUPER" }, key = "SPACE", action = "exec", command = "walker" },
  { mods = { "SUPER", "SHIFT" }, key = "F", action = "exec", command = "nautilus" },

  -- Window controls.
  { mods = { "SUPER" }, key = "W", action = "close_window" },
  { mods = { "SUPER" }, key = "Q", action = "close_window" },
  { mods = { "SUPER", "SHIFT" }, key = "Q", action = "exit" },
  { mods = { "SUPER" }, key = "F", action = "fullscreen" },
  { mods = { "SUPER" }, key = "J", action = "toggle_split" },
  { mods = { "SUPER" }, key = "V", action = "toggle_floating" },
  { mods = { "SUPER" }, key = "L", action = "exec", command = "hyprlock" },

  -- Workspaces.
  { mods = { "SUPER" }, key = "TAB", action = "workspace_next" },
  { mods = { "SUPER", "SHIFT" }, key = "TAB", action = "workspace_prev" },
  { mods = { "SUPER", "CTRL" }, key = "TAB", action = "workspace_previous" },

  -- Clipboard.
  { mods = { "SUPER" }, key = "P", action = "exec", command = "cliphist list | walker -d | cliphist decode | wl-copy" },

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