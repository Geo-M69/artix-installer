#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

PACMAN_REFRESHED=false

refresh_package_databases() {
  if [[ "$PACMAN_REFRESHED" == "true" ]]; then
    return 0
  fi

  info "Refreshing package databases and upgrading system packages"
  pacman -Syu --noconfirm
  PACMAN_REFRESHED=true
}

install_packages() {
  local pkgs=("$@")
  if [ "${#pkgs[@]}" -eq 0 ]; then return; fi
  info "Installing packages (${#pkgs[@]}): ${pkgs[*]}"
  pacman -S --needed --noconfirm "${pkgs[@]}"
}
