-- Hyprland session environment source-of-truth (Lua).
return {
  XDG_SESSION_TYPE = "wayland",
  XDG_CURRENT_DESKTOP = "Hyprland",
  XDG_SESSION_DESKTOP = "Hyprland",

  GDK_BACKEND = "wayland,x11,*",
  QT_QPA_PLATFORM = "wayland;xcb",
  MOZ_ENABLE_WAYLAND = "1",
  ELECTRON_OZONE_PLATFORM_HINT = "wayland",
  OZONE_PLATFORM = "wayland",

  XCURSOR_SIZE = "24",
  HYPRCURSOR_SIZE = "24",

  GTK_THEME = "Adwaita:dark",
}