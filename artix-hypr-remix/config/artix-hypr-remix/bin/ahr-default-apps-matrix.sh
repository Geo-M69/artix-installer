#!/usr/bin/env bash
# ahr-default-apps-matrix.sh — single source of truth for AHR default
# applications and the MIME/default matrix.
#
# This file is sourced by:
#   - config/artix-hypr-remix/first-run.d/56-default-apps.sh (setup)
#   - config/artix-hypr-remix/bin/ahr-doctor             (validation)
#   - scripts/doctor.sh                                  (validation)
#   - scripts/post-install-smoke.sh                      (validation)
#   - scripts/test-default-apps.sh                       (tests)
#
# It must stay dependency-free: it is safe to source before ahr-lib.sh and
# does not require xdg-mime, the desktop, or any external command. Keep all
# logic POSIX-ish bash that works under `set -euo pipefail`.
#
# Design goals (Phase 2):
#   - One shared definition for setup and validation so they cannot drift.
#   - Idempotent: a configured handler is never overwritten.
#   - User choice preserved: any valid handler (native or Flatpak) is kept.
#   - Stale handlers (pointing at a missing desktop entry) are detectable.
#   - Desktop entries are discovered from system, user, and Flatpak roots.

# category -> ordered candidate desktop entries (most-preferred first).
# Candidates list BOTH the reverse-DNS GNOME app-id and any legacy alias so
# we never assume a single upstream filename.
declare -gA AHR_DEFAULT_APP_CANDIDATES=(
  [browser]="firefox.desktop zen.desktop chromium.desktop google-chrome.desktop brave-browser.desktop microsoft-edge.desktop"
  [directory]="org.gnome.Nautilus.desktop nautilus.desktop thunar.desktop org.kde.dolphin.desktop dolphin.desktop"
  [editor]="helix.desktop nvim.desktop vim.desktop"
  [pdf]="org.gnome.Evince.desktop evince.desktop"
  [image]="imv.desktop"
  [video]="mpv.desktop"
  [audio]="mpv.desktop"
  [archive]="org.gnome.FileRoller.desktop file-roller.desktop"
  [calculator]="org.gnome.Calculator.desktop gnome-calculator.desktop"
)

# Every MIME type AHR manages, mapped to its owning category. This is the
# canonical matrix: URL handling, HTML, directories, text, Markdown, PDF,
# common images, common video, common audio, and supported archives.
declare -gA AHR_MIME_CATEGORY=(
  [x-scheme-handler/http]="browser"
  [x-scheme-handler/https]="browser"
  [text/html]="browser"
  [inode/directory]="directory"
  [x-directory/normal]="directory"
  [text/plain]="editor"
  [text/markdown]="editor"
  [text/x-markdown]="editor"
  [application/pdf]="pdf"
  [image/png]="image"
  [image/jpeg]="image"
  [image/gif]="image"
  [image/webp]="image"
  [image/bmp]="image"
  [image/tiff]="image"
  [video/mp4]="video"
  [video/x-matroska]="video"
  [video/webm]="video"
  [video/x-msvideo]="video"
  [video/ogg]="video"
  [video/quicktime]="video"
  [audio/mpeg]="audio"
  [audio/flac]="audio"
  [audio/x-flac]="audio"
  [audio/x-wav]="audio"
  [audio/ogg]="audio"
  [audio/x-vorbis]="audio"
  [application/zip]="archive"
  [application/x-tar]="archive"
  [application/x-bzip]="archive"
  [application/x-bzip2]="archive"
  [application/gzip]="archive"
  [application/x-7z-compressed]="archive"
  [application/x-rar-compressed]="archive"
)

