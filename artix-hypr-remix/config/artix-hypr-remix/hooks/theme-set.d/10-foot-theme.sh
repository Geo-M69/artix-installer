#!/usr/bin/env bash
# 5.1 — Foot terminal theme sync
# Deploys a themed foot.ini with the correct dark/light color section
# and signals running Foot instances to switch palettes.
set -euo pipefail

AHR_THEME_LIB="${AHR_THEME_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-theme-lib.sh}"
AHR_LIB="${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"
AHR_BACKUP_LIB="${AHR_BACKUP_HELPER_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-backup-helper.sh}"
[[ -f "$AHR_LIB" ]] && source "$AHR_LIB"
[[ -f "$AHR_THEME_LIB" ]] && source "$AHR_THEME_LIB"
[[ -f "$AHR_BACKUP_LIB" ]] && source "$AHR_BACKUP_LIB"

command -v foot >/dev/null 2>&1 || exit 0

THEME_DIR="${AHR_THEME_CURRENT_THEME_DIR:-$HOME/.config/artix-hypr-remix/current/theme}"
COLORS_FILE="$THEME_DIR/colors.toml"
FOOT_CONFIG_TARGET="$HOME/.config/foot/foot.ini"

# Read font settings from global font.toml
FONT_FAMILY="JetBrainsMono Nerd Font"
FONT_SIZE="10"
FONT_FILE="${AHR_THEME_STATE_DIR:-$HOME/.config/artix-hypr-remix/current}/font.toml"
if [[ -f "$FONT_FILE" ]]; then
  while IFS='=' read -r k v; do
    k="$(ahr_theme_trim "$k" 2>/dev/null || echo "$k")"
    v="$(ahr_theme_trim "$v" 2>/dev/null || echo "$v")"
    v="${v#\"}"; v="${v%\"}"
    case "$k" in
      font_family) FONT_FAMILY="$v" ;;
      font_size) FONT_SIZE="$v" ;;
    esac
  done < "$FONT_FILE"
fi

# Determine dark/light theme from background luminance
COLOR_THEME="dark"
FOOT_SIGNAL="USR1"  # SIGUSR1 = switch to dark palette
if [[ -f "$COLORS_FILE" ]]; then
  if ahr_theme_is_light "$THEME_DIR" 2>/dev/null; then
    COLOR_THEME="light"
    FOOT_SIGNAL="USR2"  # SIGUSR2 = switch to light palette
  fi
fi

# Strip # prefix — Foot expects plain RRGGBB
strip_hash() {
  local c="$1"
  c="${c#\#}"
  printf '%s' "$c"
}

mkdir -p "$(dirname "$FOOT_CONFIG_TARGET")"

# Backup before first write
if [[ -f "$FOOT_CONFIG_TARGET" ]]; then
  ahr_backup_before_edit "$FOOT_CONFIG_TARGET" 2>/dev/null || {
    echo "Error: failed to backup $FOOT_CONFIG_TARGET before theme edit" >&2
    exit 1
  }
fi

if [[ ! -f "$COLORS_FILE" ]]; then
  cat > "$FOOT_CONFIG_TARGET" <<FOOTEOF
[main]
term=xterm-256color
font=$FONT_FAMILY:size=$FONT_SIZE
pad=14x14
initial-window-mode=windowed
initial-color-theme=$COLOR_THEME

[scrollback]
lines=10000

[cursor]
style=block
blink=no
FOOTEOF
  killall -"$FOOT_SIGNAL" foot 2>/dev/null || true
  exit 0
fi

background="$(ahr_theme_read_color_value "$THEME_DIR" background 2>/dev/null || echo '#1a1a2e')"
foreground="$(ahr_theme_read_color_value "$THEME_DIR" foreground 2>/dev/null || echo '#c0c0c0')"

declare -a colors
for i in $(seq 0 15); do
  colors[$i]="$(ahr_theme_read_color_value "$THEME_DIR" "color$i" 2>/dev/null || echo '#000000')"
done

cat > "$FOOT_CONFIG_TARGET" <<FOOTEOF
[main]
term=xterm-256color
font=$FONT_FAMILY:size=$FONT_SIZE
pad=14x14
initial-window-mode=windowed
initial-color-theme=$COLOR_THEME

[scrollback]
lines=10000

[cursor]
style=block
blink=no

[colors-${COLOR_THEME}]
background=$(strip_hash "$background")
foreground=$(strip_hash "$foreground")

regular0=$(strip_hash "${colors[0]}")
regular1=$(strip_hash "${colors[1]}")
regular2=$(strip_hash "${colors[2]}")
regular3=$(strip_hash "${colors[3]}")
regular4=$(strip_hash "${colors[4]}")
regular5=$(strip_hash "${colors[5]}")
regular6=$(strip_hash "${colors[6]}")
regular7=$(strip_hash "${colors[7]}")

bright0=$(strip_hash "${colors[8]}")
bright1=$(strip_hash "${colors[9]}")
bright2=$(strip_hash "${colors[10]}")
bright3=$(strip_hash "${colors[11]}")
bright4=$(strip_hash "${colors[12]}")
bright5=$(strip_hash "${colors[13]}")
bright6=$(strip_hash "${colors[14]}")
bright7=$(strip_hash "${colors[15]}")
FOOTEOF

# SIGUSR1 = switch to dark palette, SIGUSR2 = switch to light palette
killall -"$FOOT_SIGNAL" foot 2>/dev/null || true
