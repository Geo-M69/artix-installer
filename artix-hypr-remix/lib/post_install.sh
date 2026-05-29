#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

FIRST_RUN_SUDOERS_FILE="/etc/sudoers.d/99-artix-hypr-remix-first-run"
REBOOT_SUDOERS_FILE="/etc/sudoers.d/99-artix-hypr-remix-installer-reboot"

post_install_run_as_user() {
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

  error "Neither sudo nor runuser is available to run commands as '$target_user'"
}

create_first_run_mode_marker() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local state_dir first_run_mode

  state_dir="$target_home/.local/state/artix-hypr-remix"
  first_run_mode="$state_dir/first-run.mode"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would create first-run marker at $first_run_mode"
    return 0
  fi

  post_install_run_as_user "$target_user" install -d -m 0755 "$state_dir"
  post_install_run_as_user "$target_user" touch "$first_run_mode"
  info "Enabled first-run mode marker: $first_run_mode"
}

write_first_run_sudoers() {
  local target_user="$1"
  local dry_run="${2:-false}"
  local temp_file

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install scoped first-run sudoers at $FIRST_RUN_SUDOERS_FILE"
    return 0
  fi

  temp_file="$(mktemp)"
  cat > "$temp_file" <<EOF
Cmnd_Alias FIRST_RUN_CLEANUP = /bin/rm -f $FIRST_RUN_SUDOERS_FILE
Cmnd_Alias REBOOT_CLEANUP = /bin/rm -f $REBOOT_SUDOERS_FILE
Cmnd_Alias DNS_STUB_SYMLINK = /usr/bin/ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
$target_user ALL=(ALL) NOPASSWD: /usr/bin/systemctl
$target_user ALL=(ALL) NOPASSWD: /usr/bin/ufw
$target_user ALL=(ALL) NOPASSWD: /usr/bin/ufw-docker
$target_user ALL=(ALL) NOPASSWD: /usr/bin/rc-update
$target_user ALL=(ALL) NOPASSWD: /usr/bin/rc-service
$target_user ALL=(ALL) NOPASSWD: /usr/bin/gtk-update-icon-cache
$target_user ALL=(ALL) NOPASSWD: DNS_STUB_SYMLINK
$target_user ALL=(ALL) NOPASSWD: FIRST_RUN_CLEANUP
$target_user ALL=(ALL) NOPASSWD: REBOOT_CLEANUP
EOF

  install -m 0440 "$temp_file" "$FIRST_RUN_SUDOERS_FILE"
  rm -f "$temp_file"
  info "Installed first-run sudoers rules: $FIRST_RUN_SUDOERS_FILE"
}

write_reboot_sudoers() {
  local target_user="$1"
  local dry_run="${2:-false}"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install reboot sudoers at $REBOOT_SUDOERS_FILE"
    return 0
  fi

  cat > "$REBOOT_SUDOERS_FILE" <<EOF
$target_user ALL=(ALL) NOPASSWD: /usr/bin/reboot
EOF
  chmod 0440 "$REBOOT_SUDOERS_FILE"
  info "Installed reboot sudoers rule: $REBOOT_SUDOERS_FILE"
}

prepare_post_install_framework() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  create_first_run_mode_marker "$target_user" "$target_home" "$dry_run"
  write_first_run_sudoers "$target_user" "$dry_run"
  write_reboot_sudoers "$target_user" "$dry_run"

  info "Post-install framework is ready for first user login"
}
