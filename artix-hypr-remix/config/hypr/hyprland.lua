-- Hyprland settings source-of-truth (Lua).
-- These values are Omarchy-inspired but intentionally distro-neutral.
return {
  monitor = "preferred,auto,auto",
  workspace_layout = "dwindle",
  cursor_size = 24,
  monitor_scale = "auto",

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

  input = {
    kb_layout = "us",
    kb_options = "compose:caps",
    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,

    touchpad = {
      clickfinger_behavior = true,
      scroll_factor = 0.4,
    },
  },
}