#!/usr/bin/env bash
set -euo pipefail

# Resolve the real path of this file (following symlinks) so ahr-lib.sh
# is found relative to the script regardless of how it was invoked.
# This avoids depending on $HOME or env vars that may be stale.
AHR_LIB_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
AHR_LIB_DIR="$(dirname "$AHR_LIB_REAL")"

if [[ -n "${AHR_LIB_PATH:-}" ]] && [[ -f "$AHR_LIB_PATH" ]]; then
  source "$AHR_LIB_PATH"
else
  source "$AHR_LIB_DIR/ahr-lib.sh"
fi

AHR_THEME_FRAMEWORK_ROOT="${AHR_THEME_FRAMEWORK_ROOT:-$HOME/.config/artix-hypr-remix}"
AHR_THEME_STATE_DIR="$AHR_THEME_FRAMEWORK_ROOT/current"
AHR_THEME_CURRENT_THEME_DIR="$AHR_THEME_STATE_DIR/theme"
AHR_THEME_NEXT_THEME_DIR="$AHR_THEME_STATE_DIR/next-theme"
AHR_THEME_NAME_FILE="$AHR_THEME_STATE_DIR/theme.name"
AHR_THEME_BACKGROUND_LINK="$AHR_THEME_STATE_DIR/background"

AHR_THEME_USER_DIR="$AHR_THEME_FRAMEWORK_ROOT/themes"
AHR_THEME_DEFAULT_DIR="$AHR_THEME_FRAMEWORK_ROOT/default/themes"
AHR_THEME_OMARCHY_USER_DIR="$HOME/.config/omarchy/themes"
AHR_THEME_OMARCHY_DEFAULT_DIR="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/themes"

AHR_THEME_USER_TEMPLATE_DIR="$AHR_THEME_FRAMEWORK_ROOT/themed"
AHR_THEME_DEFAULT_TEMPLATE_DIR="$AHR_THEME_FRAMEWORK_ROOT/default/themed"
AHR_THEME_USER_BACKGROUNDS_DIR="$AHR_THEME_FRAMEWORK_ROOT/backgrounds"
AHR_THEME_OMARCHY_CURRENT_LINK="$HOME/.config/omarchy/current"

ahr_theme_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

ahr_theme_slugify() {
  local value="$1"
  value="$(printf '%s' "$value" | sed -E 's/<[^>]+>//g')"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="${value// /-}"
  value="$(printf '%s' "$value" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  printf '%s' "$value"
}

ahr_theme_titleize() {
  local value="$1"
  printf '%s' "$value" | sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g'
}

ahr_theme_log() {
  local message="$1"
  if [[ "${AHR_THEME_QUIET:-false}" != "true" ]]; then
    printf '%s\n' "$message"
  fi
}

ahr_theme_warn() {
  local message="$1"
  printf '%s\n' "$message" >&2
}

ahr_theme_mkdir_state() {
  install -d -m 0755 "$AHR_THEME_STATE_DIR"
}

ahr_theme_ensure_omarchy_current_link() {
  local omarchy_dir

  omarchy_dir="$(dirname "$AHR_THEME_OMARCHY_CURRENT_LINK")"
  install -d -m 0755 "$omarchy_dir"

  if [[ -L "$AHR_THEME_OMARCHY_CURRENT_LINK" ]]; then
    return 0
  fi

  if [[ -e "$AHR_THEME_OMARCHY_CURRENT_LINK" ]]; then
    ahr_theme_warn "Skipping Omarchy current compatibility link (path exists): $AHR_THEME_OMARCHY_CURRENT_LINK"
    return 0
  fi

  ln -s "$AHR_THEME_STATE_DIR" "$AHR_THEME_OMARCHY_CURRENT_LINK"
}

ahr_theme_theme_dirs() {
  printf '%s\n' \
    "$AHR_THEME_OMARCHY_DEFAULT_DIR" \
    "$AHR_THEME_DEFAULT_DIR" \
    "$AHR_THEME_OMARCHY_USER_DIR" \
    "$AHR_THEME_USER_DIR"
}

ahr_theme_template_dirs() {
  printf '%s\n' "$AHR_THEME_USER_TEMPLATE_DIR" "$AHR_THEME_DEFAULT_TEMPLATE_DIR"
}

