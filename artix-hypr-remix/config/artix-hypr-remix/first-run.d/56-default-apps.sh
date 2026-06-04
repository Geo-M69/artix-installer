#!/usr/bin/env bash
set -euo pipefail

source "${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"

browser_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-browser"
terminal_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-terminal"

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

browser_default_is_valid || set_browser_default || echo "Skipping default browser setup: no supported browser desktop entry found"
terminal_default_is_valid || set_terminal_default || echo "Skipping default terminal setup: no supported terminal found"
file_manager_default_is_valid || set_file_manager_default || echo "Skipping default file manager setup: no supported file manager desktop entry found"
