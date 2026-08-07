# AHR doctor requirements

## Severity

- `FAIL` makes `ahr doctor` exit nonzero.
- `WARN` reports an actionable preference or optional component without failing doctor.

## Networking

A healthy OpenRC network stack has an active supported manager (NetworkManager or ConnMan) plus a non-loopback address. A default route is reported when available. Multiple active managers, or an inactive manager enabled in an OpenRC runlevel, are warnings; doctor never starts or stops services.

## Theme state

The current theme requires a readable `current/theme.name`, a matching source theme below `themes/` or `default/themes/`, a directory-based generated `current/theme` with matching `colors.toml` and `icons.theme`, and a background file or framework-contained symlink. Legacy theme symlinks are accepted only when they remain within the allowed theme roots.

## Video MIME defaults

A missing video default is a user-preference warning. Doctor does not choose or configure a player. A configured video desktop entry that cannot be found is also reported as an actionable warning.