ahr_theme_collect_theme_layers() {
  local theme_name="$1"
  local output_ref_name="$2"
  local -n output_ref="$output_ref_name"
  local dir candidate

  output_ref=()
  while IFS= read -r dir; do
    candidate="$dir/$theme_name"
    if [[ -d "$candidate" ]]; then
      output_ref+=("$candidate")
    fi
  done < <(ahr_theme_theme_dirs)

  (( ${#output_ref[@]} > 0 ))
}

ahr_theme_list_raw() {
  local dir theme_name
  declare -A seen=()

  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue

    while IFS= read -r -d '' theme_path; do
      theme_name="$(basename "$theme_path")"
      [[ -n "$theme_name" ]] || continue
      seen["$theme_name"]=1
    done < <(find -L "$dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -print0 2>/dev/null)
  done < <(ahr_theme_theme_dirs)

  printf '%s\n' "${!seen[@]}" | LC_ALL=C sort
}

ahr_theme_list_pretty() {
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    ahr_theme_titleize "$name"
    printf '\n'
  done < <(ahr_theme_list_raw)
}

ahr_theme_current_raw() {
  if [[ -f "$AHR_THEME_NAME_FILE" ]]; then
    cat "$AHR_THEME_NAME_FILE"
    return 0
  fi

  return 1
}

ahr_theme_current_pretty() {
  local current
  if current="$(ahr_theme_current_raw 2>/dev/null)"; then
    ahr_theme_titleize "$current"
    printf '\n'
    return 0
  fi

  printf 'Unknown\n'
  return 1
}

ahr_theme_hex_to_rgb() {
  local hex="${1#\#}"
  if [[ ! "$hex" =~ ^[0-9A-Fa-f]{6}$ ]]; then
    return 1
  fi

  printf '%d,%d,%d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

ahr_theme_colors_from_alacritty() {
  local theme_dir="$1"
  local alacritty_file="$theme_dir/alacritty.toml"
  local colors_file="$theme_dir/colors.toml"
  local section=""
  local line key value composite

  local foreground=""
  local background=""
  local cursor=""
  local selection_foreground=""
  local selection_background=""

  local color0=""
  local color1=""
  local color2=""
  local color3=""
  local color4=""
  local color5=""
  local color6=""
  local color7=""
  local color8=""
  local color9=""
  local color10=""
  local color11=""
  local color12=""
  local color13=""
  local color14=""
  local color15=""

  [[ -f "$alacritty_file" ]] || ahr_fail "Missing alacritty theme file: $alacritty_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(ahr_theme_trim "$line")"
    [[ -n "$line" ]] || continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ ! "$line" =~ ^([A-Za-z0-9_-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      continue
    fi

    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    value="$(ahr_theme_trim "$value")"

    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == "'"*"'" ]]; then
      value="${value#"'"}"
      value="${value%"'"}"
    fi

    composite="$section.$key"

    case "$composite" in
      colors.primary.foreground) foreground="$value" ;;
      colors.primary.background) background="$value" ;;
      colors.cursor.cursor) cursor="$value" ;;
      colors.selection.text) selection_foreground="$value" ;;
      colors.selection.background) selection_background="$value" ;;
      colors.normal.black) color0="$value" ;;
      colors.normal.red) color1="$value" ;;
      colors.normal.green) color2="$value" ;;
      colors.normal.yellow) color3="$value" ;;
      colors.normal.blue) color4="$value" ;;
      colors.normal.magenta) color5="$value" ;;
      colors.normal.cyan) color6="$value" ;;
      colors.normal.white) color7="$value" ;;
      colors.bright.black) color8="$value" ;;
      colors.bright.red) color9="$value" ;;
      colors.bright.green) color10="$value" ;;
      colors.bright.yellow) color11="$value" ;;
      colors.bright.blue) color12="$value" ;;
      colors.bright.magenta) color13="$value" ;;
      colors.bright.cyan) color14="$value" ;;
      colors.bright.white) color15="$value" ;;
    esac
  done < "$alacritty_file"

  [[ -n "$foreground" ]] || ahr_fail "Could not parse colors from $alacritty_file"

  [[ -n "$cursor" ]] || cursor="$foreground"
  [[ -n "$selection_foreground" ]] || selection_foreground="$foreground"
  [[ -n "$selection_background" ]] || selection_background="$background"
  [[ -n "$color4" ]] || color4="$foreground"

  cat > "$colors_file" <<EOF
accent = "$color4"
cursor = "$cursor"
foreground = "$foreground"
background = "$background"
selection_foreground = "$selection_foreground"
selection_background = "$selection_background"

color0 = "$color0"
color1 = "$color1"
color2 = "$color2"
color3 = "$color3"
color4 = "$color4"
color5 = "$color5"
color6 = "$color6"
color7 = "$color7"
color8 = "$color8"
color9 = "$color9"
color10 = "$color10"
color11 = "$color11"
color12 = "$color12"
color13 = "$color13"
color14 = "$color14"
color15 = "$color15"
EOF
}

# Escape a value for use in sed replacement (s|...|...|) so that
# characters \, &, and the | delimiter are treated literally.
ahr_theme_sed_escape() {
  local value="$1"
  local escaped
  escaped="$value"
  escaped="${escaped//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//|/\\|}"
  printf '%s' "$escaped"
}

# XML-escape a value for insertion into fontconfig XML.
# Disables patsub_replacement so & in the replacement string is literal.
ahr_theme_xml_escape() {
  local value="$1"
  local escaped
  # bash 5.2+ patsub_replacement would expand & in replacements;
  # disable it so &, amp, lt, gt, quot, apos are all literal.
  shopt -u patsub_replacement 2>/dev/null || true
  escaped="$value"
  escaped="${escaped//&/&amp;}"
  escaped="${escaped//</&lt;}"
  escaped="${escaped//>/&gt;}"
  escaped="${escaped//\"/&quot;}"
  escaped="${escaped//\'/&apos;}"
  printf '%s' "$escaped"
}

