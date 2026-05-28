# artix-hypr-remix

Opinionated Artix Linux installer remix focused on Hyprland and OpenRC.

Structure:
- `install.sh` - top-level installer entrypoint (phase-based)
- `lib/` - helper scripts
- `packages/` - per-stage package lists
- `services/` - openrc service lists
- `config/` - source-of-truth config snippets (Hyprland source is Lua)
- `scripts/` - small helper scripts

Hypr config source:
- `config/hypr/*.lua` is the canonical source for Hypr session settings.
- Hyprlang files are not source-of-truth in this repository.

Current installer milestone:
1. Run `./install.sh` on fresh Artix OpenRC.
2. Install package sets from `packages/00-*.txt` through `packages/80-*.txt`.
3. Enable safe OpenRC services from `services/openrc-default.txt`.
4. Dotfiles linking and Hyprland TTY bootstrap are intentionally deferred.

Usage:

    ./install.sh

Useful options:

    ./install.sh --dry-run
    ./install.sh --phase 1
    ./install.sh --phase 2
    ./install.sh --phase 3 -y

Notes:
- `packages/90-aur.txt` is not part of the current phase set.
- `services/openrc-boot.txt` is not managed by the desktop installer.

Package policy:
1. Prefer Artix/pacman packages.
2. Use Flatpak for GUI apps that benefit from upstream distribution.
3. Use AUR only for packages unavailable through pacman or Flatpak.
4. Keep the default AUR list minimal.
