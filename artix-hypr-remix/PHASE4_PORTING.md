# Phase 4 Omarchy Porting Notes

Goal:
- Curate repo-owned configs under `config/` using Omarchy as reference.
- Keep everything compatible with fresh Artix + OpenRC.
- Avoid runtime coupling to Omarchy helper scripts, UWSM wrappers, and systemd-specific behavior.

## Source Mapping

Hyprland:
- Source references:
  - `omarchy/config/hypr/*.lua`
  - `omarchy/default/hypr/envs.lua`
  - `omarchy/config/hypr/hyprlock.conf`
  - `omarchy/config/hypr/hypridle.conf`
  - `omarchy/config/hypr/xdph.conf`
- Ported into:
  - `config/hypr/hyprland.conf` (runtime)
  - `config/hypr/hyprland.lua`
  - `config/hypr/autostart.lua`
  - `config/hypr/env.lua`
  - `config/hypr/keybinds.lua`
  - `config/hypr/input.lua`
  - `config/hypr/looknfeel.lua`
  - `config/hypr/monitors.lua`
  - `config/hypr/hyprlock.conf`
  - `config/hypr/hypridle.conf`
  - `config/hypr/xdph.conf`

Important runtime note:
- Hyprland reads `config/hypr/hyprland.conf` at runtime.
- Lua files are currently design/source artifacts for future config generation.

Waybar:
- Source references:
  - `omarchy/config/waybar/config.jsonc`
  - `omarchy/config/waybar/style.css`
- Ported into:
  - `config/waybar/config.jsonc`
  - `config/waybar/style.css`

Walker:
- Source reference:
  - `omarchy/config/walker/config.toml`
- Ported into:
  - `config/walker/config.toml`

Ghostty:
- Source reference:
  - `omarchy/config/ghostty/config`
- Ported into:
  - `config/ghostty/config`

Starship:
- Source reference:
  - `omarchy/config/starship.toml`
- Ported into:
  - `config/starship/starship.toml`

Mako:
- Source reference:
  - `omarchy/default/themed/mako.ini.tpl`
- Ported into:
  - `config/mako/config`

Fontconfig:
- Source reference:
  - `omarchy/config/fontconfig/fonts.conf`
- Ported into:
  - `config/fontconfig/fonts.conf`

## Intentional Omissions

The following were intentionally removed to avoid dependency lock-in or OpenRC incompatibilities:
- `omarchy-*` command hooks
- Dynamic Omarchy theme imports (`~/.config/omarchy/current/...`)
- UWSM launch wrappers (`uwsm ...`)
- systemd user-service assumptions

## Dependency Alignment Rule

When adding or changing config commands:
1. Ensure command binaries exist in package lists under `packages/`.
2. If a command is optional, gate it in runtime shell scripts instead of hard failing session startup.
3. Prefer distro-neutral commands over Omarchy-specific wrappers.

## Next Steps

- Iterate each config file on real Artix hardware.
- Keep OpenRC service boundaries in installer phase 3.
- Keep phase 4 strictly about repo config quality and portability.
