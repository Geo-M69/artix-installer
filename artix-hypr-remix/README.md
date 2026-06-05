# artix-hypr-remix

Opinionated Artix Linux installer remix focused on Hyprland and OpenRC.

Project target:
- An Artix OpenRC-native Omarchy-equivalent Hyprland desktop with a safe, repeatable installer and a polished first-login experience.

Supported base system:
- Artix Linux with OpenRC
- Fresh or minimal working base install with `pacman`, network access, and a non-root desktop user already created
- Installer shell: `bash`
- Supported user shells for startup wiring: `bash` and `zsh`
- Supported session flow: `tty` by default, optional `greetd`
- GPU support target: Intel, AMD, and NVIDIA through Artix/OpenRC-safe adaptations and hardware profile stubs

Out of scope for current beta work:
- systemd-based hosts
- display managers other than `greetd`
- a line-for-line Omarchy clone
- ISO/profile distribution work before the script installer is reliable
- unsupported hardware promises beyond tested Artix OpenRC paths

Structure:
- `install.sh` - top-level installer entrypoint (phase-based)
- `lib/` - helper scripts
- `packages/` - per-stage package lists
- `services/` - openrc service lists
- `config/` - source-of-truth config snippets (Hyprland source is Lua)
- `scripts/` - small helper scripts
- `ROADMAP.md` - milestone plan, beta path, blockers, and definition of done
- `MILESTONE3_KICKOFF.md` - prioritized Milestone 3 implementation checklist and validation plan
- `MILESTONE4_KICKOFF.md` - Omarchy-like UX parity checklist and validation plan
- `MILESTONE4_PARITY_AUDIT.md` - pinned Omarchy comparison table for Milestone 4
- `MILESTONE4_EXPECTED_RESULTS.md` - beta tester expected-results checklist
- `MILESTONE5_HANDOFF.md` - maintenance, repair, and upgrade follow-up notes
- `MILESTONE5_KICKOFF.md` - Milestone 5 maintenance and repair execution checklist
- `MIGRATION_POLICY.md` - migration safety, state, and recovery policy
- `RECOVERY_AND_RESET.md` - repair, rollback, backup, log, and reset boundaries
- `BETA_READINESS.md` - known issues, unsupported items, troubleshooting, and Milestone 6 inputs
- `config/artix-hypr-remix/docs/quick-reference.md` - installed first-login quick reference
- `config/artix-hypr-remix/docs/theme-assets.md` - installed AHR/Omarchy-compatible theme asset guide

Hypr config source:
- `config/hypr/hyprland.conf` is the runtime config consumed directly by Hyprland.
- `config/hypr/*.lua` are staging/source notes for future generation tooling.

Current installer milestone:
1. Run `sudo ./install.sh` on fresh Artix OpenRC from a non-root user shell.
2. Install package sets from `packages/00-*.txt` through `packages/80-*.txt`.
3. Apply detected hardware profile OpenRC modules from `config/hardware/<profile>/openrc-module.sh`.
4. Enable safe OpenRC services from `services/openrc-default.txt`.
5. Deploy `config/` into the target user's `~/.config` using copy + timestamp backups, then initialize XDG user directories.
6. Configure startup mode for Hyprland (`tty` default or optional `greetd`).
7. Install AUR packages and Flatpak app profiles (`flatpaks/default.txt` by default).
8. Prepare first-run/post-install framework, initialize migration state, and offer reboot prompt.
9. Optionally apply a guarded Git/GPG/SSH baseline for the target user (disabled by default).

Milestone 0 and 1 status:
- Support assumptions, beta scope, and intentional OpenRC direction are documented here and in `ROADMAP.md`.
- Phase 1 preflight now validates host policy, required commands, repo inputs, and target-user context when later phases need it.
- Phase 4 now asks before backing up and replacing existing user config unless `--yes` is used.
- Phase 7 now runs post-install smoke validation before offering the reboot prompt.

Validation and stabilization policy:
- Host policy defaults to Artix-only (`AHR_HOST_POLICY=artix`) for `./install.sh`, `./scripts/doctor.sh`, `./scripts/smoke-framework.sh`, and `./scripts/check-hardware.sh`.
- Use strict VM validation with `AHR_HOST_POLICY=vm` (requires Artix + virtualization).
- For maintenance-only exceptions, use `AHR_HOST_POLICY=any` (legacy `AHR_ALLOW_NON_VM_TESTING=1` still forces bypass).

