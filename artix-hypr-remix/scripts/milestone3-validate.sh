#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOCTOR_SCRIPT="$SCRIPT_DIR/doctor.sh"
SMOKE_SCRIPT="$SCRIPT_DIR/post-install-smoke.sh"

target_user="${SUDO_USER:-}"
printing_mode="auto"
host_id=""
environment_type="unknown"
startup_mode=""
install_command=""
c1_result="not recorded"
c2_result="not recorded"
note=""

declare -a doctor_args=()
declare -a smoke_args=()

usage() {
  cat <<'EOF'
Usage: ./scripts/milestone3-validate.sh [options]

Runs Milestone 3 validation checks and prints a paste-ready log block.

Options:
  --user NAME               Target desktop user for post-install smoke checks
  --expect-printing MODE    Printing validation mode for smoke: auto|on|off (default: auto)
  --no-aur                  Pass through to doctor.sh
  --host-id TEXT            Metadata for log block
  --environment TEXT        Metadata for log block (vm|bare-metal|other)
  --startup-mode TEXT       Metadata for log block
  --install-command TEXT    Metadata for log block
  --c1-result TEXT          Manual C1 result metadata (default: not recorded)
  --c2-result TEXT          Manual C2 result metadata (default: not recorded)
  --note TEXT               Additional note line (repeatable)
  -h, --help                Show this help

Environment:
  AHR_HOST_POLICY=artix|vm|any  Host policy consumed by doctor.sh
EOF
}

append_note() {
  local message="$1"
  if [[ -z "$note" ]]; then
    note="$message"
  else
    note+="; $message"
  fi
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
          printing_mode="$1"
          ;;
        *)
          echo "Invalid --expect-printing mode: $1 (use auto, on, or off)" >&2
          exit 1
          ;;
      esac
      ;;
    --no-aur)
      doctor_args+=("--no-aur")
      ;;
    --host-id)
      shift
      [[ "$#" -gt 0 ]] || { echo "--host-id requires a value" >&2; exit 1; }
      host_id="$1"
      ;;
    --environment)
      shift
      [[ "$#" -gt 0 ]] || { echo "--environment requires a value" >&2; exit 1; }
      environment_type="$1"
      ;;
    --startup-mode)
      shift
      [[ "$#" -gt 0 ]] || { echo "--startup-mode requires a value" >&2; exit 1; }
      startup_mode="$1"
      ;;
    --install-command)
      shift
      [[ "$#" -gt 0 ]] || { echo "--install-command requires a value" >&2; exit 1; }
      install_command="$1"
      ;;
    --c1-result)
      shift
      [[ "$#" -gt 0 ]] || { echo "--c1-result requires a value" >&2; exit 1; }
      c1_result="$1"
      ;;
    --c2-result)
      shift
      [[ "$#" -gt 0 ]] || { echo "--c2-result requires a value" >&2; exit 1; }
      c2_result="$1"
      ;;
    --note)
      shift
      [[ "$#" -gt 0 ]] || { echo "--note requires a value" >&2; exit 1; }
      append_note "$1"
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

[[ -x "$DOCTOR_SCRIPT" ]] || { echo "Missing executable: $DOCTOR_SCRIPT" >&2; exit 1; }
[[ -x "$SMOKE_SCRIPT" ]] || { echo "Missing executable: $SMOKE_SCRIPT" >&2; exit 1; }

if [[ -n "$target_user" ]]; then
  smoke_args+=("--user" "$target_user")
fi
smoke_args+=("--expect-printing" "$printing_mode")

doctor_log="$(mktemp)"
smoke_log="$(mktemp)"
trap 'rm -f "$doctor_log" "$smoke_log"' EXIT

date_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
host_name="$(hostname 2>/dev/null || echo unknown-host)"

echo "[milestone3] Running doctor checks"
if "$DOCTOR_SCRIPT" "${doctor_args[@]}" | tee "$doctor_log"; then
  doctor_status="PASS"
else
  doctor_status="FAIL"
fi

echo
echo "[milestone3] Running post-install smoke checks"
if "$SMOKE_SCRIPT" "${smoke_args[@]}" | tee "$smoke_log"; then
  smoke_status="PASS"
else
  smoke_status="FAIL"
fi

session_runtime_result="PASS"
if [[ "$doctor_status" != "PASS" || "$smoke_status" != "PASS" ]]; then
  session_runtime_result="FAIL"
fi

doctor_issue_count="$(grep -cE '^MISSING:|^Doctor checks failed' "$doctor_log" || true)"
smoke_fail_count="$(grep -c '^FAIL:' "$smoke_log" || true)"
smoke_warn_count="$(grep -c '^WARN:' "$smoke_log" || true)"

runtime_anomalies="$(grep -hE '^MISSING:|^FAIL:|^WARN: service not running:|^WARN: wallpaper|^WARN: default .* probe failed|^WARN: Hyprland is not running' "$doctor_log" "$smoke_log" | sort -u || true)"
session_process_anomalies="$(grep -hE 'session process missing|waybar|mako|pipewire|wireplumber|xdg-desktop-portal' "$smoke_log" | grep -hE '^FAIL:|^WARN:' | sort -u || true)"
framework_anomalies="$(grep -hE 'framework command|default browser probe|default terminal probe|wallpaper runtime|wallpaper state|startup mode state|session launcher' "$doctor_log" "$smoke_log" | grep -hE '^MISSING:|^FAIL:|^WARN:' | sort -u || true)"

if [[ -z "$host_id" ]]; then
  host_id="$host_name"
fi

if [[ -z "$startup_mode" ]]; then
  startup_mode="not recorded"
fi

if [[ -z "$install_command" ]]; then
  install_command="not recorded"
fi

echo
echo "[milestone3] Summary"
echo "Doctor: $doctor_status"
echo "Post-install smoke: $smoke_status"
echo "C1 (manual): $c1_result"
echo "C2 (manual): $c2_result"
echo "Smoke warnings: $smoke_warn_count"
echo "Session/runtime result: $session_runtime_result"

echo
echo "[milestone3] Paste into MILESTONE3 validation log"
cat <<EOF
Host ID: $host_id
Date: $date_utc
Environment: $environment_type
Startup mode: $startup_mode
Install command: $install_command
C1 result: $c1_result
C2 result: $c2_result
Doctor result: $doctor_status (issues: $doctor_issue_count)
Post-install smoke result: $smoke_status (issues: $smoke_fail_count, warnings: $smoke_warn_count)
Printing expected (on/off/auto): $printing_mode
Session/runtime result: $session_runtime_result
Runtime anomalies:
$(if [[ -n "$runtime_anomalies" ]]; then printf '%s\n' "$runtime_anomalies"; else echo "none"; fi)
Session process anomalies:
$(if [[ -n "$session_process_anomalies" ]]; then printf '%s\n' "$session_process_anomalies"; else echo "none"; fi)
Framework/wallpaper anomalies:
$(if [[ -n "$framework_anomalies" ]]; then printf '%s\n' "$framework_anomalies"; else echo "none"; fi)
Follow-ups: ${note:-none}
EOF

if [[ "$session_runtime_result" != "PASS" ]]; then
  exit 1
fi
