#!/usr/bin/env bash
set -euo pipefail

# Source user env if available (Hyprland exec-once does not inherit shell rc).
env_file="${XDG_CONFIG_HOME:-$HOME/.config}/artix-hypr-remix/env"
[[ -f "$env_file" ]] && source "$env_file"

# ── Config ─────────────────────────────────────────────────────────
# Set AHR_THEME_OMARCHY_SEED=false to skip automatic seeding entirely.
# Set OMARCHY_SEED_COMMIT to a specific commit hash for reproducible
# checkouts (e.g., export OMARCHY_SEED_COMMIT="abc123def").
AHR_THEME_OMARCHY_SEED="${AHR_THEME_OMARCHY_SEED:-true}"

if [[ "$AHR_THEME_OMARCHY_SEED" != "true" ]]; then
  echo "Omarchy theme seed disabled by AHR_THEME_OMARCHY_SEED=false"
  exit 0
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix"
SEED_DONE="$STATE_DIR/theme-omarchy-seed.done"

# ── Best-effort one-shot ───────────────────────────────────────────
# This seed runs exactly once on first login.  If any theme download
# fails or the network is unreachable the remainder are a miss —
# themes are always installable later via the menu
# (Style → Install Omarchy Theme…).  The done marker exists so the
# seed doesn't retry; the first-run framework already handles
# re-entry through its own task-stamp mechanism.
if [[ -f "$SEED_DONE" ]]; then
  echo "Omarchy theme seed already attempted."
  exit 0
fi

install_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-install-omarchy"

if [[ ! -x "$install_cmd" ]]; then
  echo "Skipping Omarchy theme seed: ahr-theme-install-omarchy not found"
  exit 0
fi

# ── Network check ──────────────────────────────────────────────────
has_network() {
  if command -v curl >/dev/null 2>&1; then
    curl -s --max-time 5 https://github.com >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=5 --spider https://github.com >/dev/null 2>&1
  else
    return 1
  fi
}

mkdir -p "$STATE_DIR"

if ! has_network; then
  echo "Skipping Omarchy theme seed: no network connectivity"
  touch "$SEED_DONE"
  exit 0
fi

# ── Notify start ───────────────────────────────────────────────────
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Artix Hypr Remix" "Installing popular Omarchy themes…" -u low
fi

# ── Install themes ─────────────────────────────────────────────────
# If OMARCHY_SEED_COMMIT is set, export OMARCHY_BRANCH so that
# ahr-theme-install-omarchy fetches that specific commit instead of
# the mutable 'dev' branch.  OMARCHY_BRANCH must be overridable; the
# underlying script changed to ${OMARCHY_BRANCH:-dev} in the same pass.
if [[ -n "${OMARCHY_SEED_COMMIT:-}" ]]; then
  export OMARCHY_BRANCH="$OMARCHY_SEED_COMMIT"
fi

themes=(nord catppuccin tokyo-night gruvbox rose-pine)
failed=0

for theme in "${themes[@]}"; do
  # Skip themes already present (e.g., nord was seeded by 55-theme-default.sh).
  if [[ -d "$HOME/.config/artix-hypr-remix/themes/$theme" ]]; then
    continue
  fi
  if ! "$install_cmd" "$theme" >/dev/null 2>&1; then
    printf 'Failed to install theme: %s\n' "$theme" >&2
    failed=$((failed + 1))
  fi
done

# Always mark attempted so the seed doesn't retry — the menu handles
# any missing themes.
touch "$SEED_DONE"

# ── Apply the preferred default theme ─────────────────────────────
# If the preferred theme was successfully installed (and is not already
# active), apply it now. This also handles the case where
# 55-theme-default.sh ran before us and fell back to the fallback theme.
if [[ $failed -lt ${#themes[@]} ]]; then
  preferred="${AHR_DEFAULT_THEME:-nord}"
  theme_setter="$HOME/.config/artix-hypr-remix/bin/ahr-theme-set"
  theme_current="$HOME/.config/artix-hypr-remix/bin/ahr-theme-current"
  if [[ -x "$theme_setter" && -x "$theme_current" ]]; then
    current="$("$theme_current" --raw 2>/dev/null || true)"
    if [[ "$current" != "$preferred" ]]; then
      # Only apply if the preferred theme is actually available now.
      list_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-theme-list"
      if "$list_cmd" --raw 2>/dev/null | grep -qxF "$preferred"; then
        "$theme_setter" --quiet "$preferred" 2>/dev/null && echo "Applied $preferred after seeding" || true
      fi
    fi
  fi
fi

if [[ $failed -eq 0 ]]; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Artix Hypr Remix" "Omarchy themes ready: Nord, Catppuccin, Tokyo Night, Gruvbox, Rose Pine" -u low
  fi
else
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Artix Hypr Remix" "Some Omarchy themes failed to install. Use the menu to try again." -u low
  fi
fi
