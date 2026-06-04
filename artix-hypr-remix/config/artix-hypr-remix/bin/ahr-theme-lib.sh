#!/usr/bin/env bash
set -euo pipefail

source "${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"

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

ahr_theme_render_templates_for_dir() {
  local output_dir="$1"
  local colors_file="$output_dir/colors.toml"
  local sed_script template_dir template output_file
  local raw key value stripped rgb

  [[ -f "$colors_file" ]] || return 0

  sed_script="$(mktemp)"

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
    printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$sed_script"
    printf 's|{{ %s_strip }}|%s|g\n' "$key" "$stripped" >> "$sed_script"

    if rgb="$(ahr_theme_hex_to_rgb "$value" 2>/dev/null)"; then
      printf 's|{{ %s_rgb }}|%s|g\n' "$key" "$rgb" >> "$sed_script"
    fi
  done < "$colors_file"

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

ahr_theme_apply_targets() {
  local theme_dir="$1"
  local source_file target_file

  while IFS=':' read -r source_file target_file; do
    [[ -f "$theme_dir/$source_file" ]] || continue
    install -d -m 0755 "$(dirname "$target_file")"
    cp "$theme_dir/$source_file" "$target_file"
  done <<EOF
waybar.css:$HOME/.config/waybar/style.css
mako.ini:$HOME/.config/mako/config
ghostty.conf:$HOME/.config/ghostty/config
EOF
}

ahr_theme_apply_gnome() {
  local theme_dir="$1"
  local icon_name=""

  if ! ahr_has_cmd gsettings; then
    return 0
  fi

  if [[ -f "$theme_dir/light.mode" ]]; then
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

ahr_theme_reload_services() {
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

ahr_theme_apply_current_background() {
  local current_background=""

  current_background="$(ahr_theme_current_background)"
  [[ -n "$current_background" ]] || return 0

  ahr_theme_apply_background_file "$current_background"
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
    ahr_theme_warn "No backgrounds found for theme: $theme_name"
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
  ahr_theme_reload_services
}

ahr_theme_set() {
  local theme_input="$1"
  local theme_name=""
  local layer
  local -a layers=()

  theme_name="$(ahr_theme_slugify "$theme_input")"
  [[ -n "$theme_name" ]] || ahr_fail "Invalid theme name"

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
