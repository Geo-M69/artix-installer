#!/usr/bin/env bash
# 5.2 — Browser theme sync (Chromium Preferences)
# Updates Chromium's Default/Preferences with the color scheme (dark/light)
# from the current desktop theme.  This is the same file Chromium writes on
# its own, so the change takes effect on next launch.
set -euo pipefail

AHR_THEME_LIB="${AHR_THEME_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-theme-lib.sh}"
AHR_LIB="${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"
[[ -f "$AHR_LIB" ]] && source "$AHR_LIB"
[[ -f "$AHR_THEME_LIB" ]] && source "$AHR_THEME_LIB"

command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1 || exit 0

THEME_DIR="${AHR_THEME_CURRENT_THEME_DIR:-$HOME/.config/artix-hypr-remix/current/theme}"
COLORS_FILE="$THEME_DIR/colors.toml"

PREFS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chromium/Default"
PREFS_FILE="$PREFS_DIR/Preferences"

mkdir -p "$PREFS_DIR"

# Determine dark/light from background luminance
COLOR_SCHEME=1  # 0 = No preference, 1 = Dark, 2 = Light

if [[ -f "$COLORS_FILE" ]]; then
  bg_raw="$(ahr_theme_read_color_value "$THEME_DIR" background 2>/dev/null || true)"
  if [[ -n "$bg_raw" ]]; then
    bg_val="${bg_raw#\#}"
    if awk -v hex="$bg_val" '
      BEGIN {
        hex = tolower(hex)
        r = strtonum("0x" substr(hex,1,2)) / 255
        g = strtonum("0x" substr(hex,3,2)) / 255
        b = strtonum("0x" substr(hex,5,2)) / 255
        if (r <= 0.04045) r = r / 12.92; else r = ((r + 0.055) / 1.055) ^ 2.4
        if (g <= 0.04045) g = g / 12.92; else g = ((g + 0.055) / 1.055) ^ 2.4
        if (b <= 0.04045) b = b / 12.92; else b = ((b + 0.055) / 1.055) ^ 2.4
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if (lum > 0.45) exit 0; else exit 1
      }
    ' 2>/dev/null; then
      COLOR_SCHEME=2
    fi
  fi
fi

# Read existing Preferences if present, otherwise start with an empty object.
# On parse failure the file is left untouched (no data loss).
if command -v python3 >/dev/null 2>&1; then
  python3 - "$PREFS_FILE" "$COLOR_SCHEME" 2>/dev/null <<'PYEOF' || true
import json, os, sys

def _strip_jsonc(text):
    out = []
    i = 0
    n = len(text)
    in_str = False
    str_ch = None
    while i < n:
        ch = text[i]
        if in_str:
            if ch == '\\':
                out.append(ch)
                i += 1
                if i < n:
                    out.append(text[i])
                    i += 1
                continue
            if ch == str_ch:
                in_str = False
            out.append(ch)
            i += 1
            continue
        if ch == '"' or ch == "'":
            in_str = True
            str_ch = ch
            out.append(ch)
            i += 1
        elif ch == '/' and i + 1 < n and text[i + 1] == '/':
            i += 2
            while i < n and text[i] != '\n':
                i += 1
            out.append('\n')
            i += 1
        elif ch == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
        elif ch == ',':
            # trailing comma before ] or }
            # (skip whitespace AND comments before checking)
            j = i + 1
            while j < n:
                c = text[j]
                if c in ' \t\n\r':
                    j += 1
                elif c == '/' and j + 1 < n and text[j + 1] == '/':
                    j += 2
                    while j < n and text[j] != '\n':
                        j += 1
                elif c == '/' and j + 1 < n and text[j + 1] == '*':
                    j += 2
                    while j + 1 < n and not (text[j] == '*' and text[j + 1] == '/'):
                        j += 1
                    j += 2
                else:
                    break
            if j < n and text[j] in '}]':
                i = j
            else:
                out.append(ch)
                i += 1
        else:
            out.append(ch)
            i += 1
    return ''.join(out)

filepath = os.path.expanduser(sys.argv[1])
color_scheme = int(sys.argv[2])
tmp = filepath + '.tmp'

if os.path.exists(filepath):
    with open(filepath) as f:
        text = f.read()
    cleaned = _strip_jsonc(text)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        sys.exit(0)
else:
    data = {}

data.setdefault('extensions', {})['theme'] = {
    'id': '',
    'use_system': False,
    'use_custom': False
}
data.setdefault('browser', {})['theme'] = {
    'color_scheme': color_scheme,
    'user_color': color_scheme
}

with open(tmp, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp, filepath)
PYEOF
elif command -v jq >/dev/null 2>&1; then
  if [[ -f "$PREFS_FILE" ]] && jq . "$PREFS_FILE" >/dev/null 2>&1; then
    jq --argjson scheme "$COLOR_SCHEME" \
      '.extensions.theme = {"id": "", "use_system": false, "use_custom": false}
       | .browser.theme = {"color_scheme": $scheme, "user_color": $scheme}' \
      "$PREFS_FILE" > "${PREFS_FILE}.tmp" 2>/dev/null && \
      mv "${PREFS_FILE}.tmp" "$PREFS_FILE" || \
      rm -f "${PREFS_FILE}.tmp"
  elif [[ -f "$PREFS_FILE" ]]; then
    :  # jq can't parse (JSONC); skip silently
  else
    cat > "$PREFS_FILE" <<JSONEOF
{
  "extensions": {
    "theme": {
      "id": "",
      "use_system": false,
      "use_custom": false
    }
  },
  "browser": {
    "theme": {
      "color_scheme": ${COLOR_SCHEME},
      "user_color": ${COLOR_SCHEME}
    }
  }
}
JSONEOF
  fi
fi
