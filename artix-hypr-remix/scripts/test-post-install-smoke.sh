#!/usr/bin/env bash
# Focused service-policy regressions for post-install smoke validation.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE="$SCRIPT_DIR/post-install-smoke.sh"
PASS=0
FAIL=0
tmp_root="$(mktemp -d /tmp/ahr-post-install-smoke-test-XXXXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

make_fixture() {
  local dir="$1" service
  mkdir -p "$dir/init.d" "$dir/runlevels/default"
  for service in dbus elogind NetworkManager bluetoothd cupsd avahi-daemon; do
    : > "$dir/init.d/$service"
    chmod +x "$dir/init.d/$service"
  done
  for service in dbus elogind NetworkManager; do
    : > "$dir/runlevels/default/$service"
  done
}

run_case() {
  local label="$1" expected="$2" pattern="$3" mode="$4"
  local dir="$tmp_root/${label//[^A-Za-z0-9]/_}"
  make_fixture "$dir"

  case "$mode" in
    printing-active)
      : > "$dir/runlevels/default/cupsd"
      : > "$dir/runlevels/default/avahi-daemon"
      ;;
  esac

  local output rc=0
  output="$(
    exec 2>&1
    AHR_SMOKE_LIBRARY_ONLY=true
    set --
    # shellcheck source=post-install-smoke.sh
    source "$SMOKE"
    AHR_INITD_DIR="$dir/init.d"
    AHR_RUNLEVELS_DIR="$dir/runlevels"
    openrc_commands_ok=true
    failures=()
    warnings=()
    case "$mode" in
      core-inactive) AHR_TEST_ACTIVE_SERVICES='dbus elogind' ;;
      printing-active) AHR_TEST_ACTIVE_SERVICES='dbus elogind NetworkManager cupsd avahi-daemon' ;;
      *) AHR_TEST_ACTIVE_SERVICES='dbus elogind NetworkManager' ;;
    esac
    rc-service() {
      case " ${AHR_TEST_ACTIVE_SERVICES:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
    }
    check_required_openrc_services
    check_optional_openrc_services
    case "$mode" in
      printing-*) expect_printing=on ;;
      *) expect_printing=auto ;;
    esac
    check_printing_services
    printf 'RESULT: failures=%d warnings=%d\n' "${#failures[@]}" "${#warnings[@]}"
    (( ${#failures[@]} == 0 ))
  )" || rc=$?

  if [[ "$rc" == "$expected" && "$output" == *"$pattern"* ]]; then
    pass "$label"
  else
    fail "$label (exit=$rc expected=$expected; expected output: $pattern)"
    printf '%s\n' "$output" >&2
  fi
}

run_case baseline-bluetooth-inactive 0 'optional service not running: bluetoothd' baseline
run_case baseline-printing-inactive 0 'profile selection is not inferred' baseline
run_case printing-profile-inactive 1 'printing service not running: cupsd' printing-on
run_case printing-profile-active 0 'printing service running: avahi-daemon' printing-active
run_case required-core-inactive 1 'service not running: NetworkManager' core-inactive

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