Hardware detection v1:
- Phase 2 auto-detects basic hardware profiles (`nvidia`, `intel`, `amd`, `laptop`) and maps them to optional package stubs under `config/hardware/<profile>/packages.txt`.
- Phase 2 applies OpenRC-native hardware module actions from `config/hardware/<profile>/openrc-module.sh` when profile scripts are present.
- Optional Docker profile installs package set from `profiles/docker/packages.txt` when `--docker-profile on` is set.
- When `--docker-profile on` is set, phase 3 also attempts to enable/start the OpenRC `docker` service.
- Optional printing profile installs package set from `packages/profile-printing.txt` when `--printing-profile on` is set.
- When `--printing-profile on` is set, phase 3 also enables/starts printing OpenRC services from `services/openrc-printing.txt`.
- Default mode is `recommend`: installer prints detected profile packages and asks whether to install them.
- Use `--hardware-mode auto` to install detected profile packages without a prompt.
- Use `--hardware-mode off` to disable hardware profile package handling and OpenRC module actions.

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
- Installer phases 1-8 require root privileges.
- Running with `sudo` preserves `SUDO_USER`, so phases 4-8 can target your desktop user automatically.
- If you run from a root shell directly, pass `--user <username>` for phases 4-8.

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
    sudo ./install.sh --phase 2 --docker-profile on
    sudo ./install.sh --phase 3 --docker-profile on
    sudo ./install.sh --phase 2 --printing-profile on
    sudo ./install.sh --phase 3 --printing-profile on

Re-run guide (safe common cases):

    # Back up existing config without replacing it
    sudo ./install.sh --backup-only --user <username>

    # Re-apply config deployment (phase 4); creates timestamped backups first
    sudo ./install.sh --phase 4 --user <username> -y

    # Retry AUR/Flatpak installation (phase 6); skips already-installed packages
    sudo ./install.sh --phase 6 --user <username>

    # Retry AUR only
    sudo ./install.sh --phase 6 --user <username> --skip-flatpak

    # Retry Flatpak only
    sudo ./install.sh --phase 6 --user <username> --skip-aur

    # Re-run post-install framework repair (phase 7)
    sudo ./install.sh --phase 7 --user <username>

    # Resume with specific phase window
    sudo ./install.sh --from-phase 4 --phase 7 --user <username>

Additional phase 6 Flatpak profile examples:

    sudo ./install.sh --phase 6 --user <username> --flatpak-profile default
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile optional
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile all
    sudo ./install.sh --phase 6 --user <username> --flatpak-profile none

More examples:

    sudo ./install.sh --phase 7 --user <username>
    sudo ./install.sh --phase 8 --user <username> --dev-baseline on
    sudo ./install.sh --from-phase 6 --phase 7 --user <username>
    sudo ./install.sh --from-phase 8 --phase 8 --user <username> --dev-baseline on
    sudo ./install.sh --host-policy vm --phase 1
    AHR_INSTALL_STATE_DIR=/tmp/ahr-install-state sudo ./install.sh --phase 3
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
    ./scripts/check-docker-profile.sh
    ./scripts/milestone2-validate.sh --user <username>
    ./scripts/milestone2-validate.sh --user <username> --expect-printing on --host-id host-a --gpu-profile intel --startup-modes "tty,greetd"

Printing profile validation (host-independent dry-run):

    AHR_HOST_POLICY=any sudo ./install.sh --dry-run --from-phase 2 --phase 2 --printing-profile on -y
    AHR_HOST_POLICY=any sudo ./install.sh --dry-run --from-phase 3 --phase 3 --printing-profile on -y
    AHR_HOST_POLICY=any sudo ./install.sh --dry-run --from-phase 3 --phase 3 --printing-profile off -y

