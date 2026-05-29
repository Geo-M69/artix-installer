#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

FIRST_RUN_SUDOERS_FILE="/etc/sudoers.d/99-artix-hypr-remix-first-run"
REBOOT_SUDOERS_FILE="/etc/sudoers.d/99-artix-hypr-remix-installer-reboot"
MIGRATION_STATE_DIR_SUFFIX=".local/state/artix-hypr-remix/migrations"
MIGRATION_CONFIG_DIR_SUFFIX=".config/artix-hypr-remix/migrations"

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

initialize_migration_state() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local migration_state_dir migration_skipped_dir migration_config_dir migration_file migration_name

  migration_state_dir="$target_home/$MIGRATION_STATE_DIR_SUFFIX"
  migration_skipped_dir="$migration_state_dir/skipped"
  migration_config_dir="$target_home/$MIGRATION_CONFIG_DIR_SUFFIX"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would initialize migration state at $migration_state_dir"
    return 0
  fi

  post_install_run_as_user "$target_user" install -d -m 0755 "$migration_state_dir" "$migration_skipped_dir"

  if [[ -d "$migration_config_dir" ]]; then
    shopt -s nullglob
    for migration_file in "$migration_config_dir"/*.sh; do
      migration_name="$(basename "$migration_file")"
      post_install_run_as_user "$target_user" touch "$migration_state_dir/$migration_name"
    done
    shopt -u nullglob
  fi

  info "Initialized migration state: $migration_state_dir"
}

finish_post_install() {
  local target_user="$1"
  local dry_run="${2:-false}"
  local assume_yes="${3:-false}"
  local response

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would show post-install completion prompt"
    return 0
  fi

  info "Post-install framework is ready for first user login"
  info "First-run will execute as '$target_user' on the next Hyprland session"

  if [[ "$assume_yes" == "true" ]]; then
    info "Skipping reboot prompt because --yes was provided"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    warn "No interactive terminal detected; skipping reboot prompt"
    return 0
  fi

  if command -v gum >/dev/null 2>&1; then
    if gum confirm "Reboot now to trigger first-run setup?"; then
      info "Rebooting now"
      reboot
    fi
    return 0
  fi

  read -r -p "Reboot now to trigger first-run setup? [y/N]: " response
  case "${response,,}" in
    y|yes)
      info "Rebooting now"
      reboot
      ;;
    *)
      info "Reboot skipped. Run 'reboot' manually when ready."
      ;;
  esac
}

prepare_post_install_framework() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  create_first_run_mode_marker "$target_user" "$target_home" "$dry_run"
  write_first_run_sudoers "$target_user" "$dry_run"
  write_reboot_sudoers "$target_user" "$dry_run"
  initialize_migration_state "$target_user" "$target_home" "$dry_run"
}
