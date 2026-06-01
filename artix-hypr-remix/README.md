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
1. Run `sudo ./install.sh` on fresh Artix OpenRC from a non-root user shell.
2. Install package sets from `packages/00-*.txt` through `packages/80-*.txt`.
3. Enable safe OpenRC services from `services/openrc-default.txt`.
4. Deploy `config/` into the target user's `~/.config` using copy + timestamp backups, then initialize XDG user directories.
5. Configure startup mode for Hyprland (`tty` default or optional `greetd`).
6. Install AUR packages and Flatpak app profiles (`flatpaks/default.txt` by default).
7. Prepare first-run/post-install framework, initialize migration state, and offer reboot prompt.

Validation and stabilization policy:
- Host policy defaults to Artix-only (`AHR_HOST_POLICY=artix`) for `./install.sh`, `./scripts/doctor.sh`, `./scripts/smoke-framework.sh`, and `./scripts/check-hardware.sh`.
- Use strict VM validation with `AHR_HOST_POLICY=vm` (requires Artix + virtualization).
- For maintenance-only exceptions, use `AHR_HOST_POLICY=any` (legacy `AHR_ALLOW_NON_VM_TESTING=1` still forces bypass).

Hardware detection v1:
- Phase 2 auto-detects basic hardware profiles (`nvidia`, `intel`, `amd`, `laptop`) and maps them to optional package stubs under `config/hardware/<profile>/packages.txt`.
- Default mode is `recommend`: installer prints detected profile packages and asks whether to install them.
- Use `--hardware-mode auto` to install detected profile packages without a prompt.
- Use `--hardware-mode off` to disable hardware profile package handling.

Phase 4 configuration strategy:
- Use Omarchy as a reference and rewrite configs for Artix OpenRC portability.
- Keep repo configs independent from Omarchy helper commands and systemd-only workflows.
- See `PHASE4_PORTING.md` for source mapping and adaptation rules.

Usage:

Quick install (fresh Artix OpenRC):

    git clone https://github.com/<you>/artix-installer.git
    cd artix-installer/artix-hypr-remix
    sudo ./install.sh

Install command notes:
- Installer phases 1-7 require root privileges.
- Running with `sudo` preserves `SUDO_USER`, so phases 4-7 can target your desktop user automatically.
- If you run from a root shell directly, pass `--user <username>` for phases 4-7.

Usage (from `artix-hypr-remix/`):

    sudo ./install.sh

Useful options:

    sudo ./install.sh --dry-run
    sudo ./install.sh --phase 1
    sudo ./install.sh --phase 2
    sudo ./install.sh --phase 3 -y
    sudo ./install.sh --phase 4 --user <username>
    sudo ./install.sh --phase 5 --user <username>
    sudo ./install.sh --phase 5 --user <username> --startup-mode tty
    sudo ./install.sh --phase 5 --user <username> --startup-mode greetd
    sudo ./install.sh --phase 5 --user <username> --startup-mode greetd --greetd-mode autologin
    sudo ./install.sh --phase 5 --user <username> --startup-mode greetd --greetd-mode greeter
    sudo ./install.sh --phase 2 --hardware-mode recommend
    sudo ./install.sh --phase 2 --hardware-mode auto
    sudo ./install.sh --phase 2 --hardware-mode off
    sudo ./install.sh --phase 6 --user <username>
    sudo ./install.sh --phase 6 --user <username> --skip-aur
    sudo ./install.sh --phase 6 --user <username> --skip-flatpak
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile default
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile optional
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile all
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile none
    sudo ./install.sh --phase 7 --user <username>
    sudo ./install.sh --host-policy vm --phase 1
    AHR_INSTALL_LOG_FILE=/tmp/ahr-install.log sudo ./install.sh
    AHR_HOST_POLICY=vm ./scripts/doctor.sh

Config dependency validation:

    ./scripts/check-config-deps.sh
    ./scripts/check-config-deps.sh --no-aur

Combined health check:

    ./scripts/doctor.sh
    ./scripts/doctor.sh --no-aur

Phase 2 quality gate (host-independent):

    ./scripts/quality-gate.sh
    ./scripts/quality-gate.sh --no-aur

Install local pre-push hook (runs quality gate automatically):

    ./scripts/install-git-hooks.sh

CI enforcement:

- GitHub Actions workflow `.github/workflows/artix-hypr-remix-quality-gate.yml` runs quality gate on push and pull requests affecting `artix-hypr-remix/**`.
- GitHub Actions workflow `.github/workflows/artix-hypr-remix-framework-smoke.yml` runs the framework smoke test in CI with `AHR_HOST_POLICY=any` on `ubuntu-latest`.

