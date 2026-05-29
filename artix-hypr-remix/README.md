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
- `config/hypr/hyprland.conf` is the runtime config consumed directly by Hyprland.
- `config/hypr/*.lua` are staging/source notes for future generation tooling.

Current installer milestone:
1. Run `./install.sh` on fresh Artix OpenRC.
2. Install package sets from `packages/00-*.txt` through `packages/80-*.txt`.
3. Enable safe OpenRC services from `services/openrc-default.txt`.
4. Deploy `config/` into the target user's `~/.config` using copy + timestamp backups, then initialize XDG user directories.
5. Configure tty1 login to start Hyprland for the target user.
6. Install AUR packages from `packages/90-*.txt` with safe `paru` bootstrap.

Phase 4 configuration strategy:
- Use Omarchy as a reference and rewrite configs for Artix OpenRC portability.
- Keep repo configs independent from Omarchy helper commands and systemd-only workflows.
- See `PHASE4_PORTING.md` for source mapping and adaptation rules.

Usage:

    ./install.sh

Useful options:

    ./install.sh --dry-run
    ./install.sh --phase 1
    ./install.sh --phase 2
    ./install.sh --phase 3 -y
    ./install.sh --phase 4 --user <username>
    ./install.sh --phase 5 --user <username>
    ./install.sh --phase 6 --user <username>
    ./install.sh --phase 6 --user <username> --skip-aur

Config dependency validation:

    ./scripts/check-config-deps.sh
    ./scripts/check-config-deps.sh --no-aur

Combined health check:

    ./scripts/doctor.sh
    ./scripts/doctor.sh --no-aur

Doctor note:
- `paru` is reported as optional and does not fail doctor checks by itself.

Emergency recovery (if keybinds do not load):

    sudo ./install.sh --phase 4 --user <username> -y

Notes:
- `packages/90-aur.txt` is consumed by phase 6.
- `services/openrc-boot.txt` is not managed by the desktop installer.
- Phase 4 always replaces existing target config paths with timestamp backups.
- Phase 4 runs `xdg-user-dirs-update` for the target user when available.
- Phase 5 manages a startup block in `~/.bash_profile` and `~/.zprofile` and launches Hyprland with `--config ~/.config/hypr/hyprland.conf`.
- Phase 6 bootstraps `paru` if missing, then installs AUR packages as the target non-root user.

Package policy:
1. Prefer Artix/pacman packages.
2. Use Flatpak for GUI apps that benefit from upstream distribution.
3. Use AUR only for packages unavailable through pacman or Flatpak.
4. Keep the default AUR list minimal.