Post-install smoke validation:

    ./scripts/post-install-smoke.sh
    ./scripts/post-install-smoke.sh --user <username>
    ./scripts/post-install-smoke.sh --user <username> --expect-printing on
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
- `packages/90-*.txt` is the core AUR bucket consumed by phase 6 (fail-fast on install failure).
- `packages/9[1-9]-*.txt` is the optional AUR bucket consumed by phase 6 (warn-and-continue on install failure).
- `flatpaks/default.txt` and `flatpaks/optional.txt` are consumed by phase 6.
- Docker optional profile package manifest is `profiles/docker/packages.txt`.
- Printing optional profile package manifest is `packages/profile-printing.txt`.
- Printing optional profile OpenRC service manifest is `services/openrc-printing.txt`.
- Hardware profile package stubs are in `config/hardware/<profile>/packages.txt`.
- Hardware profile OpenRC modules are in `config/hardware/<profile>/openrc-module.sh`.
- `services/openrc-boot.txt` is not managed by the desktop installer.
- Installer preflight host policy supports `--host-policy artix|vm|any` (default: `artix`), and `AHR_HOST_POLICY` applies to helper validation scripts.
- `scripts/check-openrc-portability.sh` fails on runtime-path use of `systemctl`, `loginctl`, `journalctl`, `systemd-run`, and `/run/systemd`.
- `scripts/check-docker-profile.sh` verifies `--docker-profile` CLI coverage, phase 2 package injection, and phase 3 docker service toggle behavior.
- Installer state markers are persisted under `/var/lib/artix-hypr-remix/install-state` (`phase-<N>.started` and `phase-<N>.completed`), and resume windows can be selected with `--from-phase`.
- Phase 4 always replaces existing target config paths with timestamp backups.
- Phase 4 runs `xdg-user-dirs-update` for the target user when available.
- Phase 5 supports `--startup-mode tty|greetd` and uses `~/.config/artix-hypr-remix/bin/start-hyprland-session.sh` as the shared session launcher.
- When `--startup-mode greetd` is selected, `--greetd-mode autologin|greeter` controls immediate session launch vs greeter prompt (default: `greeter`).
- Phase 5 runs startup preflight checks before making mode changes; missing greetd prerequisites fail early on non-dry-run.
- In `--startup-mode greetd`, phase 5 attempts to install `greetd`, `greetd-openrc`, and the available tuigreet package variant (`greetd-tuigreet` or `tuigreet`).
- In `--startup-mode greetd`, phase 5 enables greetd for the next boot and does not start it immediately during installer execution.
- greetd config is generated on VT7 to avoid input collisions with tty1 getty prompts.
- `scripts/post-install-smoke.sh` validates required OpenRC service health (`dbus`, `elogind`, `NetworkManager`, `bluetoothd`), desktop runtime command dependencies (`polkit-gnome-authentication-agent-1`, `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`), active session runtime processes (`xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `pipewire`, `wireplumber`) when a Hyprland session is running, Hyprland runtime command dependencies (with optional warnings for `walker`/`elephant`), wallpaper backend availability (`swww` or `swaybg`), startup mode state, session launcher executable state, and mode-specific startup wiring. Use `--expect-printing on|off|auto` (default: `auto`) to control printing service checks.
- Milestone 2 real-host validation checklist is documented in `MILESTONE2_VALIDATION_MATRIX.md`.
- Hardware profile snapshots are written to `/var/lib/artix-hypr-remix/hardware-profile.json` when installer runs as root.
- Installer output is logged to `/var/log/artix-hypr-remix-install.log` by default (override with `AHR_INSTALL_LOG_FILE`, fallback under `/tmp` when needed).
- Package installation phases refresh and upgrade package databases in a full `pacman -Syu` transaction before package-specific installs (avoids `-Sy` partial upgrade risk).
- Phase 6 bootstraps `paru` if missing, repairs AUR cache/state directory ownership, and installs AUR packages as the target non-root user.
- Phase 6 installs Flatpak refs from `flatpaks/default.txt` by default (`--flatpak-profile optional|all|none` and `--skip-flatpak` are available).
- Flatpak refs are installed with system scope and Flathub remote bootstrap (`flathub`) when missing.
- Phase 7 creates first-run state at `~/.local/state/artix-hypr-remix/first-run.mode`, installs scoped installer sudoers files, and initializes migration state under `~/.local/state/artix-hypr-remix/migrations`.
- Phase 8 is optional and only applies when `--dev-baseline on` is set; it writes guarded managed blocks for `~/.ssh/config`, `~/.gnupg/gpg.conf`, and `~/.gnupg/gpg-agent.conf` with one-time backups (`*.ahr-dev-baseline.bak`) and preserves existing explicit git settings.
- Phase 7 installs native command namespace links into `~/.local/bin` and writes a small Omarchy-compatible alias layer.
- Phase 7 offers a reboot prompt (skipped when `--yes` is used) so first-run can execute immediately on next login.
- First user login runs `~/.config/artix-hypr-remix/bin/first-run.sh` from Hyprland autostart; task completion is tracked at `~/.local/state/artix-hypr-remix/first-run.tasks`, and the marker is only removed after all first-run steps succeed.
- Post-boot hook execution runs `~/.config/artix-hypr-remix/bin/hook.sh post-boot`, which includes automatic migration runner execution.
- Theme engine v1 stores state in `~/.config/artix-hypr-remix/current`, supports Omarchy theme assets, and can create a compatibility symlink at `~/.config/omarchy/current` when unused.
- Namespace specification and command inventory are documented in `COMMAND_NAMESPACE.md`.
- Startup architecture contract is documented in `STARTUP_ARCHITECTURE.md`.

Framework maintenance:

    ahr repair
    ahr repair --apply
    ahr repair --namespace
    ahr repair --theme --apply
    ahr repair --update-state
    ahr repair --config
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

Milestone 6 — Beta checklist, known issues, and support matrix

- Beta support matrix (frozen): [BETA_SUPPORT_MATRIX.md](BETA_SUPPORT_MATRIX.md)
- Milestone 6 beta checklist (draft): [MILESTONE6_BETA_CHECKLIST.md](MILESTONE6_BETA_CHECKLIST.md)
- Milestone 6 README draft: [MILESTONE6_README_DRAFT.md](MILESTONE6_README_DRAFT.md)
- Known issues and troubleshooting (draft): [MILESTONE6_KNOWN_ISSUES.md](MILESTONE6_KNOWN_ISSUES.md)
- Beta release notes (draft): [RELEASE_NOTES.md](RELEASE_NOTES.md)