Targeted validation helpers:

    ./scripts/check-openrc-portability.sh
    ./scripts/check-first-run-idempotency.sh

Post-install smoke validation:

    ./scripts/post-install-smoke.sh
    ./scripts/post-install-smoke.sh --user <username>
    sudo ./scripts/post-install-smoke.sh --user <username>

Hardware detection check:

    ./scripts/check-hardware.sh
    ./scripts/check-hardware.sh /tmp/hardware-profile.json

Framework smoke test:

    ./scripts/smoke-framework.sh
    ./scripts/smoke-framework.sh --keep-sandbox

Doctor note:
- `paru` is reported as optional and does not fail doctor checks by itself.

Emergency recovery (if keybinds do not load):

    sudo ./install.sh --phase 4 --user <username> -y

Notes:
- `packages/90-aur.txt` is consumed by phase 6.
- `flatpaks/default.txt` and `flatpaks/optional.txt` are consumed by phase 6.
- Hardware profile package stubs are in `config/hardware/<profile>/packages.txt`.
- `services/openrc-boot.txt` is not managed by the desktop installer.
- Installer preflight host policy supports `--host-policy artix|vm|any` (default: `artix`), and `AHR_HOST_POLICY` applies to helper validation scripts.
- Phase 4 always replaces existing target config paths with timestamp backups.
- Phase 4 runs `xdg-user-dirs-update` for the target user when available.
- Phase 5 supports `--startup-mode tty|greetd` and uses `~/.config/artix-hypr-remix/bin/start-hyprland-session.sh` as the shared session launcher.
- When `--startup-mode greetd` is selected, `--greetd-mode autologin|greeter` controls immediate session launch vs greeter prompt (default: `greeter`).
- Phase 5 runs startup preflight checks before making mode changes; missing greetd prerequisites fail early on non-dry-run.
- In `--startup-mode greetd`, phase 5 attempts to install `greetd`, `greetd-openrc`, and the available tuigreet package variant (`greetd-tuigreet` or `tuigreet`).
- In `--startup-mode greetd`, phase 5 enables greetd for the next boot and does not start it immediately during installer execution.
- greetd config is generated on VT7 to avoid input collisions with tty1 getty prompts.
- `scripts/post-install-smoke.sh` validates required OpenRC service health (`dbus`, `elogind`, `NetworkManager`), startup mode state, session launcher executable state, and mode-specific startup wiring.
- Hardware profile snapshots are written to `/var/lib/artix-hypr-remix/hardware-profile.json` when installer runs as root.
- Installer output is logged to `/var/log/artix-hypr-remix-install.log` by default (override with `AHR_INSTALL_LOG_FILE`, fallback under `/tmp` when needed).
- Package installation phases refresh and upgrade package databases in a full `pacman -Syu` transaction before package-specific installs (avoids `-Sy` partial upgrade risk).
- Phase 6 bootstraps `paru` if missing, repairs AUR cache/state directory ownership, and installs AUR packages as the target non-root user.
- Phase 6 installs Flatpak refs from `flatpaks/default.txt` by default (`--flatpak-profile optional|all|none` and `--skip-flatpak` are available).
- Flatpak refs are installed with system scope and Flathub remote bootstrap (`flathub`) when missing.
- Phase 7 creates first-run state at `~/.local/state/artix-hypr-remix/first-run.mode`, installs scoped installer sudoers files, and initializes migration state under `~/.local/state/artix-hypr-remix/migrations`.
- Phase 7 installs native command namespace links into `~/.local/bin` and writes a small Omarchy-compatible alias layer.
- Phase 7 offers a reboot prompt (skipped when `--yes` is used) so first-run can execute immediately on next login.
- First user login runs `~/.config/artix-hypr-remix/bin/first-run.sh` from Hyprland autostart; task completion is tracked at `~/.local/state/artix-hypr-remix/first-run.tasks`, and the marker is only removed after all first-run steps succeed.
- Post-boot hook execution runs `~/.config/artix-hypr-remix/bin/hook.sh post-boot`, which includes automatic migration runner execution.
- Theme engine v1 stores state in `~/.config/artix-hypr-remix/current`, supports Omarchy theme assets, and can create a compatibility symlink at `~/.config/omarchy/current` when unused.
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

Theme workflow:

    ahr theme list
    ahr theme set artix-dark
    ahr theme current
    ahr theme bg-next
    ahr theme refresh

Package policy:
1. Prefer Artix/pacman packages.
2. Use Flatpak for GUI apps that benefit from upstream distribution.
3. Use AUR only for packages unavailable through pacman or Flatpak.
4. Keep the default AUR list minimal.
