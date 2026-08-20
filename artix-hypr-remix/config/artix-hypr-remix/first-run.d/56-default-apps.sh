#!/usr/bin/env bash
set -euo pipefail

source "${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"
source "${AHR_DEFAULT_APPS_MATRIX:-$(dirname "${BASH_SOURCE[0]}")/ahr-default-apps-matrix.sh}"

browser_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-browser"
terminal_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-terminal"
calculator_cmd="$HOME/.config/artix-hypr-remix/bin/ahr-default-calculator"
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
      for mime in text/plain text/markdown text/x-markdown text/x-shellscript text/x-python; do
        xdg-mime default "$desktop_id" "$mime" >/dev/null 2>&1 || true
      done
    fi

    echo "Default editor set: $editor_cmd"
    return 0
  done

  return 1
}

calculator_default_is_valid() {
  local saved_calc

  if [[ -f "$SHELL_CONFIG" ]]; then
    saved_calc="$(grep -s '^export CALCULATOR=' "$SHELL_CONFIG" | sed 's/^export CALCULATOR=//' | head -1 || true)"
    if [[ -n "$saved_calc" ]]; then
      command -v "$saved_calc" >/dev/null 2>&1 && return 0
    fi
  fi

  # An installed AHR default calculator counts as a valid configuration.
  ahr_matrix_desktop_entry_exists org.gnome.Calculator.desktop || \
    ahr_matrix_desktop_entry_exists gnome-calculator.desktop
}

set_calculator_default() {
  local desktop_id

  for desktop_id in org.gnome.Calculator.desktop gnome-calculator.desktop; do
    if ahr_matrix_desktop_entry_exists "$desktop_id"; then
      if [[ -x "$calculator_cmd" ]]; then
        "$calculator_cmd" set gnome-calculator || true
      fi
      echo "Default calculator set: gnome-calculator"
      return 0
    fi
  done

  return 1
}

mime_defaults_apply() {
  # PDF, image, video, audio, and archive defaults are driven entirely by the
  # shared matrix (ahr-default-apps-matrix.sh). Each is set only when no valid
  # handler already exists, so a user-selected or Flatpak handler is preserved.
  if ahr_matrix_apply_pure_mime_categories; then
    return 0
  fi
  return 1
}

browser_default_is_valid || set_browser_default || echo "Skipping default browser setup: no supported browser desktop entry found"
terminal_default_is_valid || set_terminal_default || echo "Skipping default terminal setup: no supported terminal found"
file_manager_default_is_valid || set_file_manager_default || echo "Skipping default file manager setup: no supported file manager desktop entry found"
editor_default_is_valid || set_editor_default || echo "Skipping default editor setup: no supported editor command found"
calculator_default_is_valid || set_calculator_default || echo "Skipping default calculator setup: no supported calculator desktop entry found"
mime_defaults_apply || echo "Skipping some MIME defaults: no candidate desktop entries found"
