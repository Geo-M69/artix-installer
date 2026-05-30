#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true
source "$(dirname "${BASH_SOURCE[0]}")/openrc.sh" || true

TTY_BLOCK_BEGIN="# >>> artix-hypr-remix tty hyprland >>>"
TTY_BLOCK_END="# <<< artix-hypr-remix tty hyprland <<<"
STARTUP_MODE_STATE_REL=".local/state/artix-hypr-remix/startup.mode"

startup_session_launcher() {
  local target_home="$1"
  printf '%s/.config/artix-hypr-remix/bin/start-hyprland-session.sh' "$target_home"
}

tty_hyprland_block() {
  cat <<'EOF'
# >>> artix-hypr-remix tty hyprland >>>
if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]] && [[ -z "${SSH_TTY:-}" ]] && [[ "${XDG_VTNR:-0}" -eq 1 ]]; then
  session_launcher="$HOME/.config/artix-hypr-remix/bin/start-hyprland-session.sh"
  exec bash "$session_launcher"
fi
# <<< artix-hypr-remix tty hyprland <<<
EOF
}

write_managed_block() {
  local file_path="$1"
  local block_text="$2"
  local temp_file

  temp_file="$(mktemp)"
  awk -v begin="$TTY_BLOCK_BEGIN" -v end="$TTY_BLOCK_END" '
    $0 == begin { in_block=1; next }
    $0 == end { in_block=0; next }
    !in_block { print }
  ' "$file_path" > "$temp_file"

  printf '\n%s\n' "$block_text" >> "$temp_file"
  mv "$temp_file" "$file_path"
}

remove_managed_block() {
  local file_path="$1"
  local temp_file

  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  temp_file="$(mktemp)"
  awk -v begin="$TTY_BLOCK_BEGIN" -v end="$TTY_BLOCK_END" '
    $0 == begin { in_block=1; next }
    $0 == end { in_block=0; next }
    !in_block { print }
  ' "$file_path" > "$temp_file"

  mv "$temp_file" "$file_path"
}

ensure_tty_block_in_file() {
  local file_path="$1"
  local dry_run="${2:-false}"
  local block_text

  block_text="$(tty_hyprland_block)"

  if [[ "$dry_run" == "true" ]]; then
    if [[ -f "$file_path" ]] && grep -Fq "$TTY_BLOCK_BEGIN" "$file_path"; then
      info "Dry-run: would refresh managed tty block in $file_path"
    else
      info "Dry-run: would append managed tty block to $file_path"
    fi
    return 0
  fi

  touch "$file_path"
  write_managed_block "$file_path" "$block_text"
  info "Updated tty startup block in $file_path"
}

remove_tty_block_from_file() {
  local file_path="$1"
  local dry_run="${2:-false}"

  if [[ "$dry_run" == "true" ]]; then
    if [[ -f "$file_path" ]] && grep -Fq "$TTY_BLOCK_BEGIN" "$file_path"; then
      info "Dry-run: would remove managed tty block from $file_path"
    else
      info "Dry-run: no managed tty block present in $file_path"
    fi
    return 0
  fi

  remove_managed_block "$file_path"
  info "Removed tty startup block from $file_path"
}

configure_tty_hyprland_autostart() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  local profile
  local -a profiles=("$target_home/.bash_profile" "$target_home/.zprofile")

  for profile in "${profiles[@]}"; do
    ensure_tty_block_in_file "$profile" "$dry_run"
    if [[ "$dry_run" == "false" ]]; then
      chown "$target_user:$target_user" "$profile"
    fi
  done
}

remove_tty_hyprland_autostart() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  local profile
  local -a profiles=("$target_home/.bash_profile" "$target_home/.zprofile")

  for profile in "${profiles[@]}"; do
    remove_tty_block_from_file "$profile" "$dry_run"
    if [[ "$dry_run" == "false" && -f "$profile" ]]; then
      chown "$target_user:$target_user" "$profile"
    fi
  done
}

disable_greetd_service() {
  local dry_run="${1:-false}"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would remove greetd from OpenRC default runlevel and stop service"
    return 0
  fi

  if command -v rc-update >/dev/null 2>&1; then
    rc-update del greetd default >/dev/null 2>&1 || true
  fi

  if command -v rc-service >/dev/null 2>&1; then
    rc-service greetd stop >/dev/null 2>&1 || true
  fi
}

