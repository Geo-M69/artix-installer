-- Hyprland settings source-of-truth (Lua).
-- These values are Omarchy-inspired but intentionally distro-neutral.
return {
  monitor = "preferred,auto,auto",
  workspace_layout = "dwindle",
  cursor_size = 24,

  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    allow_tearing = false,
  },

  decoration = {
    rounding = 8,
    dim_inactive = true,
    dim_strength = 0.08,
  },

  animation = {
    enabled = true,
  },

  xwayland = {
    force_zero_scaling = true,
  },
}