-- Hyprland look-and-feel source-of-truth (Lua).
-- Values are conservative defaults; tweak freely on hardware.
return {
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    layout = "dwindle",
  },

  decoration = {
    rounding = 8,
    dim_inactive = true,
    dim_strength = 0.08,
  },

  animations = {
    enabled = true,
  },
}
