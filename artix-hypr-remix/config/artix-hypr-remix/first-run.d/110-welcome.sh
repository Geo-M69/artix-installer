#!/usr/bin/env bash
set -euo pipefail

if ! command -v notify-send >/dev/null 2>&1; then
  echo "Skipping welcome notification: notify-send not found"
  exit 0
fi

# Session-scoped guard — use XDG_RUNTIME_DIR (tmpfs, cleaned on logout)
# so the health tip fires at most once per login session.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/artix-hypr-remix-runtime}"
HEALTH_NOTIFIED="$RUNTIME_DIR/first-run.health-notified"

# Main welcome notification — essential keybindings to get started.
notify-send "Welcome to Artix Hypr Remix" \
  "Super + Space  Main menu\nSuper + K      Keybinding help\nSuper + Return Terminal\nSuper + P      Clipboard picker\nPrint           Screenshot picker\n\nLearn menu has docs, theme help, and quick reference." \
  -u critical

# Follow-up health tip (delayed so desktop is fully settled).
# Guard is written *before* spawning the background subshell to avoid
# a race if this script runs twice within the sleep window.
if [[ ! -f "$HEALTH_NOTIFIED" ]]; then
  mkdir -p "$(dirname "$HEALTH_NOTIFIED")"
  touch "$HEALTH_NOTIFIED"

  (
    sleep 12
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -u low "Artix Hypr Remix — health tip" \
"Run 'ahr status' to inspect install state and log paths.
Run 'ahr repair --dry-run' to check for fixable issues.
Run 'ahr doctor' for a full health report." \
        -i dialog-information
    fi
  ) &
  disown
fi
