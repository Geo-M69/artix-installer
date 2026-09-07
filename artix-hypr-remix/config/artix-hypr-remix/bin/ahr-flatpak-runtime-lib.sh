#!/usr/bin/env bash
# Shared system-scoped Flatpak operations for installer and runtime commands.

AHR_FLATPAK_COMMAND="${AHR_FLATPAK_COMMAND:-flatpak}"
AHR_FLATPAK_REMOTE="flathub"
AHR_FLATPAK_REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
AHR_FLATPAK_SYSTEM_APPLICATIONS_DIR="${AHR_FLATPAK_SYSTEM_APPLICATIONS_DIR:-/var/lib/flatpak/exports/share/applications}"

ahr_flatpak_require_command() {
  command -v "$AHR_FLATPAK_COMMAND" >/dev/null 2>&1
}

ahr_flatpak_system_ref_installed() {
  local flatpak_id="$1"
  "$AHR_FLATPAK_COMMAND" info --system "$flatpak_id" >/dev/null 2>&1
}

ahr_flatpak_system_flathub_configured() {
  "$AHR_FLATPAK_COMMAND" remotes --system --columns=name 2>/dev/null |
    grep -Fxq "$AHR_FLATPAK_REMOTE"
}

ahr_flatpak_system_add_flathub() {
  "$AHR_FLATPAK_COMMAND" remote-add --if-not-exists --system \
    "$AHR_FLATPAK_REMOTE" "$AHR_FLATPAK_REMOTE_URL"
}

ahr_flatpak_system_install() {
  local flatpak_id="$1"
  "$AHR_FLATPAK_COMMAND" install --system --noninteractive \
    "$AHR_FLATPAK_REMOTE" "$flatpak_id"
}

ahr_flatpak_system_uninstall() {
  local flatpak_id="$1"
  "$AHR_FLATPAK_COMMAND" uninstall --system --noninteractive "$flatpak_id"
}

ahr_flatpak_system_update() {
  (( $# > 0 )) || return 0
  "$AHR_FLATPAK_COMMAND" update --system "$@"
}

ahr_flatpak_system_run() {
  local flatpak_id="$1"
  "$AHR_FLATPAK_COMMAND" run --system "$flatpak_id"
}

ahr_flatpak_system_desktop_entry_path() {
  local desktop_entry="$1"
  local desktop_path="$AHR_FLATPAK_SYSTEM_APPLICATIONS_DIR/$desktop_entry"

  [[ -f "$desktop_path" ]] || return 1
  printf '%s\n' "$desktop_path"
}
