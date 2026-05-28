-- Hyprland input source-of-truth (Lua).
-- Omarchy-inspired defaults adapted for portable Artix/OpenRC setups.
return {
  kb_layout = "us",
  kb_options = "compose:caps",
  repeat_rate = 40,
  repeat_delay = 250,
  numlock_by_default = true,

  touchpad = {
    clickfinger_behavior = true,
    scroll_factor = 0.4,
  },

  app_scroll_touchpad = {
    ["(Alacritty|kitty|foot)"] = 1.5,
    ["com.mitchellh.ghostty"] = 0.2,
  },
}
