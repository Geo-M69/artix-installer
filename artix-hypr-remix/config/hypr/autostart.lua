-- Hyprland autostart source-of-truth (Lua).
return {
  "waybar",
  "mako",
  "elephant",
  "walker --gapplication-service",
  "swww-daemon",
  "hypridle",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  "gnome-keyring-daemon --start --components=secrets",
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
  "pipewire",
  "wireplumber",
  "pipewire-pulse",
}