# Theme Asset Guide

Artix Hypr Remix themes are plain directories that can live in AHR-native or Omarchy-compatible locations.

## Theme Search Paths

AHR discovers themes from these directories, in order:

- `~/.config/artix-hypr-remix/themes`
- `~/.config/artix-hypr-remix/default/themes`
- `~/.config/omarchy/themes`
- `${OMARCHY_PATH:-~/.local/share/omarchy}/themes`

Use `ahr theme list` to see what the current install can find.

## Theme Directory Layout

Recommended files:

- `colors.toml`: named colors used by AHR templates.
- `icons.theme`: icon theme name to apply when the theme is selected.
- `light.mode`: optional marker file for light themes.
- `backgrounds/`: one or more wallpaper images for `ahr theme bg-next`.
- `alacritty.toml`: optional source file for generating `colors.toml`.

Theme directories can include only the assets they need. Missing optional files should not block theme selection, but a theme without colors or backgrounds may look incomplete.

## Template Rendering

AHR renders app-specific files from templates under:

- `~/.config/artix-hypr-remix/themed`
- `~/.config/artix-hypr-remix/default/themed`

Current default templates cover Waybar, Mako, and Ghostty. Use `ahr theme set-templates` to render templates into a theme directory when building or repairing a theme.

## Theme State

Current theme state is stored under:

- `~/.config/artix-hypr-remix/current/theme.name`
- `~/.config/artix-hypr-remix/current/theme`
- `~/.config/artix-hypr-remix/current/background`

If a post-install check reports missing theme state, run:

```bash
ahr theme set nord
```

## Useful Commands

- `ahr theme list`: list discovered themes.
- `ahr theme current`: show the current theme.
- `ahr theme set <theme>`: apply a theme.
- `ahr theme refresh`: reapply the current theme and templates.
- `ahr theme bg-next`: cycle to the next background in the current theme.
- `ahr theme bg-set <path>`: set a specific background image.
