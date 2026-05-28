#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

aur_run_as_user() {
  local target_user="$1"
  shift

  if command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$target_user" "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- "$@"
    return
  fi

  error "Neither sudo nor runuser is available to run AUR builds as '$target_user'"
}

ensure_paru_bootstrap() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local build_root paru_source

  if command -v paru >/dev/null 2>&1; then
    info "paru is already installed"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would bootstrap paru using AUR under user '$target_user'"
    return 0
  fi

  info "Bootstrapping paru AUR helper"
  pacman -S --needed --noconfirm base-devel git

  build_root="$target_home/.cache/artix-hypr-remix"
  paru_source="$build_root/paru"
  install -d -m 0755 "$build_root"
  chown -R "$target_user:$target_user" "$build_root"

  rm -rf "$paru_source"
  aur_run_as_user "$target_user" git clone https://aur.archlinux.org/paru.git "$paru_source"
  aur_run_as_user "$target_user" bash -lc "cd '$paru_source' && makepkg -si --noconfirm --needed"

  command -v paru >/dev/null 2>&1 || error "paru bootstrap failed"
}

install_aur_packages() {
  local target_user="$1"
  local dry_run="$2"
  shift 2
  local pkgs=("$@")

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install AUR packages (${#pkgs[@]}): ${pkgs[*]}"
    return 0
  fi

  info "Installing AUR packages (${#pkgs[@]}): ${pkgs[*]}"
  aur_run_as_user "$target_user" paru -S --needed --noconfirm --skipreview "${pkgs[@]}"
}
