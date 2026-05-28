#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

TTY_BLOCK_BEGIN="# >>> artix-hypr-remix tty hyprland >>>"
TTY_BLOCK_END="# <<< artix-hypr-remix tty hyprland <<<"

tty_hyprland_block() {
  cat <<'EOF'
# >>> artix-hypr-remix tty hyprland >>>
if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]] && [[ -z "${SSH_TTY:-}" ]] && [[ "${XDG_VTNR:-0}" -eq 1 ]]; then
  hypr_config="$HOME/.config/hypr/hyprland.conf"
  if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session Hyprland --config "$hypr_config"
  else
    exec Hyprland --config "$hypr_config"
  fi
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