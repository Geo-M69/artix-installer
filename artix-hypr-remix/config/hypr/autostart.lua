-- Hyprland autostart source-of-truth (Lua).
return {
  "waybar",
  "mako",
  "swww-daemon",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  "gnome-keyring-daemon --start --components=secrets",
  "pipewire",
  "wireplumber",
  "pipewire-pulse",
}