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

ensure_user_runtime_paths() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local state_root namespace_state user_bin

  state_root="$target_home/.local/state"
  namespace_state="$state_root/artix-hypr-remix"
  user_bin="$target_home/.local/bin"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would ensure user runtime paths and ownership"
    info "  - $state_root"
    info "  - $namespace_state"
    info "  - $user_bin"
    return 0
  fi

  install -d -m 0755 "$state_root" "$namespace_state" "$user_bin"
  chown "$target_user:$target_user" "$state_root" "$user_bin"
  chown -R "$target_user:$target_user" "$namespace_state"
}

create_first_run_mode_marker() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local state_dir first_run_mode
  local task_dir

  state_dir="$target_home/.local/state/artix-hypr-remix"
  task_dir="$state_dir/first-run.tasks"
  first_run_mode="$state_dir/first-run.mode"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would create first-run marker at $first_run_mode"
    info "Dry-run: would clear theme seed first-run done markers"
    return 0
  fi

  # Ensure the task dir exists — rm -f on a file inside a non-existent
  # directory returns non-zero even with -f, which would abort the install
  # under set -e.
  post_install_run_as_user "$target_user" install -d -m 0755 "$state_dir" "$task_dir"

  # Clear theme seed done markers before creating first-run.mode so the
  # seed re-runs on re-install.  First-run task stamps persist across
  # installs; without this, the first-run framework skips already-completed
  # tasks and the five Omarchy themes never get seeded on subsequent
  # installs.  The marker is created *after* cleanup so first-run.sh
  # cannot race in and see stale .done files.
  post_install_run_as_user "$target_user" rm -f "$task_dir/55-theme-default.sh.done" \
    "$task_dir/57-theme-omarchy-seed.sh.done" \
    "$state_dir/theme-omarchy-seed.done"

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
$target_user ALL=(ALL) NOPASSWD: /usr/bin/ufw
$target_user ALL=(ALL) NOPASSWD: /usr/bin/ufw-docker
$target_user ALL=(ALL) NOPASSWD: /usr/bin/rc-update
$target_user ALL=(ALL) NOPASSWD: /usr/bin/rc-service
$target_user ALL=(ALL) NOPASSWD: /usr/bin/gtk-update-icon-cache
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

install_command_namespace() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local namespace_installer

  namespace_installer="$target_home/.config/artix-hypr-remix/bin/namespace-install.sh"

  if [[ ! -f "$namespace_installer" ]]; then
    warn "Command namespace installer not found: $namespace_installer"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would install command namespace links via $namespace_installer"
    return 0
  fi

  post_install_run_as_user "$target_user" bash "$namespace_installer" --quiet
  info "Installed command namespace links into $target_home/.local/bin"
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

