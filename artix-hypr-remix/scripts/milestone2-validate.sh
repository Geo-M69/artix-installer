#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCTOR_SCRIPT="$SCRIPT_DIR/doctor.sh"
SMOKE_SCRIPT="$SCRIPT_DIR/post-install-smoke.sh"

target_user="${SUDO_USER:-}"
printing_mode="auto"
host_id=""
gpu_profile=""
startup_modes=""
install_command=""
note=""

declare -a doctor_args=()
declare -a smoke_args=()

usage() {
  cat <<'EOF'
Usage: ./scripts/milestone2-validate.sh [options]

Runs Milestone 2 validation checks and prints a paste-ready log block.

Options:
  --user NAME               Target desktop user for post-install smoke checks
  --expect-printing MODE    Printing validation mode for smoke: auto|on|off (default: auto)
  --no-aur                  Pass-through to doctor.sh
  --host-id TEXT            Metadata for log block
  --gpu-profile TEXT        Metadata for log block
  --startup-modes TEXT      Metadata for log block
  --install-command TEXT    Metadata for log block
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
    --gpu-profile)
      shift
      [[ "$#" -gt 0 ]] || { echo "--gpu-profile requires a value" >&2; exit 1; }
      gpu_profile="$1"
      ;;
    --startup-modes)
      shift
      [[ "$#" -gt 0 ]] || { echo "--startup-modes requires a value" >&2; exit 1; }
      startup_modes="$1"
      ;;
    --install-command)
      shift
      [[ "$#" -gt 0 ]] || { echo "--install-command requires a value" >&2; exit 1; }
      install_command="$1"
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

echo "[milestone2] Running doctor checks"
if "$DOCTOR_SCRIPT" "${doctor_args[@]}" | tee "$doctor_log"; then
  doctor_status="PASS"
else
  doctor_status="FAIL"
fi

echo
echo "[milestone2] Running post-install smoke checks"
if "$SMOKE_SCRIPT" "${smoke_args[@]}" | tee "$smoke_log"; then
  smoke_status="PASS"
else
  smoke_status="FAIL"
fi

final_status="PASS"
if [[ "$doctor_status" != "PASS" || "$smoke_status" != "PASS" ]]; then
  final_status="FAIL"
fi

doctor_fail_count="$(grep -cE '^MISSING:|^Doctor checks failed' "$doctor_log" || true)"
smoke_fail_count="$(grep -c '^FAIL:' "$smoke_log" || true)"
smoke_warn_count="$(grep -c '^WARN:' "$smoke_log" || true)"

service_anomalies="$(grep -E '^MISSING: service|^MISSING: /etc/init.d/|^MISSING: service not running|^MISSING: service not enabled|^FAIL: .*service' "$doctor_log" "$smoke_log" || true)"
package_anomalies="$(grep -E '^MISSING .* ->|Dependency check failed' "$doctor_log" || true)"
portal_polkit_anomalies="$(grep -E 'polkit-gnome-authentication-agent-1|xdg-desktop-portal|xdg-desktop-portal-hyprland' "$doctor_log" "$smoke_log" | grep -E 'MISSING:|FAIL:' || true)"

if [[ -z "$host_id" ]]; then
  host_id="$host_name"
fi

if [[ -z "$startup_modes" ]]; then
  startup_modes="unknown"
fi

if [[ -z "$install_command" ]]; then
  install_command="not recorded"
fi

if [[ -z "$gpu_profile" ]]; then
  gpu_profile="not recorded"
fi

echo
echo "[milestone2] Summary"
echo "Doctor: $doctor_status"
echo "Post-install smoke: $smoke_status"
echo "Smoke warnings: $smoke_warn_count"
echo "Final status: $final_status"

echo
echo "[milestone2] Paste into MILESTONE2 validation log"
cat <<EOF
Host ID: $host_id
Date: $date_utc
GPU/Profile: $gpu_profile
Startup mode tested: $startup_modes
Install command: $install_command
Doctor result: $doctor_status (issues: $doctor_fail_count)
Post-install smoke result: $smoke_status (issues: $smoke_fail_count, warnings: $smoke_warn_count)
Printing expected (on/off/auto): $printing_mode
OpenRC service anomalies:
$(if [[ -n "$service_anomalies" ]]; then printf '%s\n' "$service_anomalies"; else echo "none"; fi)
Package manifest anomalies:
$(if [[ -n "$package_anomalies" ]]; then printf '%s\n' "$package_anomalies"; else echo "none"; fi)
Portal/polkit anomalies:
$(if [[ -n "$portal_polkit_anomalies" ]]; then printf '%s\n' "$portal_polkit_anomalies"; else echo "none"; fi)
Final status: $final_status
Follow-ups: ${note:-none}
EOF

if [[ "$final_status" != "PASS" ]]; then
  exit 1
fi
