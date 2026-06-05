#!/usr/bin/env bash
# Collect validation logs, state, and diagnostic info into a tarball.
# Usage: sudo ./scripts/collect-validation-bundle.sh [--user <username>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_USER="${SUDO_USER:-}"
BUNDLE_DIR=""
BUNDLE_FILE=""
COLLECT_DIR=""

usage() {
  cat <<'EOF'
Usage: sudo ./scripts/collect-validation-bundle.sh [options]

Collects logs, state, and diagnostic information for troubleshooting
or pre-release validation. Outputs a tarball to the current directory.

Options:
  --user NAME   Target user (default: SUDO_USER or current user)
  --output DIR  Output directory for the bundle tarball (default: current dir)
  -h, --help    Show this help

Examples:
  sudo ./scripts/collect-validation-bundle.sh
  sudo ./scripts/collect-validation-bundle.sh --user myuser --output /tmp
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --user) shift; TARGET_USER="$1" ;;
    --output) shift; BUNDLE_DIR="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# Resolve target user
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
  fi
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  TARGET_USER="$(id -un 2>/dev/null || true)"
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  printf 'ERROR: Could not determine target user. Use --user <username>.\n' >&2
  exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  printf 'ERROR: User %s does not exist.\n' "$TARGET_USER" >&2
  exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
  printf 'ERROR: Could not resolve home directory for user %s.\n' "$TARGET_USER" >&2
  exit 1
fi

# Set output directory
if [[ -z "$BUNDLE_DIR" ]]; then
  BUNDLE_DIR="$PWD"
fi
mkdir -p "$BUNDLE_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE_NAME="ahr-validation-bundle-$TARGET_USER-$TIMESTAMP"
COLLECT_DIR="$(mktemp -d "/tmp/${BUNDLE_NAME}.XXXXXX")"
BUNDLE_FILE="$BUNDLE_DIR/${BUNDLE_NAME}.tar.gz"

# Resolve paths
FRAMEWORK_ROOT="$TARGET_HOME/.config/artix-hypr-remix"
STATE_ROOT="$TARGET_HOME/.local/state/artix-hypr-remix"
INSTALL_STATE_DIR="/var/lib/artix-hypr-remix/install-state"
INSTALL_LOG_FILE="/var/log/artix-hypr-remix-install.log"

collect() {
  local src="$1"
  local dest_subdir="$2"
  local desc="$3"

  if [[ -e "$src" ]]; then
    local dest_dir="$COLLECT_DIR/$dest_subdir"
    mkdir -p "$dest_dir"
    cp -a "$src" "$dest_dir/" 2>/dev/null || printf '  WARN: could not copy %s\n' "$src"
    printf '  collected %s: %s\n' "$desc" "$src"
  else
    printf '  skipped (%s not found): %s\n' "$desc" "$src"
  fi
}

printf '\nCollecting validation bundle for user %s\n' "$TARGET_USER"
printf '  Home:      %s\n' "$TARGET_HOME"
printf '  Output:    %s\n' "$BUNDLE_FILE"
printf '\n'

mkdir -p "$COLLECT_DIR"

# --- System info ---
printf '[1/8] System information\n'
{
  printf '=== uname -a ===\n'
  uname -a
  printf '\n=== /etc/artix-release ===\n'
  cat /etc/artix-release 2>/dev/null || printf '(not found)\n'
  printf '\n=== /etc/os-release ===\n'
  cat /etc/os-release 2>/dev/null || printf '(not found)\n'
  printf '\n=== pacman -Q (installed packages, truncated to first 200) ===\n'
  pacman -Q 2>/dev/null | head -200 || printf '(pacman not available)\n'
  printf '\n=== CPU info ===\n'
  grep -E 'model name|vendor_id' /proc/cpuinfo 2>/dev/null | head -10 || true
  printf '\n=== Memory ===\n'
  head -3 /proc/meminfo 2>/dev/null || true
  printf '\n=== Virtualization ===\n'
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt 2>/dev/null || printf 'none\n'
  else
    grep -qi hypervisor /proc/cpuinfo 2>/dev/null && printf 'virtualized\n' || printf 'unknown\n'
  fi
  printf '\n=== Kernel modules (GPU) ===\n'
  lsmod 2>/dev/null | grep -iE 'nvidia|amdgpu|i915|nouveau|radeon' || printf '(none found)\n'
} > "$COLLECT_DIR/system-info.txt"
printf '  collected system info\n'

# --- Installer state ---
printf '[2/8] Installer state\n'
collect "$INSTALL_STATE_DIR" "install-state" "install state directory"
collect "$INSTALL_LOG_FILE" "logs" "install log"
for f in /tmp/artix-hypr-remix-install-*.log; do
  [[ -f "$f" ]] && collect "$f" "logs" "install log (fallback)"
done

