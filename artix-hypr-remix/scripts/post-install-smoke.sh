#!/usr/bin/env bash
set -euo pipefail

STARTUP_MODE_STATE_REL=".local/state/artix-hypr-remix/startup.mode"
TTY_BLOCK_BEGIN="# >>> artix-hypr-remix tty hyprland >>>"

declare -a REQUIRED_COMMANDS=(id getent rc-update rc-service)
declare -a REQUIRED_SERVICES=(dbus elogind NetworkManager bluetoothd)
declare -a REQUIRED_DESKTOP_COMMANDS=(
  polkit-gnome-authentication-agent-1
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
)
declare -a PRINTING_SERVICES=(cupsd avahi-daemon)
declare -A OPTIONAL_HYPR_COMMANDS=(
  [walker]=1
  [elephant]=1
)

declare -A hypr_commands_seen=()

target_user="${SUDO_USER:-}"
target_home=""

identity_commands_ok=true
openrc_commands_ok=true
user_context_ready=false
startup_mode=""
expect_printing="auto"

declare -a failures=()
declare -a warnings=()

usage() {
  cat <<'EOF'
Usage: ./scripts/post-install-smoke.sh [options]

Validates critical post-install state for Artix Hypr Remix:
- Required commands are present
- Required OpenRC services are enabled in default runlevel and running
- Hyprland runtime command dependencies are available (with optional-command warnings)
- Startup-mode state exists and is valid (tty|greetd)
- Session launcher exists and is executable
- Startup-mode specific wiring (tty managed block or greetd service/config)

Options:
  --user NAME   Target desktop user (default: SUDO_USER, else current non-root user)
  --expect-printing MODE  Printing validation mode: auto (default), on, or off
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

service_script_present() {
  local service="$1"
  [[ -x "/etc/init.d/$service" ]]
}

trim_whitespace() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

normalize_first_token() {
  local command_line="$1"
  local token

  command_line="${command_line%%|*}"
  command_line="$(trim_whitespace "$command_line")"

  # Drop leading env assignment (e.g. FOO=bar cmd).
  while [[ "$command_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
    command_line="${command_line#*=}"
    command_line="$(trim_whitespace "$command_line")"
  done

  token="${command_line%%[[:space:]]*}"
  token="${token#\"}"
  token="${token%\"}"
  token="${token#\'}"
  token="${token%\'}"

  printf '%s' "$token"
}

track_hypr_command_line() {
  local command_line="$1"
  local token

  token="$(normalize_first_token "$command_line")"
  [[ -z "$token" ]] && return 0

  case "$token" in
    if|then|else|fi|for|while|do|done|case|esac|"[["|true|false|return|export|source|alias|command|eval|builtin|activate|"#"*)
      return 0
      ;;
  esac

  [[ "$token" == '$'* ]] && return 0
  hypr_commands_seen["$token"]=1
}

hypr_command_is_available() {
  local command_token="$1"

  if [[ "$command_token" == */* ]]; then
    [[ -x "$command_token" ]]
    return $?
  fi

  command -v "$command_token" >/dev/null 2>&1
}

check_required_commands() {
  local cmd

  echo "[1/6] Checking required commands"
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

  echo "[2/6] Resolving target desktop user"

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

  echo "[3/6] Validating required OpenRC services"

  if [[ "$openrc_commands_ok" != "true" ]]; then
    fail "cannot validate OpenRC services because rc-update/rc-service checks failed"
    return
  fi

  for service in "${REQUIRED_SERVICES[@]}"; do
    if ! service_script_present "$service"; then
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

check_desktop_runtime_commands() {
  local cmd

  echo "[4/8] Validating desktop runtime commands"
  for cmd in "${REQUIRED_DESKTOP_COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      pass "desktop runtime command available: $cmd"
    else
      fail "missing required desktop runtime command: $cmd"
    fi
  done
}

check_printing_services() {
  local service
  local enforce_printing=false
  local all_scripts_present=true

  echo "[5/8] Validating optional printing service state"

  case "$expect_printing" in
    on)
      enforce_printing=true
      ;;
    off)
      pass "printing validation skipped by --expect-printing off"
      return
      ;;
    auto)
      for service in "${PRINTING_SERVICES[@]}"; do
        if ! service_script_present "$service"; then
          all_scripts_present=false
        fi
      done

      if [[ "$all_scripts_present" == "true" ]]; then
        enforce_printing=true
      else
        pass "printing services not detected; skipping printing service checks"
        return
      fi
      ;;
    *)
      fail "invalid --expect-printing mode: $expect_printing"
      return
      ;;
  esac

  if [[ "$openrc_commands_ok" != "true" ]]; then
    fail "cannot validate printing services because rc-update/rc-service checks failed"
    return
  fi

  if [[ "$enforce_printing" != "true" ]]; then
    return
  fi

  for service in "${PRINTING_SERVICES[@]}"; do
    if ! service_script_present "$service"; then
      fail "printing service script missing: /etc/init.d/$service"
      continue
    fi

    pass "printing service script present: /etc/init.d/$service"

    if service_enabled_in_default_runlevel "$service"; then
      pass "printing service enabled in default runlevel: $service"
    else
      fail "printing service not enabled in default runlevel: $service"
    fi

    if rc-service "$service" status >/dev/null 2>&1; then
      pass "printing service running: $service"
    else
      fail "printing service not running: $service"
    fi
  done
}

check_hyprland_command_dependencies() {
  local hypr_conf
  local line cmd command_token

  echo "[6/8] Validating Hyprland command dependencies"

  if [[ "$user_context_ready" != "true" ]]; then
    fail "cannot validate Hyprland command dependencies because target user context is unavailable"
    return
  fi

  hypr_conf="$target_home/.config/hypr/hyprland.conf"
  if [[ ! -f "$hypr_conf" ]]; then
    fail "Hyprland runtime config missing: $hypr_conf"
    return
  fi

  hypr_commands_seen=()

  while IFS= read -r line; do
    cmd="$(sed -E 's/^\s*exec-once\s*=\s*(.*)\s*$/\1/' <<< "$line")"
    track_hypr_command_line "$cmd"
  done < <(grep -E '^\s*exec-once\s*=\s*.+$' "$hypr_conf" || true)

  while IFS= read -r line; do
    cmd="$(sed -E 's/^.*\bexec\s*,\s*(.*)\s*$/\1/' <<< "$line")"
    track_hypr_command_line "$cmd"
  done < <(grep -E '^\s*bind[a-z]*\s*=\s*.*\bexec\s*,\s*.+$' "$hypr_conf" || true)

  if [[ "${#hypr_commands_seen[@]}" -eq 0 ]]; then
    fail "no executable commands discovered in $hypr_conf"
    return
  fi

  while IFS= read -r command_token; do
    if hypr_command_is_available "$command_token"; then
      pass "Hyprland command available: $command_token"
      continue
    fi

    if [[ -n "${OPTIONAL_HYPR_COMMANDS[$command_token]:-}" ]]; then
      warn_msg "optional Hyprland command missing: $command_token"
      continue
    fi

    fail "required Hyprland command missing: $command_token"
  done < <(printf '%s\n' "${!hypr_commands_seen[@]}" | sort)
}

check_wallpaper_backend() {
  echo "[6b/8] Validating wallpaper backend"

  if command -v swww >/dev/null 2>&1 || command -v swaybg >/dev/null 2>&1; then
    if command -v swww >/dev/null 2>&1; then
      pass "wallpaper backend available: swww"
    else
      pass "wallpaper backend available: swaybg"
    fi
    return
  fi

  fail "no supported wallpaper backend is installed (expected swww or swaybg)"
}

check_startup_state_and_launcher() {
  local state_file
  local launcher

  echo "[7/8] Validating startup mode state + launcher"

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

  echo "[8/8] Validating mode-specific startup wiring"

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
    --expect-printing)
      shift
      [[ "$#" -gt 0 ]] || { echo "--expect-printing requires a value" >&2; exit 1; }
      case "$1" in
        auto|on|off)
          expect_printing="$1"
          ;;
        *)
          echo "Invalid --expect-printing mode: $1 (use auto, on, or off)" >&2
          exit 1
          ;;
      esac
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
check_desktop_runtime_commands
check_printing_services
check_hyprland_command_dependencies
check_wallpaper_backend
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