seed_omarchy_themes() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local install_script theme_dir env_file failed=0
  local -a themes=()

  themes=(nord catppuccin tokyo-night gruvbox rose-pine)

  # Dry-run before any capability guards so --dry-run --phase 7 shows
  # intent even when the framework isn't fully deployed yet.
  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would seed ${#themes[@]} Omarchy themes via ahr-theme-install-omarchy"
    printf '  - %s\n' "${themes[@]}"
    return 0
  fi

  # Read seed-control variables from user env without sourcing the file.
  # The env is user-writable and could contain arbitrary shell, so we
  # never source it as root.  Instead, sed extracts only the value
  # portion of lines matching ^export VAR= or ^VAR= — the file is
  # never executed.
  env_file="$target_home/.config/artix-hypr-remix/env"
  if [[ -f "$env_file" ]]; then
    local opt_out commit_pin
    opt_out=$(sed -n '/^export AHR_THEME_OMARCHY_SEED=/{s/^export AHR_THEME_OMARCHY_SEED=//;p;q}' "$env_file" 2>/dev/null || true)
    if [[ -z "$opt_out" ]]; then
      opt_out=$(sed -n '/^AHR_THEME_OMARCHY_SEED=/{s/^AHR_THEME_OMARCHY_SEED=//;p;q}' "$env_file" 2>/dev/null || true)
    fi
    opt_out="${opt_out#\"}"; opt_out="${opt_out%\"}"
    opt_out="${opt_out#\'}"; opt_out="${opt_out%\'}"
    case "$opt_out" in
      false|no|off|0)
        info "Omarchy theme seed disabled by AHR_THEME_OMARCHY_SEED in $env_file"
        return 0
        ;;
    esac

    commit_pin=$(sed -n '/^export OMARCHY_SEED_COMMIT=/{s/^export OMARCHY_SEED_COMMIT=//;p;q}' "$env_file" 2>/dev/null || true)
    if [[ -z "$commit_pin" ]]; then
      commit_pin=$(sed -n '/^OMARCHY_SEED_COMMIT=/{s/^OMARCHY_SEED_COMMIT=//;p;q}' "$env_file" 2>/dev/null || true)
    fi
    commit_pin="${commit_pin#\"}"; commit_pin="${commit_pin%\"}"
    commit_pin="${commit_pin#\'}"; commit_pin="${commit_pin%\'}"
    # commit_pin is used below — it is NOT exported here because
    # post_install_run_as_user uses sudo -H -u which resets the
    # environment.  Instead it is passed via env(1) in the command.
  fi

  install_script="$target_home/.config/artix-hypr-remix/bin/ahr-theme-install-omarchy"

  if [[ ! -f "$install_script" ]]; then
    info "Omarchy theme seed: ahr-theme-install-omarchy not found (skip)"
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    info "Omarchy theme seed: git not available (skip)"
    return 0
  fi

  info "Seeding ${#themes[@]} Omarchy themes during install (eliminates first-boot download)…"

  # Build command prefix for target-user execution.
  # When commit_pin is set, use env(1) to pass OMARCHY_BRANCH through
  # sudo -H -u which would otherwise strip it from the environment.
  local -a target_cmd_prefix=()
  if [[ -n "${commit_pin:-}" ]]; then
    target_cmd_prefix=(env "OMARCHY_BRANCH=$commit_pin")
  fi

  for theme in "${themes[@]}"; do
    theme_dir="$target_home/.config/artix-hypr-remix/themes/$theme"
    local -a extra_args=()

    # If the directory exists but is incomplete (missing colors.toml),
    # pass --force so ahr-theme-install-omarchy overwrites it rather
    # than refusing with "already exists".
    if [[ -d "$theme_dir" ]]; then
      if [[ -f "$theme_dir/colors.toml" ]]; then
        info "  ✓ Omarchy theme already present: $theme (skip)"
        continue
      fi
      warn "  ! Omarchy theme dir exists but is incomplete: $theme (will re-download)"
      extra_args=(--force)
    fi

    if post_install_run_as_user "$target_user" "${target_cmd_prefix[@]}" bash "$install_script" "${extra_args[@]}" "$theme" >/dev/null 2>&1; then
      info "  ✓ Omarchy theme seeded: $theme"
    else
      warn "  ✗ Omarchy theme failed: $theme (will retry on first login)"
      failed=$((failed + 1))
    fi
  done

  if [[ $failed -eq 0 ]]; then
    info "All ${#themes[@]} Omarchy themes seeded successfully."
  else
    warn "$failed/${#themes[@]} Omarchy themes failed to seed. First-run will retry."
  fi
}

prepare_post_install_framework() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  ensure_user_runtime_paths "$target_user" "$target_home" "$dry_run"
  create_first_run_mode_marker "$target_user" "$target_home" "$dry_run"
  write_first_run_sudoers "$target_user" "$dry_run"
  write_reboot_sudoers "$target_user" "$dry_run"
  initialize_migration_state "$target_user" "$target_home" "$dry_run"
  install_command_namespace "$target_user" "$target_home" "$dry_run"
  seed_omarchy_themes "$target_user" "$target_home" "$dry_run"
}
