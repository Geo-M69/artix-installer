#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

install_aur() {
  local pkg="$1"
  info "Installing AUR package: $pkg"
  paru -S --noconfirm "$pkg"
}