# Resolve desktop entries from system, user, and Flatpak application roots.
# Usage: ahr_matrix_desktop_entry_exists <desktop_id>
# Treats desktop-entry data as untrusted: only a plain filename match under a
# known prefix is accepted; no eval or path traversal.
ahr_matrix_desktop_entry_exists() {
  local desktop_id="$1"
  local path

  [[ -n "$desktop_id" && "$desktop_id" != *"/"* && "$desktop_id" == *.desktop ]] || return 1

  for path in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$desktop_id" \
    "$HOME/.local/share/flatpak/exports/share/applications/$desktop_id" \
    "/var/lib/flatpak/exports/share/applications/$desktop_id" \
    "/usr/local/share/applications/$desktop_id" \
    "/usr/share/applications/$desktop_id"; do
    [[ -f "$path" ]] && return 0
  done

  return 1
}

ahr_matrix_categories() {
  printf '%s\n' "${!AHR_DEFAULT_APP_CANDIDATES[@]}" | sort -u
}

ahr_matrix_mimes() {
  printf '%s\n' "${!AHR_MIME_CATEGORY[@]}" | sort -u
}

ahr_matrix_category_for_mime() {
  local mime="$1"
  printf '%s\n' "${AHR_MIME_CATEGORY[$mime]:-}"
}

ahr_matrix_candidates_for_category() {
  local cat="$1"
  printf '%s\n' "${AHR_DEFAULT_APP_CANDIDATES[$cat]:-}"
}

ahr_matrix_mimes_for_category() {
  local cat="$1" mime
  for mime in "${!AHR_MIME_CATEGORY[@]}"; do
    [[ "${AHR_MIME_CATEGORY[$mime]}" == "$cat" ]] && printf '%s\n' "$mime"
  done | sort -u
}

# Returns 0 if a valid (existing on disk) handler is configured for a MIME.
# Optional; does not require xdg-mime to be present (returns 1 if absent).
ahr_matrix_mime_handler_is_valid() {
  local mime="$1" current="" path

  command -v xdg-mime >/dev/null 2>&1 || return 1
  current="$(xdg-mime query default "$mime" 2>/dev/null || true)"
  current="${current#"${current%%[![:space:]]*}"}"
  current="${current%"${current##*[![:space:]]}"}"
  [[ -n "$current" ]] && ahr_matrix_desktop_entry_exists "$current"
}

# Returns the configured handler for a MIME (empty if none). Never fails.
ahr_matrix_current_handler() {
  local mime="$1" current=""
  command -v xdg-mime >/dev/null 2>&1 || { printf ''; return 0; }
  current="$(xdg-mime query default "$mime" 2>/dev/null || true)"
  current="${current#"${current%%[![:space:]]*}"}"
  current="${current%"${current##*[![:space:]]}"}"
  printf '%s' "$current"
}

# Assign the AHR default candidate for a category to every MIME it owns, but
# ONLY where no valid handler already exists. Idempotent and choice-preserving.
# Usage: ahr_matrix_apply_category <category>
ahr_matrix_apply_category() {
  local cat="$1" candidate mime applied=false had_valid=false

  command -v xdg-mime >/dev/null 2>&1 || return 1

  for candidate in ${AHR_DEFAULT_APP_CANDIDATES[$cat]:-}; do
    ahr_matrix_desktop_entry_exists "$candidate" || continue

    for mime in $(ahr_matrix_mimes_for_category "$cat"); do
      if ahr_matrix_mime_handler_is_valid "$mime"; then
        had_valid=true
        continue
      fi
      xdg-mime default "$candidate" "$mime" >/dev/null 2>&1 || true
      applied=true
    done

    if $applied || $had_valid; then
      if $applied; then
        echo "Default $cat set: $candidate"
      else
        echo "Default $cat preserved (valid handler already configured)"
      fi
      return 0
    fi
  done

  return 1
}

# Apply every pure-MIME category driven by the matrix. Browser, terminal,
# editor, directory, and calculator are handled by dedicated helpers in
# 56-default-apps.sh because they carry extra preference/state; this covers
# pdf, image, video, audio, and archive.
ahr_matrix_apply_pure_mime_categories() {
  local cat rc=1
  for cat in pdf image video audio archive; do
    if ahr_matrix_apply_category "$cat"; then
      rc=0
    fi
  done
  return $rc
}
