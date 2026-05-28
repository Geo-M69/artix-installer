-- Hyprland monitor source-of-truth (Lua).
-- Keep defaults broad and override per-machine as needed.
return {
  default = {
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
  },

  -- Optional presets:
  -- retina = { gdk_scale = 2, monitor_scale = "auto" }
  -- balanced_4k = { gdk_scale = 1.75, monitor_scale = 1.6 }
  -- standard = { gdk_scale = 1, monitor_scale = 1 }
}
