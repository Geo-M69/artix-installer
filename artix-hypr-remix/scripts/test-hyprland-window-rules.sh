#!/usr/bin/env bash
# Regression checks for AHR-owned Hyprland dialog placement rules.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HYPRLAND_CONFIG="$REPO_ROOT/config/hypr/hyprland.conf"

assert_exact_rule_once() {
  local rule="$1"
  local count

  count="$(grep -Fxc -- "$rule" "$HYPRLAND_CONFIG" || true)"
  if [[ "$count" -ne 1 ]]; then
    printf 'FAIL: expected exactly one Hyprland rule: %s (found %s)\n' "$rule" "$count" >&2
    exit 1
  fi
}

assert_exact_rule_once 'windowrule = match:class ^(hyprland-share-picker)$, float on'
assert_exact_rule_once 'windowrule = match:class ^(hyprland-share-picker)$, center on'

echo "Hyprland window-rule checks passed."
