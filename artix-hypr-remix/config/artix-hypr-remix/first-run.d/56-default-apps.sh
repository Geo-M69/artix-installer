#!/usr/bin/env bash
set -euo pipefail

source "${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"

browser_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-browser"
terminal_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-terminal"
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/artix-hypr-remix/env"

browser_default_is_valid() {
  local desktop_id

  ahr_has_cmd xdg-settings || return 1
  desktop_id="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  desktop_id="$(ahr_trim "$desktop_id")"

  [[ -n "$desktop_id" ]] && ahr_desktop_entry_exists "$desktop_id"
}

terminal_default_is_valid() {
  local desktop_id=""

  desktop_id="$(ahr_read_first_noncomment_line "$(ahr_terminal_preference_file)" 2>/dev/null || true)"
  [[ -n "$desktop_id" ]] && ahr_terminal_id_is_available "$desktop_id"
}

file_manager_default_is_valid() {
  local desktop_id

  ahr_has_cmd xdg-mime || return 1
  desktop_id="$(xdg-mime query default inode/directory 2>/dev/null || true)"
  desktop_id="$(ahr_trim "$desktop_id")"

  [[ -n "$desktop_id" ]] && ahr_desktop_entry_exists "$desktop_id"
}

set_browser_default() {
  local choice desktop_id

  [[ -x "$browser_cmd" ]] || return 1

  for choice in firefox zen chromium chrome brave brave-origin edge; do
    case "$choice" in
      firefox) desktop_id="firefox.desktop" ;;
      zen) desktop_id="zen.desktop" ;;
      chromium) desktop_id="chromium.desktop" ;;
      chrome) desktop_id="google-chrome.desktop" ;;
      brave) desktop_id="brave-browser.desktop" ;;
      brave-origin) desktop_id="brave-origin-beta.desktop" ;;
      edge) desktop_id="microsoft-edge.desktop" ;;
    esac

    if ahr_desktop_entry_exists "$desktop_id"; then
      "$browser_cmd" "$choice"
      echo "Default browser set: $choice"
      return 0
    fi
  done

  return 1
}

set_terminal_default() {
  local choice desktop_id

  [[ -x "$terminal_cmd" ]] || return 1

  for choice in ghostty foot kitty alacritty; do
    case "$choice" in
      ghostty) desktop_id="com.mitchellh.ghostty.desktop" ;;
      foot) desktop_id="foot.desktop" ;;
      kitty) desktop_id="kitty.desktop" ;;
      alacritty) desktop_id="Alacritty.desktop" ;;
    esac

    if ahr_terminal_id_is_available "$desktop_id"; then
      "$terminal_cmd" "$choice"
      echo "Default terminal set: $choice"
      return 0
    fi
  done

  return 1
}

set_file_manager_default() {
  local desktop_id mime_type

  ahr_has_cmd xdg-mime || return 1

  for desktop_id in \
    org.gnome.Nautilus.desktop \
    nautilus.desktop \
    thunar.desktop \
    org.kde.dolphin.desktop \
    dolphin.desktop; do
    if ! ahr_desktop_entry_exists "$desktop_id"; then
      continue
    fi

    for mime_type in inode/directory x-directory/normal; do
      xdg-mime default "$desktop_id" "$mime_type" >/dev/null 2>&1 || true
    done

    echo "Default file manager set: $desktop_id"
    return 0
  done

  return 1
}

editor_default_is_valid() {
  local editor_cmd saved_editor

  # Prefer the saved env file over the live $EDITOR so re-runs respect
  # a user's explicit choice (ahr-default-editor) even when $EDITOR is
  # unset or differs in the calling shell.
  if [[ -f "$SHELL_CONFIG" ]]; then
    saved_editor="$(grep -s '^export EDITOR=' "$SHELL_CONFIG" | sed 's/^export EDITOR=//' | head -1 || true)"
    if [[ -n "$saved_editor" ]]; then
      command -v "$saved_editor" >/dev/null 2>&1 && return 0
    fi
  fi

  [[ -n "${EDITOR:-}" ]] || return 1
  editor_cmd="${EDITOR%% *}"
  command -v "$editor_cmd" >/dev/null 2>&1
}

