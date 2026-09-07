# Phase 3 OBS/Hyprland Portal Validation

Date: 2026-09-06
Host: `geoartix`, Artix Linux/OpenRC, laptop panel `eDP-1`

## Result

The reported OBS termination was not reproduced in two controlled runs. Both a
direct system-scoped Flatpak run and the current repository AHR launch path
completed source selection, received an `eDP-1` PipeWire node, rendered a live
OBS preview, and exited cleanly. The evidence does not justify an AHR crash
workaround or a change to the Flatpak launcher.

A separate AHR window-rule defect was reproduced: the picker identifies itself
to Hyprland as class `hyprland-share-picker`, while AHR only floated the GTK
portal class. Because AHR also floats the OBS window, the tiled picker could
open underneath OBS. AHR now floats and centers the picker by its observed
class.

The post-fix live run completed the full acceptance flow: the picker surfaced
focused and centered, `eDP-1` selection reached `streaming`, the preview was
visible, and OBS recorded for more than ten seconds without exiting. The
Phase 3 portal blocker is cleared for the current AHR tree on this host. A
recurrence of the original intermittent assertion/termination remains an
upstream interoperability watch item and should be captured with a backtrace;
it is not evidence for an AHR workaround by itself.

## Versions

- OBS Studio Flatpak: 32.2.2, commit
  `21b35765922fb5c8b92ccdccedc0d8ca709b12f86a961780350199082da822ef`,
  `org.freedesktop.Platform//25.08`
- OBS Flatpak PipeWire client library/header: 1.4.9
- Flatpak: 1.18.2
- Hyprland: 0.56.1, commit
  `5c9377c15f85c50648f35ca5a213754f95b93ca0`
- xdg-desktop-portal: 1.22.1
- xdg-desktop-portal-hyprland and bundled `hyprland-share-picker`: 1.4.1
- PipeWire server: 1.6.8
- WirePlumber: 0.5.17
- Host Mesa: 26.2.2; OBS Flatpak Mesa extension: 26.1.6
- Kernel: 7.2.2-artix1-1.1

## Controlled observations

### Installed AHR command

The installed framework snapshot was older than the current Phase 3 working
tree and returned `Unknown command: flatpak`. This is deployment/version drift,
not a portal crash. The current repository command was exercised without
installing it by setting `AHR_FRAMEWORK_ROOT` to the repository framework.

### Direct Flatpak control

Command:

```bash
flatpak run --system com.obsproject.Studio
```

Observed result:

- The picker exposed class `hyprland-share-picker` and title
  `Select what to share`.
- Selecting `eDP-1` returned a successful ScreenCast response with
  `mapping_id=eDP-1`, source type monitor, size 1920x1080, and PipeWire node
  100.
- OBS reached `streaming`; a captured screenshot showed the recursive live
  desktop preview.
- OBS exited normally with status 0.

### Current AHR launcher

Command shape:

```bash
AHR_FRAMEWORK_ROOT=/path/to/repo/config/artix-hypr-remix \
  ahr flatpak launch obs-studio
```

The launcher validated the catalog entry and desktop export, then invoked the
same `flatpak run --system com.obsproject.Studio` primitive. A saved restore
token initialized the first stream. Reopening source selection and selecting
`eDP-1` replaced it successfully. OBS again reached `streaming`, rendered the
preview, and exited normally with status 0.

After injecting the repository picker rules into the live compositor, the
acceptance run through this launcher produced
`/home/geo/2026-09-06 17-14-33.mp4`: 10.5 seconds, 1280x720 at 30 fps, H.264
video with AAC audio, 8,098,691 bytes. OBS finalized 317 output frames, then
exited with status 0 and reported no memory leaks. The front portal, GTK
portal, and Hyprland backend remained alive after OBS exited.

### Portal and graphics interaction

The traced Hyprland backend received valid request/session object paths and
returned valid ScreenCast responses. OBS rejected two AMD DMA-BUF modifiers
with `Cannot create EGLImage: Arguments are inconsistent`; the backend logged
`DMA-BUF fixation failed after 2 attempts`, fell back to shared-memory buffers,
and continued streaming. No portal daemon exited.

No `g_variant_is_object_path`, `g_variant_new_object_path`, GLib assertion,
segmentation signal, or core dump occurred in either controlled run. The
reported assertion/crash signature and the observed DMA-BUF negotiation path
match known upstream OBS/Hyprland-portal interoperability reports, but the
original termination cannot be assigned to one upstream component without a
backtrace from a failing run.

### Journal and core evidence

This OpenRC installation has neither `journalctl` nor `coredumpctl`. Portal
process output had been attached to `/dev/tty7`, so historical daemon stderr was
not recoverable; the controlled AHR run therefore restarted only the three
user-session portal processes under file-backed trace capture. The shell core
limit was zero during the reported failure. The only core file found was an
unrelated 2026-09-05 Xwayland core.

## Root-cause assessment

- **Picker placement — AHR defect, high confidence.** The live picker class did
  not match any AHR rule; adding rules for the observed class immediately made
  it floating, centered, and focused.
- **Catalog launcher — not causal, high confidence.** The current AHR path
  reaches the same system-scoped Flatpak primitive as the direct control, and
  both completed the same portal flow.
- **AHR portal configuration — not causal, high confidence.** The only AHR
  backend setting is the restore-token default. The trace showed valid D-Bus
  object paths and successful portal responses before graphics negotiation.
- **Original OBS termination — upstream interaction probable, moderate
  confidence; exact component low confidence.** The controlled runs repeatedly
  exposed OBS/Mesa rejecting DMA-BUF modifiers, followed by the Hyprland
  backend's successful shared-memory fallback. Without a failing backtrace, it
  is not possible to distinguish an OBS client fault from a portal/PipeWire/
  graphics-stack interaction.

The reported GLib object-path assertion has appeared in an earlier
[xdg-desktop-portal-hyprland/OBS crash report](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/239).
OBS has also tracked a crash during PipeWire format renegotiation after an
EGLImage failure in [OBS issue 9733](https://github.com/obsproject/obs-studio/issues/9733),
and newer reports continue to show the same DMA-BUF-to-SHM path in
[OBS issue 13318](https://github.com/obsproject/obs-studio/issues/13318) and
[XDPH issue 403](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/403).
These comparisons support the upstream-interaction classification but do not
prove the cause of the uncaptured original exit.

## AHR change and regression

`config/hypr/hyprland.conf` now contains exact `float` and `center` rules for
class `hyprland-share-picker`. Before the rules, live `hyprctl` state reported
`floating=false` and the picker was obscured by floating OBS. With the proposed
rules injected temporarily, the picker was focused, `floating=true`, and
centered at logical coordinates 10,38 with size 1260x672 on the scaled laptop
work area. `scripts/test-hyprland-window-rules.sh` pins both rules and runs in
the quality gate.

## Recurrence action

If OBS terminates again, preserve stderr and run it with a debugger/core limit
that can produce a backtrace. Include the OBS log and a simultaneous verbose
Hyprland-backend trace in an upstream report. The current evidence is enough to
validate AHR's portal path, but not to name the exact upstream component that
caused the earlier intermittent termination.
