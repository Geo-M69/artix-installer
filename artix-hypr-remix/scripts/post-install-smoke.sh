#!/usr/bin/env bash
set -euo pipefail

STARTUP_MODE_STATE_REL=".local/state/artix-hypr-remix/startup.mode"
TTY_BLOCK_BEGIN="# >>> artix-hypr-remix tty hyprland >>>"

declare -a REQUIRED_COMMANDS=(id getent rc-update rc-service)
declare -a REQUIRED_SERVICES=(dbus elogind NetworkManager)

target_user="${SUDO_USER:-}"
target_home=""

identity_commands_ok=true
openrc_commands_ok=true
user_context_ready=false
startup_mode=""

declare -a failures=()
declare -a warnings=()

usage() {
  cat <<'EOF'
Usage: ./scripts/post-install-smoke.sh [options]

Validates critical post-install state for Artix Hypr Remix:
- Required commands are present
- Required OpenRC services are enabled in default runlevel and running
- Startup-mode state exists and is valid (tty|greetd)
- Session launcher exists and is executable
- Startup-mode specific wiring (tty managed block or greetd service/config)

Options:
  --user NAME   Target desktop user (default: SUDO_USER, else current non-root user)
  -h, --help    Show this help
EOF
}

pass() {
  printf 'PASS: %s\n' "$*"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures+=("$*")
}

warn_msg() {
  printf 'WARN: %s\n' "$*"
  warnings+=("$*")
}

service_enabled_in_default_runlevel() {
  local service="$1"
  [[ -e "/etc/runlevels/default/$service" ]]
}

check_required_commands() {
  local cmd

  echo "[1/5] Checking required commands"
  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      pass "command available: $cmd"
    else
      fail "missing required command: $cmd"
      case "$cmd" in
        id|getent) identity_commands_ok=false ;;
        rc-update|rc-service) openrc_commands_ok=false ;;
      esac
    fi
  done
}

resolve_target_user() {
  local current_user

  echo "[2/5] Resolving target desktop user"

  if [[ "$identity_commands_ok" != "true" ]]; then
    fail "cannot resolve target user because id/getent checks failed"
    return
  fi

  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    current_user="$(id -un)"
    if [[ "$current_user" != "root" ]]; then
      target_user="$current_user"
    fi
  fi

  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    fail "target user is required when running as root (use --user <name>)"
    return
  fi

  if ! id "$target_user" >/dev/null 2>&1; then
    fail "target user does not exist: $target_user"
    return
  fi

  target_home="$(getent passwd "$target_user" | cut -d: -f6)"
  if [[ -z "$target_home" || ! -d "$target_home" ]]; then
    fail "could not resolve a valid home directory for user: $target_user"
    return
  fi

  user_context_ready=true
  pass "target user resolved: $target_user ($target_home)"
}

check_required_openrc_services() {
  local service

  echo "[3/5] Validating required OpenRC services"

  if [[ "$openrc_commands_ok" != "true" ]]; then
    fail "cannot validate OpenRC services because rc-update/rc-service checks failed"
    return
  fi

  for service in "${REQUIRED_SERVICES[@]}"; do
    if [[ ! -x "/etc/init.d/$service" ]]; then
      fail "required service script missing: /etc/init.d/$service"
      continue
    fi

    pass "service script present: /etc/init.d/$service"

    if service_enabled_in_default_runlevel "$service"; then
      pass "service enabled in default runlevel: $service"
    else
      fail "service not enabled in default runlevel: $service"
    fi

    if rc-service "$service" status >/dev/null 2>&1; then
      pass "service running: $service"
    else
      fail "service not running: $service"
    fi
  done
}

check_startup_state_and_launcher() {
  local state_file
  local launcher

  echo "[4/5] Validating startup mode state + launcher"

  if [[ "$user_context_ready" != "true" ]]; then
    fail "cannot validate startup state because target user context is unavailable"
    return
  fi

  state_file="$target_home/$STARTUP_MODE_STATE_REL"
  if [[ ! -f "$state_file" ]]; then
    fail "startup mode state file missing: $state_file"
  else
    startup_mode="$(tr -d '[:space:]' < "$state_file")"
    case "$startup_mode" in
      tty|greetd)
        pass "startup mode state: $startup_mode"
        ;;
      *)
        fail "startup mode state is invalid ('$startup_mode'): $state_file"
        startup_mode=""
        ;;
    esac
  fi

  launcher="$target_home/.config/artix-hypr-remix/bin/start-hyprland-session.sh"
  if [[ ! -f "$launcher" ]]; then
    fail "session launcher missing: $launcher"
  elif [[ ! -x "$launcher" ]]; then
    fail "session launcher is not executable: $launcher"
  else
    pass "session launcher executable: $launcher"
  fi
}

check_mode_specific_state() {
  local profile
  local found_tty_block=false

  echo "[5/5] Validating mode-specific startup wiring"

  if [[ -z "$startup_mode" ]]; then
    fail "cannot run mode-specific checks because startup mode state is unavailable"
    return
  fi

  case "$startup_mode" in
    tty)
      for profile in "$target_home/.bash_profile" "$target_home/.zprofile"; do
        if [[ -f "$profile" ]] && grep -Fq "$TTY_BLOCK_BEGIN" "$profile"; then
          pass "tty startup block present in $profile"
          found_tty_block=true
        fi
      done

      if [[ "$found_tty_block" != "true" ]]; then
        fail "tty startup block missing from both ~/.bash_profile and ~/.zprofile"
      fi

      if service_enabled_in_default_runlevel "greetd"; then
        fail "greetd is still enabled in default runlevel while startup mode is tty"
      else
        pass "greetd not enabled in default runlevel for tty mode"
      fi

      if [[ "$openrc_commands_ok" == "true" ]] && [[ -x /etc/init.d/greetd ]]; then
        if rc-service greetd status >/dev/null 2>&1; then
          fail "greetd service is currently running while startup mode is tty"
        else
          pass "greetd service is not running in tty mode"
        fi
      fi
      ;;
    greetd)
      if [[ ! -x /etc/init.d/greetd ]]; then
        fail "greetd service script missing for greetd mode: /etc/init.d/greetd"
      else
        pass "greetd service script present"
      fi

      if service_enabled_in_default_runlevel "greetd"; then
        pass "greetd enabled in default runlevel"
      else
        fail "greetd not enabled in default runlevel"
      fi

      if [[ -f /etc/greetd/config.toml ]]; then
        pass "greetd config exists: /etc/greetd/config.toml"
      else
        fail "greetd config missing: /etc/greetd/config.toml"
      fi

      if [[ "$openrc_commands_ok" == "true" ]]; then
        if rc-service greetd status >/dev/null 2>&1; then
          pass "greetd service is running"
        else
          warn_msg "greetd service is not currently running (expected before reboot if installer deferred start)"
        fi
      fi
      ;;
  esac
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --user)
      shift
      [[ "$#" -gt 0 ]] || { echo "--user requires a value" >&2; exit 1; }
      target_user="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

check_required_commands
resolve_target_user
check_required_openrc_services
check_startup_state_and_launcher
check_mode_specific_state

echo
if [[ "${#warnings[@]}" -gt 0 ]]; then
  echo "Warnings:"
  printf '  - %s\n' "${warnings[@]}"
  echo
fi

if [[ "${#failures[@]}" -gt 0 ]]; then
  echo "Post-install smoke failed (${#failures[@]} checks)."
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi

echo "Post-install smoke passed."