set_editor_default() {
  local editor_cmd desktop_id

  for editor_cmd in hx nvim vim; do
    if ! command -v "$editor_cmd" >/dev/null 2>&1; then
      continue
    fi

    case "$editor_cmd" in
      hx) desktop_id="helix.desktop" ;;
      nvim) desktop_id="nvim.desktop" ;;
      vim) desktop_id="vim.desktop" ;;
    esac

    export EDITOR="$editor_cmd"
    mkdir -p "$(dirname "$SHELL_CONFIG")"
    if grep -qs '^export EDITOR=' "$SHELL_CONFIG" 2>/dev/null; then
      sed -i "s|^export EDITOR=.*|export EDITOR=$editor_cmd|" "$SHELL_CONFIG"
    else
      printf '%s\n' "export EDITOR=$editor_cmd" >> "$SHELL_CONFIG"
    fi

    if ahr_desktop_entry_exists "$desktop_id"; then
      xdg-mime default "$desktop_id" text/plain >/dev/null 2>&1 || true
      xdg-mime default "$desktop_id" text/x-markdown >/dev/null 2>&1 || true
    fi

    echo "Default editor set: $editor_cmd"
    return 0
  done

  return 1
}

mime_defaults_apply() {
  local applied=false

  ahr_has_cmd xdg-mime || return 1

  # PDF viewer — firefox is always installed and handles PDFs
  if ahr_desktop_entry_exists firefox.desktop; then
    xdg-mime default firefox.desktop application/pdf >/dev/null 2>&1 || true
    applied=true
  fi

  # Image viewer — imv is the default image viewer candidate
  if ahr_has_cmd imv && ahr_desktop_entry_exists imv.desktop; then
    for mime in image/png image/jpeg image/gif image/webp image/bmp image/tiff; do
      xdg-mime default imv.desktop "$mime" >/dev/null 2>&1 || true
    done
    applied=true
    echo "Default image viewer set: imv"
  fi

  # Video player — mpv is the default video player candidate
  if ahr_has_cmd mpv && ahr_desktop_entry_exists mpv.desktop; then
    for mime in video/mp4 video/x-matroska video/webm video/x-msvideo video/ogg video/quicktime; do
      xdg-mime default mpv.desktop "$mime" >/dev/null 2>&1 || true
    done
    applied=true
    echo "Default video player set: mpv"
  fi

  # Archive manager — file-roller
  if ahr_desktop_entry_exists org.gnome.FileRoller.desktop || ahr_desktop_entry_exists file-roller.desktop; then
    local rid
    rid="org.gnome.FileRoller.desktop"
    ahr_desktop_entry_exists "$rid" || rid="file-roller.desktop"
    for mime in application/zip application/x-tar application/x-bzip application/x-bzip2 application/gzip application/x-7z-compressed application/x-rar-compressed; do
      xdg-mime default "$rid" "$mime" >/dev/null 2>&1 || true
    done
    applied=true
    echo "Default archive manager set: $rid"
  fi

  # Audio — pavucontrol for audio control (not a file-open MIME, but useful)
  if ahr_has_cmd pavucontrol; then
    xdg-mime default pavucontrol.desktop x-scheme-handler/pulse >/dev/null 2>&1 || true
  fi

  if $applied; then
    return 0
  fi
  return 1
}

browser_default_is_valid || set_browser_default || echo "Skipping default browser setup: no supported browser desktop entry found"
terminal_default_is_valid || set_terminal_default || echo "Skipping default terminal setup: no supported terminal found"
file_manager_default_is_valid || set_file_manager_default || echo "Skipping default file manager setup: no supported file manager desktop entry found"
editor_default_is_valid || set_editor_default || echo "Skipping default editor setup: no supported editor command found"
mime_defaults_apply || echo "Skipping some MIME defaults: no candidate desktop entries found"