ahr_theme_render_templates_for_dir() {
  local output_dir="$1"
  local colors_file="$output_dir/colors.toml"
  local font_file="${AHR_THEME_STATE_DIR:-$HOME/.config/artix-hypr-remix/current}/font.toml"
  local sed_script template_dir template output_file
  local raw key value stripped rgb

  [[ -f "$colors_file" ]] || return 0

  sed_script="$(mktemp)"

  # Read color variables from theme colors.toml
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    raw="$(ahr_theme_trim "$raw")"
    [[ -n "$raw" ]] || continue
    [[ "$raw" == \#* ]] && continue
    [[ "$raw" == *=* ]] || continue

    key="$(ahr_theme_trim "${raw%%=*}")"
    value="$(ahr_theme_trim "${raw#*=}")"

    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == "'"*"'" ]]; then
      value="${value#"'"}"
      value="${value%"'"}"
    fi

    [[ -n "$key" ]] || continue

    stripped="${value#\#}"
    printf 's|{{ %s }}|%s|g\n' "$key" "$(ahr_theme_sed_escape "$value")" >> "$sed_script"
    printf 's|{{ %s_strip }}|%s|g\n' "$key" "$(ahr_theme_sed_escape "$stripped")" >> "$sed_script"

    if rgb="$(ahr_theme_hex_to_rgb "$value" 2>/dev/null)"; then
      printf 's|{{ %s_rgb }}|%s|g\n' "$key" "$rgb" >> "$sed_script"
    fi
  done < "$colors_file"

  # Overlay font variables from global font.toml.
  # Create default font.toml on first use if it doesn't exist yet.
  if [[ ! -f "$font_file" ]]; then
    local font_dir
    font_dir="$(dirname "$font_file")"
    install -d -m 0755 "$font_dir"
    cat > "$font_file" <<'FONTDEFAULTS'
font_family = "JetBrainsMono Nerd Font"
font_size = "10"
font_style = "Regular"
ui_font_family = "Liberation Sans"
ui_font_size = "12"
monospace_fallback = "monospace"
FONTDEFAULTS
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    raw="$(ahr_theme_trim "$raw")"
    [[ -n "$raw" ]] || continue
    [[ "$raw" == \#* ]] && continue
    [[ "$raw" == *=* ]] || continue

    key="$(ahr_theme_trim "${raw%%=*}")"
    value="$(ahr_theme_trim "${raw#*=}")"

    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == "'"*"'" ]]; then
      value="${value#"'"}"
      value="${value%"'"}"
    fi

    [[ -n "$key" ]] || continue

    printf 's|{{ %s }}|%s|g\n' "$key" "$(ahr_theme_sed_escape "$value")" >> "$sed_script"
  done < "$font_file"

  while IFS= read -r template_dir; do
    [[ -d "$template_dir" ]] || continue

    shopt -s nullglob
    for template in "$template_dir"/*.tpl; do
      output_file="$output_dir/$(basename "${template%.tpl}")"

      if [[ -f "$output_file" ]]; then
        continue
      fi

      sed -f "$sed_script" "$template" > "$output_file"
    done
    shopt -u nullglob
  done < <(ahr_theme_template_dirs)

  rm -f "$sed_script"
}

ahr_theme_set_templates() {
  local target_dir="${1:-$AHR_THEME_NEXT_THEME_DIR}"
  [[ -d "$target_dir" ]] || ahr_fail "Theme directory not found: $target_dir"
  ahr_theme_render_templates_for_dir "$target_dir"
}

# Generate fontconfig XML from the current font settings (or use defaults).
# This reads the same font.toml that template rendering uses.
ahr_theme_generate_fontconfig() {
  local font_config_file="$AHR_THEME_STATE_DIR/font.toml"
  local font_family="JetBrainsMono Nerd Font"
  local ui_font_family="Liberation Sans"

  if [[ -f "$font_config_file" ]]; then
    local raw k v
    while IFS= read -r raw || [[ -n "$raw" ]]; do
      raw="$(ahr_theme_trim "$raw")"
      [[ -n "$raw" ]] || continue
      [[ "$raw" == \#* ]] && continue
      [[ "$raw" == *=* ]] || continue
      k="$(ahr_theme_trim "${raw%%=*}")"
      v="$(ahr_theme_trim "${raw#*=}")"
      v="${v#\"}"; v="${v%\"}"
      case "$k" in
        font_family) font_family="$v" ;;
        ui_font_family) ui_font_family="$v" ;;
      esac
    done < "$font_config_file"
  fi

  local font_family_xml ui_font_family_xml
  font_family_xml="$(ahr_theme_xml_escape "$font_family")"
  ui_font_family_xml="$(ahr_theme_xml_escape "$ui_font_family")"

  cat <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>${ui_font_family_xml}</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>serif</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>Liberation Serif</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>monospace</string>
    </test>
    <edit name="family" mode="append" binding="same">
      <string>${font_family_xml}</string>
    </edit>
  </match>

  <alias>
    <family>system-ui</family>
    <prefer>
      <family>${ui_font_family_xml}</family>
    </prefer>
  </alias>

  <alias>
    <family>ui-monospace</family>
    <default>
      <family>monospace</family>
    </default>
  </alias>

  <alias>
    <family>-apple-system</family>
    <prefer>
      <family>${ui_font_family_xml}</family>
    </prefer>
  </alias>

  <alias>
    <family>BlinkMacSystemFont</family>
    <prefer>
      <family>${ui_font_family_xml}</family>
    </prefer>
  </alias>

  <alias>
    <family>sans-serif</family>
    <accept>
      <family>Noto Color Emoji</family>
    </accept>
  </alias>

  <alias>
    <family>serif</family>
    <accept>
      <family>Noto Color Emoji</family>
    </accept>
  </alias>

  <alias>
    <family>monospace</family>
    <accept>
      <family>Noto Color Emoji</family>
    </accept>
  </alias>
</fontconfig>
XML
}

# Deploy generated fontconfig to ~/.config/fontconfig/fonts.conf
ahr_theme_deploy_fontconfig() {
  local target="$HOME/.config/fontconfig/fonts.conf"
  local backup_lib="${AHR_BACKUP_HELPER_PATH:-$(dirname "${BASH_SOURCE[0]}")/ahr-backup-helper.sh}"

  install -d -m 0755 "$(dirname "$target")"

  # Backup before write
  if [[ -f "$target" ]]; then
    [[ -f "$backup_lib" ]] || {
      ahr_theme_warn "Unable to back up $target; refusing to modify it"
      return 1
    }
    source "$backup_lib"
    ahr_backup_before_edit "$target" 2>/dev/null || {
      ahr_theme_warn "Unable to back up $target; refusing to modify it"
      return 1
    }
  fi

  ahr_theme_generate_fontconfig > "$target"
  ahr_theme_log "Fontconfig deployed: $target"
}

ahr_theme_apply_targets() {
  local theme_dir="$1"
  local source_file target_file backup_file timestamp

  timestamp="$(date +%Y%m%d-%H%M%S)"

  while IFS=':' read -r source_file target_file; do
    [[ -f "$theme_dir/$source_file" ]] || continue
    install -d -m 0755 "$(dirname "$target_file")"

    # Timestamped backup before overwriting (with .N collision suffix)
    if [[ -f "$target_file" ]]; then
      backup_file="${target_file}.bak.${timestamp}"
      if [[ -e "$backup_file" ]]; then
        local collision=1
        while [[ -e "${backup_file}.$collision" ]]; do
          collision=$((collision + 1))
        done
        backup_file="${backup_file}.$collision"
      fi
      cp "$target_file" "$backup_file"
      ahr_theme_log "Backup saved: $(basename "$backup_file")"
    fi

    cp "$theme_dir/$source_file" "$target_file"
  done <<EOF
waybar.css:$HOME/.config/waybar/style.css
mako.ini:$HOME/.config/mako/config
ghostty.conf:$HOME/.config/ghostty/config
EOF
}

ahr_theme_is_light() {
  local theme_dir="$1"
  local bg_color

  # Explicit light.mode marker always wins
  if [[ -f "$theme_dir/light.mode" ]]; then
    return 0
  fi

  # Auto-detect from background color luminance
  bg_color="$(ahr_theme_read_color_value "$theme_dir" background 2>/dev/null || true)"
  [[ -n "$bg_color" ]] || return 1

  # Compute relative luminance (sRGB) via awk.
  # Returns 0 (light) if luminance > 0.45, otherwise 1 (dark).
  # Threshold chosen to classify all Omarchy light themes correctly
  # while keeping dark themes dark.
  awk -v hex="$bg_color" '
    BEGIN {
      hex = tolower(hex)
      sub(/^#/, "", hex)
      r = strtonum("0x" substr(hex,1,2)) / 255
      g = strtonum("0x" substr(hex,3,2)) / 255
      b = strtonum("0x" substr(hex,5,2)) / 255

      # sRGB linearization
      if (r <= 0.04045) r = r / 12.92; else r = ((r + 0.055) / 1.055) ^ 2.4
      if (g <= 0.04045) g = g / 12.92; else g = ((g + 0.055) / 1.055) ^ 2.4
      if (b <= 0.04045) b = b / 12.92; else b = ((b + 0.055) / 1.055) ^ 2.4

      # Relative luminance (WCAG 2.x)
      lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

      if (lum > 0.45) exit 0; else exit 1
    }
  '
}

ahr_theme_apply_gnome() {
  local theme_dir="$1"
  local icon_name=""

  if ! ahr_has_cmd gsettings; then
    return 0
  fi

  if ahr_theme_is_light "$theme_dir"; then
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" >/dev/null 2>&1 || true
  else
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" >/dev/null 2>&1 || true
  fi

  if [[ -f "$theme_dir/icons.theme" ]]; then
    icon_name="$(tr -d '\r\n' < "$theme_dir/icons.theme")"
    if [[ -n "$icon_name" ]]; then
      gsettings set org.gnome.desktop.interface icon-theme "$icon_name" >/dev/null 2>&1 || true
    fi
  fi
}

ahr_theme_read_color_value() {
  local theme_dir="$1"
  local key_name="$2"
  local colors_file="$theme_dir/colors.toml"
  local raw key value

  [[ -f "$colors_file" ]] || return 1

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    raw="$(ahr_theme_trim "$raw")"
    [[ -n "$raw" ]] || continue
    [[ "$raw" == \#* ]] && continue
    [[ "$raw" == *=* ]] || continue

    key="$(ahr_theme_trim "${raw%%=*}")"
    [[ "$key" == "$key_name" ]] || continue

    value="$(ahr_theme_trim "${raw#*=}")"
    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == "'"*"'" ]]; then
      value="${value#"'"}"
      value="${value%"'"}"
    fi

    [[ -n "$value" ]] || return 1
    printf '%s\n' "$value"
    return 0
  done < "$colors_file"

  return 1
}

ahr_theme_reload_services() {
  if [[ "${AHR_THEME_NO_RELOAD:-0}" == "1" ]]; then
    return 0
  fi

  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -x waybar >/dev/null 2>&1 || true
    if ahr_has_cmd waybar; then
      setsid waybar >/dev/null 2>&1 &
    fi
  fi

  if pgrep -x mako >/dev/null 2>&1; then
    pkill -x mako >/dev/null 2>&1 || true
    if ahr_has_cmd mako; then
      setsid mako >/dev/null 2>&1 &
    fi
  fi

  if ahr_has_cmd hyprctl; then
    hyprctl reload >/dev/null 2>&1 || true
  fi

  # Restart Walker so it picks up fresh theme CSS variables from
  # current/theme/walker.css.  The @import in ahr-default/style.css
  # is resolved when the Walker service starts, so a restart ensures
  # new colors are visible immediately.
  if pgrep -x walker >/dev/null 2>&1; then
    if ahr_has_cmd walker; then
      pkill -x walker >/dev/null 2>&1 || true
      sleep 0.2
      setsid walker --gapplication-service >/dev/null 2>&1 &
    fi
  fi
}

ahr_theme_collect_backgrounds() {
  local theme_name="$1"
  local output_ref_name="$2"
  local -n output_ref="$output_ref_name"
  local dir
  local -a background_dirs=(
    "$AHR_THEME_USER_BACKGROUNDS_DIR/$theme_name"
    "$AHR_THEME_CURRENT_THEME_DIR/backgrounds"
    "$AHR_THEME_FRAMEWORK_ROOT/default/backgrounds/$theme_name"
    "/usr/share/backgrounds"
    "/usr/share/wallpapers"
  )

  output_ref=()

  for dir in "${background_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' background; do
      output_ref+=("$background")
    done < <(
      find -L "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
        -print0 2>/dev/null
    )
  done

  if (( ${#output_ref[@]} > 0 )); then
    mapfile -t output_ref < <(printf '%s\n' "${output_ref[@]}" | LC_ALL=C sort -u)
  fi

  (( ${#output_ref[@]} > 0 ))
}

ahr_theme_bg_set() {
  local background="$1"
  local resolved=""

  if ahr_has_cmd realpath; then
    resolved="$(realpath "$background")"
  else
    resolved="$(readlink -f "$background" 2>/dev/null || printf '%s' "$background")"
  fi

  [[ -f "$resolved" ]] || ahr_fail "Background file does not exist: $resolved"

  ahr_theme_mkdir_state
  ln -sfn "$resolved" "$AHR_THEME_BACKGROUND_LINK"

  ahr_theme_apply_background_file "$resolved" || true
}

ahr_theme_current_background() {
  if [[ -L "$AHR_THEME_BACKGROUND_LINK" ]]; then
    readlink -f "$AHR_THEME_BACKGROUND_LINK" 2>/dev/null || true
    return 0
  fi

  return 1
}

ahr_theme_apply_background_file() {
  local resolved="$1"

  [[ -f "$resolved" ]] || return 1

  if ahr_has_cmd swww-daemon && ! pgrep -x swww-daemon >/dev/null 2>&1; then
    setsid swww-daemon >/dev/null 2>&1 &
    sleep 0.2
  fi

  if ahr_has_cmd swww; then
    if swww img "$resolved" --transition-type simple --transition-duration 0.4 >/dev/null 2>&1; then
      return 0
    fi
  fi

  if ahr_has_cmd swaybg; then
    pkill -x swaybg >/dev/null 2>&1 || true
    setsid swaybg -i "$resolved" -m fill >/dev/null 2>&1 &
    sleep 0.2

    if pgrep -x swaybg >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

ahr_theme_apply_background_color() {
  local color="$1"

  [[ "$color" =~ ^#?[0-9A-Fa-f]{6}$ ]] || return 1
  [[ "$color" == \#* ]] || color="#$color"

  if ahr_has_cmd swaybg; then
    pkill -x swaybg >/dev/null 2>&1 || true
    setsid swaybg -c "$color" >/dev/null 2>&1 &
    sleep 0.2

    if pgrep -x swaybg >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

ahr_theme_apply_current_background_fallback() {
  local color=""

  [[ -d "$AHR_THEME_CURRENT_THEME_DIR" ]] || return 1
  color="$(ahr_theme_read_color_value "$AHR_THEME_CURRENT_THEME_DIR" background 2>/dev/null || true)"
  [[ -n "$color" ]] || return 1

  ahr_theme_apply_background_color "$color"
}

ahr_theme_apply_current_background() {
  local current_background=""

  current_background="$(ahr_theme_current_background 2>/dev/null || true)"

  if [[ -n "$current_background" ]] && ahr_theme_apply_background_file "$current_background"; then
    return 0
  fi

  ahr_theme_apply_current_background_fallback
}

ahr_theme_bg_next() {
  local theme_name=""
  local current_background=""
  local index=-1
  local next_index
  local i
  local -a backgrounds=()

  theme_name="$(ahr_theme_current_raw 2>/dev/null || true)"
  [[ -n "$theme_name" ]] || return 0

  if ! ahr_theme_collect_backgrounds "$theme_name" backgrounds; then
    ahr_theme_warn "No backgrounds found for theme: $theme_name; using theme background color"
    ahr_theme_apply_current_background_fallback || true
    # Create sentinel symlink so repair does not flag this as missing.
    if [[ ! -e "$AHR_THEME_BACKGROUND_LINK" && ! -L "$AHR_THEME_BACKGROUND_LINK" ]]; then
      ln -sfn ".no-background" "$AHR_THEME_BACKGROUND_LINK"
    fi
    return 0
  fi

  if [[ -L "$AHR_THEME_BACKGROUND_LINK" ]]; then
    current_background="$(readlink -f "$AHR_THEME_BACKGROUND_LINK" 2>/dev/null || true)"
  fi

  for i in "${!backgrounds[@]}"; do
    if [[ "${backgrounds[$i]}" == "$current_background" ]]; then
      index="$i"
      break
    fi
  done

  if (( index == -1 )); then
    ahr_theme_bg_set "${backgrounds[0]}"
    return 0
  fi

  next_index=$(( (index + 1) % ${#backgrounds[@]} ))
  ahr_theme_bg_set "${backgrounds[$next_index]}"
}

ahr_theme_apply_current() {
  [[ -d "$AHR_THEME_CURRENT_THEME_DIR" ]] || ahr_fail "Current theme directory not found"

  ahr_theme_apply_targets "$AHR_THEME_CURRENT_THEME_DIR"
  ahr_theme_apply_gnome "$AHR_THEME_CURRENT_THEME_DIR"

  # Deploy fontconfig to match current font settings
  ahr_theme_deploy_fontconfig

  ahr_theme_reload_services

  # Post-switch validation — warn but do not fail
  local waybar_css="$HOME/.config/waybar/style.css"
  local mako_config="$HOME/.config/mako/config"
  local ghostty_config="$HOME/.config/ghostty/config"

  if [[ ! -f "$waybar_css" || ! -s "$waybar_css" ]]; then
    ahr_theme_warn "Post-switch: Waybar CSS not deployed or empty — run 'ahr-theme refresh'"
  fi

  if [[ ! -f "$mako_config" || ! -s "$mako_config" ]]; then
    ahr_theme_warn "Post-switch: Mako config not deployed or empty — run 'ahr-theme refresh'"
  fi

  if ahr_has_cmd ghostty && [[ ! -f "$ghostty_config" || ! -s "$ghostty_config" ]]; then
    ahr_theme_warn "Post-switch: Ghostty config not deployed or empty — run 'ahr-theme refresh'"
  fi
}

ahr_theme_set() {
  local theme_input="$1"
  local theme_name=""
  local layer
  local -a layers=()

  theme_name="$(ahr_theme_slugify "$theme_input")"
  [[ -n "$theme_name" ]] || ahr_fail "Invalid theme name"
  [[ "$theme_name" == "." || "$theme_name" == ".." || "$theme_name" == */* ]] && ahr_fail "Invalid theme name: $theme_name"

  if ! ahr_theme_collect_theme_layers "$theme_name" layers; then
    ahr_fail "Theme not found: $theme_name"
  fi

  ahr_theme_mkdir_state
  ahr_theme_ensure_omarchy_current_link
  rm -rf "$AHR_THEME_NEXT_THEME_DIR"
  install -d -m 0755 "$AHR_THEME_NEXT_THEME_DIR"

  for layer in "${layers[@]}"; do
    cp -a "$layer/." "$AHR_THEME_NEXT_THEME_DIR/" 2>/dev/null || true
  done

  # Strip VCS metadata from active theme state; keep .git in user themes dir for update
  rm -rf "$AHR_THEME_NEXT_THEME_DIR/.git"

  if [[ ! -f "$AHR_THEME_NEXT_THEME_DIR/colors.toml" && -f "$AHR_THEME_NEXT_THEME_DIR/alacritty.toml" ]]; then
    ahr_theme_colors_from_alacritty "$AHR_THEME_NEXT_THEME_DIR"
  fi

  ahr_theme_render_templates_for_dir "$AHR_THEME_NEXT_THEME_DIR"

  rm -rf "$AHR_THEME_CURRENT_THEME_DIR"
  mv "$AHR_THEME_NEXT_THEME_DIR" "$AHR_THEME_CURRENT_THEME_DIR"
  printf '%s\n' "$theme_name" > "$AHR_THEME_NAME_FILE"

  ahr_theme_apply_current

  if [[ "${AHR_THEME_SKIP_BACKGROUND:-0}" != "1" && "${OMARCHY_THEME_SKIP_BACKGROUND:-0}" != "1" ]]; then
    ahr_theme_bg_next || true
  fi

  if [[ -x "$AHR_THEME_FRAMEWORK_ROOT/bin/hook.sh" ]]; then
    bash "$AHR_THEME_FRAMEWORK_ROOT/bin/hook.sh" theme-set "$theme_name" >/dev/null 2>&1 || true
  fi

  ahr_theme_log "Theme applied: $(ahr_theme_titleize "$theme_name")"
  ahr_notify "Theme" "Applied $(ahr_theme_titleize "$theme_name")"
}

