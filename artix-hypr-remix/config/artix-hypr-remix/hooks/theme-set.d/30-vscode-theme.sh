#!/usr/bin/env bash
# 5.3 — VS Code / Cursor / OpenCode theme sync
# Updates the editor's settings.json to use a dark or light color theme
# matching the current desktop theme.  Handles JSONC gracefully by using
# python3 when jq cannot parse the file.
set -euo pipefail

AHR_THEME_LIB="${AHR_THEME_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-theme-lib.sh}"
AHR_LIB="${AHR_LIB_PATH:-$HOME/.config/artix-hypr-remix/bin/ahr-lib.sh}"
[[ -f "$AHR_LIB" ]] && source "$AHR_LIB"
[[ -f "$AHR_THEME_LIB" ]] && source "$AHR_THEME_LIB"

# OpenCode uses .jsonc (JSON with comments).  Prefer .jsonc when it exists;
# otherwise fall back to .json for backward compatibility with older installs.
OPencode_CONFIG="$HOME/.config/opencode/opencode.jsonc"
[[ -f "$HOME/.config/opencode/opencode.json" && ! -f "$OPencode_CONFIG" ]] && \
  OPencode_CONFIG="$HOME/.config/opencode/opencode.json"

EDITORS=(
  "code:$HOME/.config/Code/User/settings.json:workbench.colorTheme"
  "cursor:$HOME/.config/Cursor/User/settings.json:workbench.colorTheme"
  "opencode:${OPencode_CONFIG}:theme"
)

THEME_DIR="${AHR_THEME_CURRENT_THEME_DIR:-$HOME/.config/artix-hypr-remix/current/theme}"

DARK_THEME="Default Dark+"
LIGHT_THEME="Default Light+"

THEME_NAME="$DARK_THEME"
if ahr_theme_is_light "$THEME_DIR" 2>/dev/null; then
  THEME_NAME="$LIGHT_THEME"
fi

has_python3=false
command -v python3 >/dev/null 2>&1 && has_python3=true
has_jq=false
command -v jq >/dev/null 2>&1 && has_jq=true

# python3-based JSON editor — strips // and /* */ comments (including
# inline ones) and trailing commas using a proper state machine that
# tracks string context, so JSONC files are handled safely.  On parse
# failure the original file is left untouched.
update_json_python() {
  local file="$1" key="$2" val="$3"
  python3 - "$file" "$key" "$val" 2>/dev/null <<'PYEOF'
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
key = sys.argv[2]
val = sys.argv[3]
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

data[key] = val

with open(tmp, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp, filepath)
PYEOF
}

update_json_jq() {
  local file="$1" key="$2" val="$3"
  # Validate that the file is parseable JSON first
  jq . "$file" >/dev/null 2>&1 || return 1
  jq --arg key "$key" --arg val "$val" \
    '.[$key] = $val' "$file" > "${file}.tmp" 2>/dev/null && \
    mv "${file}.tmp" "$file" || \
    rm -f "${file}.tmp"
}

for editor_entry in "${EDITORS[@]}"; do
  IFS=':' read -r editor_cmd settings_path theme_key <<< "$editor_entry"
  command -v "$editor_cmd" >/dev/null 2>&1 || continue

  mkdir -p "$(dirname "$settings_path")"

  if [[ -f "$settings_path" ]]; then
    # Try jq first (fast, strict JSON)
    if $has_jq && update_json_jq "$settings_path" "$theme_key" "$THEME_NAME"; then
      :
    elif $has_python3; then
      update_json_python "$settings_path" "$theme_key" "$THEME_NAME"
    else
      # No jq or python3 — skip with a visible warning
      echo "Warning: Cannot update $settings_path — need jq or python3" >&2
    fi
  else
    cat > "$settings_path" <<JSONEOF
{
  "$theme_key": "$THEME_NAME"
}
JSONEOF
  fi
done
