# Milestone 2 Validation Matrix (Artix/OpenRC)

This checklist tracks completion evidence for Milestone 2 in `ROADMAP.md`.

## Scope

Milestone 2 goals:
- Validate package manifests on real Artix repositories.
- Confirm OpenRC service and runtime flows for base components.
- Confirm no systemd-only runtime assumptions remain.
- Add service-specific doctor/smoke checks.

## Required Host Matrix

Run on real Artix OpenRC hosts:

- Host A: Intel desktop or laptop
- Host B: AMD desktop or laptop
- Host C: NVIDIA desktop or laptop

Optional but recommended:

- Host D: VM with greetd mode
- Host E: laptop with power management profile

For each host, run both startup modes where possible:

- `tty`
- `greetd` (`greeter` and `autologin` at least once across matrix)

## Pre-Validation Commands

From repo root:

```bash
cd artix-hypr-remix
./scripts/quality-gate.sh
```

On target host after install:

```bash
./scripts/doctor.sh
./scripts/post-install-smoke.sh --user <username>
./scripts/milestone2-validate.sh --user <username>
```

If printing profile is installed:

```bash
./scripts/post-install-smoke.sh --user <username> --expect-printing on
./scripts/milestone2-validate.sh --user <username> --expect-printing on
```

## Milestone 2 Evidence Checklist

### 1) Package Manifest Validation

- [ ] `install.sh --phase 2` succeeds on each host without package-name edits.
- [ ] `packages/00-core.txt` resolves fully on Artix mirrors.
- [ ] `packages/10-hyprland.txt` portal packages resolve fully.
- [ ] `packages/60-network-openrc.txt` OpenRC/network/bluetooth packages resolve fully.
- [ ] Optional printing profile package manifest resolves (`packages/profile-printing.txt`).

Record per-host notes:

- Host:
- Mirror:
- Missing/renamed packages:
- Resolution:

### 2) OpenRC Service Behavior Validation

Required services (default profile):
- `dbus`
- `elogind`
- `NetworkManager`
- `bluetoothd`

Optional printing services (when profile enabled):
- `cupsd`
- `avahi-daemon`

Checks:

- [ ] Present under `/etc/init.d`.
- [ ] Added to default runlevel.
- [ ] Running after install and reboot.
- [ ] `rc-update` and `rc-service` operations behave as expected on each host.

### 3) Runtime Flow Validation

- [ ] Polkit agent binary present (`polkit-gnome-authentication-agent-1`).
- [ ] Portal binaries present (`xdg-desktop-portal`, `xdg-desktop-portal-hyprland`).
- [ ] Hyprland startup mode wiring stable in `tty` mode.
- [ ] Hyprland startup mode wiring stable in `greetd` mode.

### 4) Portability Guard Validation

- [ ] `./scripts/check-openrc-portability.sh` passes.
- [ ] No runtime-path use of blocked systemd commands.

### 5) Doctor/Smoke Coverage Validation

- [ ] `doctor.sh` checks required OpenRC services and desktop runtime commands.
- [ ] `post-install-smoke.sh` checks required OpenRC services including bluetooth.
- [ ] `post-install-smoke.sh` validates optional printing services when expected.

## Signoff Criteria

Milestone 2 is complete when:

- All required checklist items above are marked complete.
- No unresolved package naming mismatches remain for supported hosts.
- Required services are verified on real hardware in at least three GPU classes.
- Validation results are linked from release notes/README known issues.

## Validation Log Template

Use this block per host:

```text
Host ID:
Date:
GPU/Profile:
Startup mode tested:
Install command:
Doctor result:
Post-install smoke result:
Printing expected (on/off/auto):
OpenRC service anomalies:
Package manifest anomalies:
Portal/polkit anomalies:
Final status: PASS|FAIL
Follow-ups:
```

## Validation Results

### Entry 1: Artix VM (PASS)

```text
Host ID: geoartix
Date: 2026-06-03T14:50:31Z
GPU/Profile: not recorded (VM)
Startup mode tested: unknown
Install command: not recorded
Doctor result: PASS (issues: 0)
Post-install smoke result: PASS (issues: 0, warnings: 0)
Printing expected (on/off/auto): auto
OpenRC service anomalies:
none
Package manifest anomalies:
none
Portal/polkit anomalies:
none
Final status: PASS
Follow-ups: none
```

### Entry 2: NVIDIA Laptop (pending)

```text
Host ID: <fill>
Date: <fill>
GPU/Profile: nvidia laptop
Startup mode tested: <fill>
Install command: <fill>
Doctor result: <fill>
Post-install smoke result: <fill>
Printing expected (on/off/auto): auto
OpenRC service anomalies:
<fill>
Package manifest anomalies:
<fill>
Portal/polkit anomalies:
<fill>
Final status: <fill>
Follow-ups: run milestone2-validate with --gpu-profile "nvidia laptop" and record startup mode coverage
```
