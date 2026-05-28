-- Hyprland keybind source-of-truth (Lua).
return {
  { mods = { "SUPER" }, key = "RETURN", action = "exec", command = "ghostty" },
  { mods = { "SUPER" }, key = "SPACE", action = "exec", command = "walker" },
  { mods = { "SUPER", "SHIFT" }, key = "F", action = "exec", command = "nautilus" },
  { mods = { "SUPER" }, key = "Q", action = "close_window" },
  { mods = { "SUPER", "SHIFT" }, key = "Q", action = "exit" },
  { mods = { "SUPER" }, key = "V", action = "toggle_floating" },
  { mods = { "SUPER" }, key = "P", action = "exec", command = "cliphist list | walker -d | cliphist decode | wl-copy" },
}