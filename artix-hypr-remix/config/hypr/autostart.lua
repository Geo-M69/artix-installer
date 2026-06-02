-- Hyprland autostart source-of-truth (Lua).
return {
  "waybar",
  "mako",
  "bash ~/.config/artix-hypr-remix/bin/ahr-optional-elephant",
  "bash ~/.config/artix-hypr-remix/bin/ahr-launcher-service",
  "bash ~/.config/artix-hypr-remix/bin/ahr-launch-wallpaper-session",
  "hypridle",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  "gnome-keyring-daemon --start --components=secrets",
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
  "pipewire",
  "wireplumber",
  "pipewire-pulse",
}
