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
5. Configure startup mode for Hyprland (`tty` default or optional `greetd`).
6. Install AUR packages from `packages/90-*.txt` with safe `paru` bootstrap.
7. Prepare first-run/post-install framework, initialize migration state, and offer reboot prompt.

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
    ./install.sh --phase 5 --user <username> --startup-mode tty
    ./install.sh --phase 5 --user <username> --startup-mode greetd
    ./install.sh --phase 5 --user <username> --startup-mode greetd --greetd-mode autologin
    ./install.sh --phase 5 --user <username> --startup-mode greetd --greetd-mode greeter
    ./install.sh --phase 6 --user <username>
    ./install.sh --phase 6 --user <username> --skip-aur
    ./install.sh --phase 7 --user <username>

Config dependency validation:

    ./scripts/check-config-deps.sh
    ./scripts/check-config-deps.sh --no-aur

Combined health check:

    ./scripts/doctor.sh
    ./scripts/doctor.sh --no-aur

Framework smoke test (works on non-Artix hosts):

    ./scripts/smoke-framework.sh
    ./scripts/smoke-framework.sh --keep-sandbox

Doctor note:
- `paru` is reported as optional and does not fail doctor checks by itself.

Emergency recovery (if keybinds do not load):

    sudo ./install.sh --phase 4 --user <username> -y

Notes:
- `packages/90-aur.txt` is consumed by phase 6.
- `services/openrc-boot.txt` is not managed by the desktop installer.
- Phase 4 always replaces existing target config paths with timestamp backups.
- Phase 4 runs `xdg-user-dirs-update` for the target user when available.
- Phase 5 supports `--startup-mode tty|greetd` and uses `~/.config/artix-hypr-remix/bin/start-hyprland-session.sh` as the shared session launcher.
- When `--startup-mode greetd` is selected, `--greetd-mode autologin|greeter` controls immediate session launch vs greeter prompt (default: `greeter`).
- Phase 5 runs startup preflight checks before making mode changes; missing greetd prerequisites fail early on non-dry-run.
- In `--startup-mode greetd`, phase 5 attempts to install `greetd`, `greetd-openrc`, and the available tuigreet package variant (`greetd-tuigreet` or `tuigreet`).
- In `--startup-mode greetd`, phase 5 enables greetd for the next boot and does not start it immediately during installer execution.
- greetd config is generated on VT7 to avoid input collisions with tty1 getty prompts.
- Phase 6 bootstraps `paru` if missing, repairs AUR cache/state directory ownership, and installs AUR packages as the target non-root user.
- Phase 7 creates first-run state at `~/.local/state/artix-hypr-remix/first-run.mode`, installs scoped installer sudoers files, and initializes migration state under `~/.local/state/artix-hypr-remix/migrations`.
- Phase 7 installs native command namespace links into `~/.local/bin` and writes a small Omarchy-compatible alias layer.
- Phase 7 offers a reboot prompt (skipped when `--yes` is used) so first-run can execute immediately on next login.
- First user login runs `~/.config/artix-hypr-remix/bin/first-run.sh` from Hyprland autostart and then removes first-run marker state.
- Post-boot hook execution runs `~/.config/artix-hypr-remix/bin/hook.sh post-boot`, which includes automatic migration runner execution.
- Namespace specification and command inventory are documented in `COMMAND_NAMESPACE.md`.
- Startup architecture contract is documented in `STARTUP_ARCHITECTURE.md`.

Framework maintenance:

    ahr migrate --status
    ahr migrate --dry-run
    ahr migrate --retry-skipped

Upgrade workflow:

    ahr update
    ahr update --no-aur
    ahr update --flatpak
    ahr update --migrations-only
    ahr update --dry-run

Update status helper:

    ahr update-available
    ahr update-available --json

`ahr update-available` exit codes:
- `0` when updates or pending/skipped migrations are present
- `1` when everything is up to date

Command namespace:

    ~/.config/artix-hypr-remix/bin/namespace-install.sh
    ahr help

Package policy:
1. Prefer Artix/pacman packages.
2. Use Flatpak for GUI apps that benefit from upstream distribution.
3. Use AUR only for packages unavailable through pacman or Flatpak.
4. Keep the default AUR list minimal.
