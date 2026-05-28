#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

refresh_package_databases() {
  info "Refreshing pacman package databases"
  pacman -Sy --noconfirm
}

install_packages() {
  local pkgs=("$@")
  if [ "${#pkgs[@]}" -eq 0 ]; then return; fi
  info "Installing packages (${#pkgs[@]}): ${pkgs[*]}"
  pacman -S --needed --noconfirm "${pkgs[@]}"
}