ensure_session_launcher_present() {
  local target_home="$1"
  local dry_run="${2:-false}"
  local launcher_path

  launcher_path="$(startup_session_launcher "$target_home")"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would verify session launcher at $launcher_path"
    return 0
  fi

  if [[ ! -f "$launcher_path" ]]; then
    error "Session launcher not found: $launcher_path"
  fi

  chmod 0755 "$launcher_path"
}

startup_mode_preflight() {
  local mode="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local launcher_path
  local detail
  local -a missing=()

  launcher_path="$(startup_session_launcher "$target_home")"

  if [[ ! -f "$launcher_path" ]]; then
    missing+=("session launcher: $launcher_path")
  fi

  case "$mode" in
    tty)
      ;;
    greetd)
      if [[ ! -x /etc/init.d/greetd ]]; then
        missing+=("OpenRC service: /etc/init.d/greetd")
      fi

      if ! command -v tuigreet >/dev/null 2>&1; then
        missing+=("command: tuigreet")
      fi
      ;;
    *)
      error "Unknown startup mode in preflight: $mode"
      ;;
  esac

  if (( ${#missing[@]} == 0 )); then
    info "Startup preflight ($mode): prerequisites satisfied"
    return 0
  fi

  warn "Startup preflight ($mode): missing prerequisites detected"
  for detail in "${missing[@]}"; do
    warn "  - $detail"
  done

  if [[ "$mode" == "greetd" ]]; then
    warn "Suggested packages: greetd greetd-openrc greetd-tuigreet (or tuigreet, depending on repository naming)"
  fi

  if [[ "$dry_run" == "true" ]]; then
    warn "Dry-run continues; non-dry-run would fail until prerequisites are installed"
    return 0
  fi

  error "Startup preflight ($mode) failed. Install missing prerequisites and retry."
}

ensure_greetd_prereqs() {
  if [[ ! -x /etc/init.d/greetd ]]; then
    error "greetd OpenRC service is missing (/etc/init.d/greetd). Install greetd with OpenRC service support before using --startup-mode greetd."
  fi

  if ! command -v tuigreet >/dev/null 2>&1; then
    error "tuigreet is missing. Install tuigreet before using --startup-mode greetd."
  fi
}

configure_greetd_hyprland_autostart() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local launcher_path
  local greetd_config

  launcher_path="$(startup_session_launcher "$target_home")"
  greetd_config="/etc/greetd/config.toml"

  ensure_session_launcher_present "$target_home" "$dry_run"

  if [[ "$dry_run" == "false" ]]; then
    ensure_greetd_prereqs
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would write greetd config to $greetd_config"
    info "Dry-run: would set greetd autologin session to $launcher_path"
  else
    install -d -m 0755 /etc/greetd

    cat > "$greetd_config" <<EOF
[terminal]
vt = 1

[initial_session]
command = "bash $launcher_path"
user = "$target_user"

[default_session]
command = "tuigreet --time --remember --remember-session --cmd 'bash $launcher_path'"
user = "greeter"
EOF

    chmod 0644 "$greetd_config"
    info "Configured greetd startup at $greetd_config"
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would enable greetd OpenRC service (start deferred until reboot)"
  else
    enable_service greetd default false
    info "Enabled greetd service for next boot (not started during installer run)"
  fi
}

write_startup_mode_state() {
  local target_user="$1"
  local target_home="$2"
  local mode="$3"
  local dry_run="${4:-false}"
  local state_file

  state_file="$target_home/$STARTUP_MODE_STATE_REL"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would write startup mode state '$mode' to $state_file"
    return 0
  fi

  install -d -m 0755 "$(dirname "$state_file")"
  printf '%s\n' "$mode" > "$state_file"
  chown "$target_user:$target_user" "$state_file"
}

configure_startup_mode() {
  local mode="$1"
  local target_user="$2"
  local target_home="$3"
  local dry_run="${4:-false}"

  case "$mode" in
    tty)
      ensure_session_launcher_present "$target_home" "$dry_run"
      disable_greetd_service "$dry_run"
      configure_tty_hyprland_autostart "$target_user" "$target_home" "$dry_run"
      write_startup_mode_state "$target_user" "$target_home" "$mode" "$dry_run"
      ;;
    greetd)
      configure_greetd_hyprland_autostart "$target_user" "$target_home" "$dry_run"
      remove_tty_hyprland_autostart "$target_user" "$target_home" "$dry_run"
      write_startup_mode_state "$target_user" "$target_home" "$mode" "$dry_run"
      ;;
    *)
      error "Unknown startup mode: $mode"
      ;;
  esac
}
