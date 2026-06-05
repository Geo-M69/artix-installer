# README (Milestone 6 draft)

artix-hypr-remix — Artix OpenRC-native Hyprland installer (README draft for beta)

Short summary
- Opinionated installer that configures a Hyprland desktop on Artix Linux (OpenRC). The installer is phase-based and idempotent; phases 4–8 target a non-root desktop user.

Supported base system
- Artix Linux with OpenRC
- Fresh or minimal Artix base install with `pacman` and network access
- Non-root desktop user already created
- Supported shells: `bash`, `zsh`
- Startup modes: `tty` (default) and optional `greetd`

Quick install

```bash
git clone https://github.com/<you>/artix-installer.git
cd artix-installer/artix-hypr-remix
sudo ./install.sh    # use --dry-run to preview
```

Core validation and recovery commands

- Run the quality gate locally: `./scripts/quality-gate.sh`
- Post-install smoke (as user): `./scripts/post-install-smoke.sh --user <username>`
- Repair preview: `ahr repair`
- Safe repair apply (after review): `ahr repair --apply`
- Migration status: `ahr migrate --status`
- Update dry-run: `ahr update --dry-run`

Where to look for logs and state
- Installer log: `/var/log/artix-hypr-remix-install.log`
- Installer state markers: `/var/lib/artix-hypr-remix/install-state`
- Hardware snapshot: `/var/lib/artix-hypr-remix/hardware-profile.json`
- User runtime state: `~/.local/state/artix-hypr-remix/`

Beta checklist and release notes
- See the Milestone 6 beta checklist: `MILESTONE6_BETA_CHECKLIST.md` (draft)
- Known issues and troubleshooting: `MILESTONE6_KNOWN_ISSUES.md` (draft)

Notes
- The project intentionally avoids systemd-only assumptions (no systemctl/loginctl usage in installer paths).
- AUR packages are optional by default; phase 6 installs AUR manifests only when configured.
