#!/usr/bin/env bash
# Phase 3 catalog-entry validation layer for the existing catalog applications.
#
# Default mode is fully offline and host-independent: it pins the recorded
# application-availability assumptions (identity, Flatpak ID, and catalog
# order) and the expected desktop-entry convention for every catalog entry.
#
# --live-flathub adds a strictly read-only live re-check of each catalog ID
# against the configured Flathub remote. It never bootstraps remotes, never
# installs or removes anything, and is never required by the offline gate, so
# synthetic and live evidence stay clearly separated.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${AHR_FLATPAK_CATALOG_PATH:-$REPO_ROOT/config/artix-hypr-remix/default/flatpak/catalog.json}"
CATALOG_LIB="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-flatpak-catalog-lib.sh"
FLATPAK_REMOTE="flathub"

# This is the recorded availability-assumption set: the exact catalog entries
# (slug and Flatpak ID, in catalog order) whose Flathub availability and
# system desktop entries were live-validated on 2026-09-05 on an Artix host
# with a system-scoped Flathub remote. See docs/ARCHITECTURE_CONTEXT.md.
# Changing any row is a visible product decision and requires a fresh live
# validation pass before the row is updated here.
expected_entries() {
  printf '%s\n' \
    'zen-browser|app.zen_browser.zen' \
    'flatseal|com.github.tchx84.Flatseal' \
    'warehouse|io.github.flattool.Warehouse' \
    'gear-lever|it.mijorus.gearlever' \
    'obs-studio|com.obsproject.Studio' \
    'discord|com.discordapp.Discord' \
    'vesktop|dev.vencord.Vesktop' \
    'obsidian|md.obsidian.Obsidian' \
    'spotify|com.spotify.Client' \
    'signal|org.signal.Signal' \
    'onlyoffice|org.onlyoffice.desktopeditors' \
    'easyeffects|com.github.wwmm.easyeffects' \
    'mission-center|io.missioncenter.MissionCenter'
}

PASS=0
FAIL=0
LIVE_REQUESTED=false
declare -a CATALOG_IDS=()

pass() { printf 'PASS: %s\n' "$1"; ((PASS+=1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; ((FAIL+=1)); }

usage() {
  cat <<'EOF'
Usage: ./scripts/validate-flatpak-catalog-entries.sh [options]

Validates the existing catalog entries against the recorded Phase 3
availability assumptions and the expected desktop-entry convention
(desktop_entry must equal "<flatpak-id>.desktop"). Offline by default.

Options:
  --live-flathub   Add a read-only live check that every catalog ID exists
                   on the configured Flathub remote. Never mutates Flatpak
                   state; requires flatpak and a configured flathub remote.
  -h, --help       Show this help
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --live-flathub)
      LIVE_REQUESTED=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

source "$CATALOG_LIB"

offline_validation() {
  local rows row
  local slug name flatpak_id category profile support proprietary unofficial desktop_entry
  local actual="" convention_mismatches=""

  if ahr_flatpak_catalog_validate "$CATALOG"; then
    pass "canonical catalog validates through the shared library"
  else
    fail "canonical catalog validates through the shared library"
    return
  fi

  if ! rows="$(ahr_flatpak_catalog_rows "$CATALOG")"; then
    fail "catalog rows resolve through the shared library"
    return
  fi

  while IFS= read -r row || [[ -n "$row" ]]; do
    [[ -n "$row" ]] || continue
    IFS=$'\t' read -r slug name flatpak_id category profile support proprietary unofficial desktop_entry <<< "$row"
    actual+="$slug|$flatpak_id"$'\n'
    CATALOG_IDS+=("$flatpak_id")
    if [[ "$desktop_entry" != "$flatpak_id.desktop" ]]; then
      convention_mismatches+="$slug: $desktop_entry (expected $flatpak_id.desktop)"$'\n'
    fi
  done <<< "$rows"
  actual="${actual%$'\n'}"

  if [[ "$actual" == "$(expected_entries)" ]]; then
    pass "catalog matches the pinned availability assumption set in order"
  else
    fail "catalog matches the pinned availability assumption set in order"
    printf 'Expected:\n%s\nActual:\n%s\n' "$(expected_entries)" "$actual" >&2
  fi

  if [[ -z "$convention_mismatches" ]]; then
    pass "every desktop entry follows the <flatpak-id>.desktop convention"
  else
    fail "every desktop entry follows the <flatpak-id>.desktop convention"
    printf 'Mismatches:\n%s' "$convention_mismatches" >&2
  fi
}

live_validation() {
  local checked_at missing=0 flatpak_id

  printf '\nLive Flathub evidence (read-only):\n'

  if ! command -v flatpak >/dev/null 2>&1; then
    printf 'ERROR: live validation requires the flatpak command; nothing was changed.\n' >&2
    return 1
  fi

  if ! flatpak remotes --columns=name 2>/dev/null | grep -Fxq "$FLATPAK_REMOTE"; then
    printf 'ERROR: the %s remote is not configured; this validator never bootstraps remotes.\n' \
      "$FLATPAK_REMOTE" >&2
    printf 'Configure Flathub (for example via ahr flatpak install or the installer profile) and re-run.\n' >&2
    return 1
  fi

  if ! REMOTE_APP_IDS="$(flatpak remote-ls --columns=application "$FLATPAK_REMOTE" 2>/dev/null)"; then
    printf 'ERROR: could not read the %s remote summary; nothing was changed.\n' \
      "$FLATPAK_REMOTE" >&2
    return 1
  fi

  checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for flatpak_id in "${CATALOG_IDS[@]}"; do
    if grep -Fxq "$flatpak_id" <<< "$REMOTE_APP_IDS"; then
      printf 'LIVE: %s available on %s\n' "$flatpak_id" "$FLATPAK_REMOTE"
    else
      printf 'LIVE: %s MISSING from %s\n' "$flatpak_id" "$FLATPAK_REMOTE" >&2
      missing=$((missing + 1))
    fi
  done

  if (( missing == 0 )); then
    pass "live: all ${#CATALOG_IDS[@]} catalog IDs are present on the current Flathub summary (checked $checked_at)"
  else
    fail "live: all ${#CATALOG_IDS[@]} catalog IDs are present on the current Flathub summary ($missing missing, checked $checked_at)"
  fi
}

printf 'Synthetic catalog-entry validation (offline):\n'
offline_validation

if [[ "$FAIL" -ne 0 ]]; then
  printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
  printf 'Live validation is skipped while synthetic validation fails.\n' >&2
  exit 1
fi

if [[ "$LIVE_REQUESTED" == "true" ]]; then
  live_validation
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