ahr_theme_refresh() {
  local theme_name
  local prior_skip_background="${AHR_THEME_SKIP_BACKGROUND:-0}"

  theme_name="$(ahr_theme_current_raw 2>/dev/null || true)"
  [[ -n "$theme_name" ]] || ahr_fail "No current theme set"

  AHR_THEME_SKIP_BACKGROUND=1
  ahr_theme_set "$theme_name"
  AHR_THEME_SKIP_BACKGROUND="$prior_skip_background"
}

ahr_theme_status() {
  local theme_name=""
  local background_path=""
  local has_issues=false
  local -a status_lines=()

  theme_name="$(ahr_theme_current_raw 2>/dev/null || true)"

  # --- Theme name ---
  if [[ -n "$theme_name" ]]; then
    status_lines+=("Theme: $(ahr_theme_titleize "$theme_name")")
  else
    status_lines+=("Theme: (none set)")
    has_issues=true
  fi

  # --- State directory ---
  if [[ -d "$AHR_THEME_STATE_DIR" ]]; then
    status_lines+=("State directory: $AHR_THEME_STATE_DIR")
  else
    status_lines+=("WARN: State directory missing: $AHR_THEME_STATE_DIR")
    has_issues=true
  fi

  # --- Current theme directory ---
  if [[ -d "$AHR_THEME_CURRENT_THEME_DIR" ]]; then
    status_lines+=("Theme directory: $AHR_THEME_CURRENT_THEME_DIR")
  else
    status_lines+=("WARN: Theme directory missing: $AHR_THEME_CURRENT_THEME_DIR")
    has_issues=true
  fi

  # --- Background ---
  background_path="$(ahr_theme_current_background 2>/dev/null || true)"
  if [[ -n "$background_path" ]]; then
    if [[ "$background_path" == *".no-background"* ]]; then
      status_lines+=("Background: (no backgrounds available, using theme color)")
    elif [[ -f "$background_path" ]]; then
      status_lines+=("Background: $background_path")
    else
      status_lines+=("WARN: Background link points to missing file: $background_path")
      has_issues=true
    fi
  else
    if [[ -L "$AHR_THEME_BACKGROUND_LINK" ]]; then
      local broken_target
      broken_target="$(readlink "$AHR_THEME_BACKGROUND_LINK" 2>/dev/null || echo "?")"
      status_lines+=("WARN: Background symlink broken: → $broken_target")
      has_issues=true
    else
      status_lines+=("Background: (none set)")
    fi
  fi

  # --- Background collection count ---
  if [[ -n "$theme_name" ]]; then
    local -a backgrounds=()
    if ahr_theme_collect_backgrounds "$theme_name" backgrounds; then
      status_lines+=("Available backgrounds: ${#backgrounds[@]}")
    fi
  fi

  # --- Font ---
  local font_config_file="$AHR_THEME_STATE_DIR/font.toml"
  local font_family="JetBrainsMono Nerd Font"
  local font_size="10"
  local ui_font_family="Liberation Sans"
  if [[ -f "$font_config_file" ]]; then
    local raw k v
    while IFS= read -r raw || [[ -n "$raw" ]]; do
      raw="$(ahr_theme_trim "$raw")"
      [[ -n "$raw" ]] || continue
      [[ "$raw" == \#* ]] && continue
      [[ "$raw" == *=* ]] || continue
      k="$(ahr_theme_trim "${raw%%=*}")"
      v="$(ahr_theme_trim "${raw#*=}")"
      v="${v#\"}"; v="${v%\"}"
      case "$k" in
        font_family) font_family="$v" ;;
        font_size) font_size="$v" ;;
        ui_font_family) ui_font_family="$v" ;;
      esac
    done < "$font_config_file"
  fi
  status_lines+=("Font: $font_family (size $font_size)")
  status_lines+=("UI font: $ui_font_family")

  # --- Deployed configs ---
  local waybar_css="$HOME/.config/waybar/style.css"
  local mako_config="$HOME/.config/mako/config"
  local ghostty_config="$HOME/.config/ghostty/config"
  local walker_theme_css="$AHR_THEME_STATE_DIR/theme/walker.css"

  if [[ -f "$walker_theme_css" && -s "$walker_theme_css" ]]; then
    status_lines+=("Walker theme CSS: deployed ($(wc -l < "$walker_theme_css" | tr -d ' ') lines)")
  else
    status_lines+=("WARN: Walker theme CSS missing or empty: $walker_theme_css")
    status_lines+=("  Run 'ahr-theme refresh' to regenerate from default/themed/walker.css.tpl")
    has_issues=true
  fi

  if [[ -f "$waybar_css" && -s "$waybar_css" ]]; then
    status_lines+=("Waybar CSS: deployed ($(wc -l < "$waybar_css" | tr -d ' ') lines)")
  elif [[ -f "$waybar_css" ]]; then
    status_lines+=("WARN: Waybar CSS empty: $waybar_css")
    has_issues=true
  else
    status_lines+=("WARN: Waybar CSS missing: $waybar_css")
    has_issues=true
  fi

  if [[ -f "$mako_config" && -s "$mako_config" ]]; then
    status_lines+=("Mako config: deployed ($(wc -l < "$mako_config" | tr -d ' ') lines)")
  elif [[ -f "$mako_config" ]]; then
    status_lines+=("WARN: Mako config empty: $mako_config")
    has_issues=true
  else
    status_lines+=("WARN: Mako config missing: $mako_config")
    has_issues=true
  fi

  if [[ -f "$ghostty_config" && -s "$ghostty_config" ]]; then
    status_lines+=("Ghostty config: deployed ($(wc -l < "$ghostty_config" | tr -d ' ') lines)")
  elif [[ -f "$ghostty_config" ]]; then
    status_lines+=("WARN: Ghostty config empty: $ghostty_config")
    has_issues=true
  else
    if ahr_has_cmd ghostty; then
      status_lines+=("WARN: Ghostty config missing (ghostty installed): $ghostty_config")
      has_issues=true
    fi
  fi

  local fontconfig_target="$HOME/.config/fontconfig/fonts.conf"
  if [[ -f "$fontconfig_target" && -s "$fontconfig_target" ]]; then
    status_lines+=("Fontconfig: deployed ($(wc -l < "$fontconfig_target" | tr -d ' ') lines)")
  elif [[ -f "$fontconfig_target" ]]; then
    status_lines+=("WARN: Fontconfig empty: $fontconfig_target")
    has_issues=true
  else
    status_lines+=("Fontconfig: (not deployed)")
  fi

  # --- Template rendering ---
  local template_count=0
  local rendered_count=0
  local template_dir

  while IFS= read -r template_dir; do
    [[ -d "$template_dir" ]] || continue
    while IFS= read -r -d '' tpl; do
      template_count=$((template_count + 1))
      local output_file
      output_file="$AHR_THEME_CURRENT_THEME_DIR/$(basename "${tpl%.tpl}")"
      if [[ -f "$output_file" ]]; then
        rendered_count=$((rendered_count + 1))
      fi
    done < <(find "$template_dir" -name '*.tpl' -print0 2>/dev/null)
  done < <(ahr_theme_template_dirs)

  if (( template_count > 0 )); then
    status_lines+=("Templates: $rendered_count/$template_count rendered")
    if (( rendered_count < template_count )); then
      status_lines+=("  (run 'ahr-theme refresh' to re-render)")
      has_issues=true
    fi
  else
    status_lines+=("Templates: (none defined)")
  fi

  # --- Missing optional assets ---
  if [[ -d "$AHR_THEME_CURRENT_THEME_DIR" ]]; then
    local missing_assets=()

    if [[ ! -f "$AHR_THEME_CURRENT_THEME_DIR/swayosd.css" ]]; then
      missing_assets+=("swayosd.css")
    fi
    if [[ ! -f "$AHR_THEME_CURRENT_THEME_DIR/vscode.json" ]]; then
      missing_assets+=("vscode.json")
    fi

    if (( ${#missing_assets[@]} > 0 )); then
      status_lines+=("Optional assets not in theme: ${missing_assets[*]}")
      status_lines+=("  (Omarchy-specific; not required for AHR)")
    fi
  fi

  # --- Print status ---
  local line
  for line in "${status_lines[@]}"; do
    printf '%s\n' "$line"
  done

  if $has_issues; then
    return 1
  fi
  return 0
}