# --- Framework config ---
printf '[3/8] Framework config\n'
collect "$FRAMEWORK_ROOT" "framework" "framework root"

# --- State files ---
printf '[4/8] Runtime state\n'
collect "$STATE_ROOT" "state" "runtime state root"
collect "$TARGET_HOME/.local/state/artix-hypr-remix" "state-full" "full state tree"

# --- Config files ---
printf '[5/8] Desktop config manifests\n'
for cfg in hypr/hyprland.conf hypr/hypridle.conf hypr/hyprlock.conf waybar/config.jsonc waybar/style.css mako/config; do
  collect "$TARGET_HOME/.config/$cfg" "config/$(dirname "$cfg")" "$cfg"
done

# --- Config backups ---
printf '[6/8] Config backups\n'
{
  shopt -s nullglob
  for root in artix-hypr-remix fontconfig ghostty helix hypr mako starship walker waybar yazi zsh; do
    for backup in "$TARGET_HOME/.config/$root".bak.*; do
      printf '%s\n' "$backup"
    done
  done
  for backup in "$TARGET_HOME/.ssh/config.ahr-dev-baseline.bak"* \
    "$TARGET_HOME/.gnupg/gpg.conf.ahr-dev-baseline.bak"* \
    "$TARGET_HOME/.gnupg/gpg-agent.conf.ahr-dev-baseline.bak"*; do
    printf '%s\n' "$backup"
  done
  shopt -u nullglob
} > "$COLLECT_DIR/config-backups.txt"
printf '  collected config backup listing\n'

# --- OpenRC service state ---
printf '[7/8] OpenRC service state\n'
{
  printf '=== rc-status ===\n'
  rc-status 2>/dev/null || printf '(rc-status not available)\n'
  printf '\n=== rc-update ===\n'
  rc-update 2>/dev/null || printf '(rc-update not available)\n'
  printf '\n=== Default runlevel services ===\n'
  ls /etc/runlevels/default/ 2>/dev/null || printf '(not found)\n'
} > "$COLLECT_DIR/openrc-state.txt"
printf '  collected OpenRC state\n'

# --- Run quality gate and smoke tests ---
printf '[8/8] Validation scripts\n'
{
  printf '=== quality-gate.sh (--no-aur) ===\n'
  if [[ -x "$SCRIPT_DIR/quality-gate.sh" ]]; then
    bash "$SCRIPT_DIR/quality-gate.sh" --no-aur 2>&1 || printf '(exit code: %s)\n' "$?"
  else
    printf '(quality-gate.sh not found)\n'
  fi

  printf '\n=== check-openrc-portability.sh ===\n'
  if [[ -x "$SCRIPT_DIR/check-openrc-portability.sh" ]]; then
    bash "$SCRIPT_DIR/check-openrc-portability.sh" 2>&1 || printf '(exit code: %s)\n' "$?"
  else
    printf '(not found)\n'
  fi

  printf '\n=== doctor.sh (--no-aur) ===\n'
  if [[ -x "$SCRIPT_DIR/doctor.sh" ]]; then
    bash "$SCRIPT_DIR/doctor.sh" --no-aur 2>&1 || printf '(exit code: %s)\n' "$?"
  else
    printf '(not found)\n'
  fi

  printf '\n=== ahr-repair (dry-run) ===\n'
  AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$FRAMEWORK_ROOT/bin/ahr-repair" 2>&1 || printf '(exit code: %s)\n' "$?"

  printf '\n=== ahr-status ===\n'
  AHR_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$FRAMEWORK_ROOT/bin/ahr-status" 2>&1 || printf '(exit code: %s)\n' "$?"

  printf '\n=== ahr-list-backups ===\n'
  bash "$FRAMEWORK_ROOT/bin/ahr-list-backups" 2>&1 || printf '(exit code: %s)\n' "$?"
} > "$COLLECT_DIR/validation-output.txt"
printf '  collected validation script output\n'
# --- Determine how to run commands as target user ---
run_as_user() {
  local target_user="$1"
  shift
  if command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$target_user" "$@"
  elif command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- "$@"
  else
    # Fall back to running directly (may inspect wrong home)
    "$@"
  fi
}
# --- Create tarball ---
printf '\nCreating bundle...\n'
tar -czf "$BUNDLE_FILE" -C "$(dirname "$COLLECT_DIR")" "$(basename "$COLLECT_DIR")"
rm -rf "$COLLECT_DIR"

printf '\nValidation bundle created:\n'
printf '  %s\n' "$BUNDLE_FILE"
printf '  Size: %s\n' "$(stat --printf='%s' "$BUNDLE_FILE" 2>/dev/null || echo '?') bytes"
printf '\nTo share this bundle, attach the file to a GitHub issue or transfer it securely.\n'
printf 'Contents: system info, installer state, framework config, runtime state,\n'
printf '          config manifests, backup listing, OpenRC state, validation output.\n'
