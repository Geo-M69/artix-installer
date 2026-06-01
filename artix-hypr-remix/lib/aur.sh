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

ensure_aur_user_dirs() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local cache_root state_root paru_state build_root

  cache_root="$target_home/.cache"
  state_root="$target_home/.local/state"
  paru_state="$state_root/paru"
  build_root="$cache_root/artix-hypr-remix"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would ensure AUR state/cache directories are user-owned"
    info "  - $cache_root"
    info "  - $state_root"
    info "  - $paru_state"
    info "  - $build_root"
    return 0
  fi

  install -d -m 0755 "$cache_root" "$state_root" "$paru_state" "$build_root"
  chown -R "$target_user:$target_user" "$build_root" "$paru_state"
  chown "$target_user:$target_user" "$cache_root" "$state_root"
}

aur_paru_as_user() {
  local target_user="$1"
  local target_home="$2"
  shift 2

  aur_run_as_user "$target_user" env \
    HOME="$target_home" \
    XDG_CACHE_HOME="$target_home/.cache" \
    XDG_STATE_HOME="$target_home/.local/state" \
    "${@}"
}

ensure_paru_bootstrap() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local build_root paru_source

  ensure_aur_user_dirs "$target_user" "$target_home" "$dry_run"

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

  rm -rf "$paru_source"
  aur_run_as_user "$target_user" git clone https://aur.archlinux.org/paru.git "$paru_source"
  aur_run_as_user "$target_user" bash -lc "cd '$paru_source' && makepkg -si --noconfirm --needed"

  command -v paru >/dev/null 2>&1 || error "paru bootstrap failed"
}

install_aur_packages() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="$3"
  shift 3
  local pkgs=("$@")

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi

  ensure_aur_user_dirs "$target_user" "$target_home" "$dry_run"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install AUR packages (${#pkgs[@]}): ${pkgs[*]}"
    return 0
  fi

  info "Installing AUR packages (${#pkgs[@]}): ${pkgs[*]}"
  aur_paru_as_user "$target_user" "$target_home" paru -S --needed --noconfirm --skipreview "${pkgs[@]}"
}

install_aur_packages_optional() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="$3"
  shift 3
  local pkgs=("$@")
  local pkg
  local -a failed=()

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi

  ensure_aur_user_dirs "$target_user" "$target_home" "$dry_run"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install optional AUR packages (${#pkgs[@]}): ${pkgs[*]}"
    return 0
  fi

  info "Installing optional AUR packages (${#pkgs[@]}): ${pkgs[*]}"
  for pkg in "${pkgs[@]}"; do
    if aur_paru_as_user "$target_user" "$target_home" paru -S --needed --noconfirm --skipreview "$pkg"; then
      continue
    fi

    warn "Optional AUR package '$pkg' failed to install; continuing"
    failed+=("$pkg")
  done

  if [[ "${#failed[@]}" -gt 0 ]]; then
    warn "Optional AUR install finished with failures (${#failed[@]}): ${failed[*]}"
  else
    info "Optional AUR packages installed successfully"
  fi

  return 0
}
