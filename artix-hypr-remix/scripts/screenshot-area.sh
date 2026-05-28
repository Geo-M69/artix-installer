#!/usr/bin/env bash
set -euo pipefail
OUTDIR="$HOME/Pictures"
mkdir -p "$OUTDIR"
FNAME="$OUTDIR/screenshot-$(date +%s).png"
if command -v slurp >/dev/null 2>&1 && command -v grim >/dev/null 2>&1; then
  slurp | xargs grim -g > "$FNAME"
  echo "Saved $FNAME"
else
  echo "slurp or grim not available; cannot take area screenshot" >&2
  exit 1
fi
