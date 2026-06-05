#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

# Temporary sudoers drop-in allowing the target user to run pacman without a
# password.  Installed before paru operations and removed after they complete.
AUR_SUDOERS_FILE="/etc/sudoers.d/99-artix-hypr-remix-aur"
# Track whether THIS invocation created the file, so we only clean up what
# we own and don't touch a pre-existing file from another run or user.
AUR_SUDOERS_CREATED=false

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

  # makepkg -i calls sudo pacman internally; install passwordless rule.
  aur_ensure_pacman_passwordless "$target_user" "$dry_run"

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

  # paru calls sudo pacman internally; install passwordless rule for the
  # duration of this phase so the desktop user isn't prompted repeatedly.
  aur_ensure_pacman_passwordless "$target_user" "$dry_run"

  info "Installing AUR packages (${#pkgs[@]}): ${pkgs[*]}"
  aur_paru_as_user "$target_user" "$target_home" paru -S --needed --noconfirm --skipreview "${pkgs[@]}"

  aur_remove_pacman_passwordless "$dry_run"
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

  # Each paru call triggers sudo pacman internally; install passwordless
  # rule for the duration of this phase.
  aur_ensure_pacman_passwordless "$target_user" "$dry_run"

  info "Installing optional AUR packages (${#pkgs[@]}): ${pkgs[*]}"
  for pkg in "${pkgs[@]}"; do
    if aur_paru_as_user "$target_user" "$target_home" paru -S --needed --noconfirm --skipreview "$pkg"; then
      continue
    fi

    warn "Optional AUR package '$pkg' failed to install; continuing"
    failed+=("$pkg")
  done

  aur_remove_pacman_passwordless "$dry_run"

  if [[ "${#failed[@]}" -gt 0 ]]; then
    warn "Optional AUR install finished with failures (${#failed[@]}): ${failed[*]}"
  else
    info "Optional AUR packages installed successfully"
  fi

  return 0
}

# Install a temporary sudoers drop-in so the target user can run "pacman"
# without a password.  paru (run as the desktop user) invokes "sudo pacman"
# internally for installation; this avoids prompting for the desktop user's
# password repeatedly during the AUR phase.
aur_ensure_pacman_passwordless() {
  local target_user="$1"
  local dry_run="${2:-false}"
  local temp_file expected_content

  # Validate username format — sudoers syntax breaks on special characters.
  if ! [[ "$target_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    error "Invalid target user '$target_user' for sudoers drop-in; refusing to write unvalidated content"
  fi

  # If a file already exists, check that it grants the right user pacman
  # access.  If it does, we can reuse it; if not, we replace it.
  if [[ -f "$AUR_SUDOERS_FILE" ]]; then
    if grep -qs "^$target_user\s\+ALL=(ALL)\s\+NOPASSWD:\s\+/usr/bin/pacman$" "$AUR_SUDOERS_FILE" 2>/dev/null; then
      AUR_SUDOERS_CREATED=false
      return 0
    fi
    warn "Existing sudoers file $AUR_SUDOERS_FILE does not match target user '$target_user'; overwriting"
    rm -f "$AUR_SUDOERS_FILE"
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install temporary pacman passwordless sudoers at $AUR_SUDOERS_FILE"
    return 0
  fi

  temp_file="$(mktemp)"
  cat > "$temp_file" <<EOF
# Installed by artix-hypr-remix AUR phase — removed automatically on completion.
$target_user ALL=(ALL) NOPASSWD: /usr/bin/pacman
EOF

  # Validate syntax before installing to avoid breaking sudo.
  if ! visudo -cf "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    error "Generated sudoers file failed validation for user '$target_user'"
  fi

  install -m 0440 "$temp_file" "$AUR_SUDOERS_FILE"
  rm -f "$temp_file"
  AUR_SUDOERS_CREATED=true
  info "Installed temporary pacman passwordless sudoers: $AUR_SUDOERS_FILE"
}

aur_remove_pacman_passwordless() {
  local dry_run="${1:-false}"

  # Only remove the file if we created it during THIS run.
  if [[ "$AUR_SUDOERS_CREATED" != "true" ]]; then
    return 0
  fi

  if [[ ! -f "$AUR_SUDOERS_FILE" ]]; then
    AUR_SUDOERS_CREATED=false
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would remove temporary pacman sudoers at $AUR_SUDOERS_FILE"
    return 0
  fi

  rm -f "$AUR_SUDOERS_FILE"
  AUR_SUDOERS_CREATED=false
  info "Removed temporary pacman sudoers: $AUR_SUDOERS_FILE"
}
