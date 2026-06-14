#!/usr/bin/env bash
set -euo pipefail

AHR_SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
AHR_SCRIPT_DIR="$(dirname "$AHR_SCRIPT_REAL")"

if [[ -n "${AHR_LIB_PATH:-}" ]] && [[ -f "$AHR_LIB_PATH" ]]; then
  source "$AHR_LIB_PATH"
else
  source "$AHR_SCRIPT_DIR/ahr-lib.sh"
fi

if [[ -n "${AHR_THEME_LIB_PATH:-}" ]] && [[ -f "$AHR_THEME_LIB_PATH" ]]; then
  source "$AHR_THEME_LIB_PATH"
else
  source "$AHR_SCRIPT_DIR/ahr-theme-lib.sh"
fi

AHR_FONT_CONFIG_FILE="$AHR_THEME_STATE_DIR/font.toml"

# Default font configuration written when no font.toml exists yet.
ahr_font_defaults() {
  cat <<'DEFAULTS'
font_family = "JetBrainsMono Nerd Font"
font_size = "10"
font_style = "Regular"
ui_font_family = "Liberation Sans"
ui_font_size = "12"
monospace_fallback = "monospace"
DEFAULTS
}

# Ensure font state directory and default config exist.
ahr_font_init() {
  ahr_theme_mkdir_state

  if [[ ! -f "$AHR_FONT_CONFIG_FILE" ]]; then
    ahr_font_defaults > "$AHR_FONT_CONFIG_FILE"
  fi
}

# Read the current value of a font config key.
# Usage: ahr_font_read <key>
# Returns the value (without quotes) or exits 1 if not found.
ahr_font_read() {
  local key="$1"
  local raw key_name value

  ahr_font_init

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    raw="$(ahr_theme_trim "$raw")"
    [[ -n "$raw" ]] || continue
    [[ "$raw" == \#* ]] && continue
    [[ "$raw" == *=* ]] || continue

    key_name="$(ahr_theme_trim "${raw%%=*}")"
    [[ "$key_name" == "$key" ]] || continue

    value="$(ahr_theme_trim "${raw#*=}")"
    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == "'"*"'" ]]; then
      value="${value#"'"}"
      value="${value%"'"}"
    fi

    printf '%s\n' "$value"
    return 0
  done < "$AHR_FONT_CONFIG_FILE"

  return 1
}

# List all font configuration key=value pairs (one per line, no quotes).
ahr_font_list_config() {
  ahr_font_init
  cat "$AHR_FONT_CONFIG_FILE"
}

# Write a new font.toml with all the standard keys, preserving any that
# are not explicitly overridden.
# Usage: ahr_font_set <key>=<value> [<key>=<value> ...]
ahr_font_set() {
  ahr_font_init

  local -A overrides=()
  local pair key value

  for pair in "$@"; do
    key="$(ahr_theme_trim "${pair%%=*}")"
    value="$(ahr_theme_trim "${pair#*=}")"
    [[ -n "$key" && -n "$value" ]] || continue
    overrides["$key"]="$value"
  done

  # Build the new font.toml, starting with defaults and overlaying current values,
  # then applying overrides.  Uses process substitution so the while loop runs
  # in the current shell and unset affects the parent's overrides array.
  {
    while IFS= read -r raw || [[ -n "$raw" ]]; do
      raw="$(ahr_theme_trim "$raw")"
      [[ -n "$raw" ]] || { echo; continue; }
      [[ "$raw" == \#* ]] && { echo "$raw"; continue; }
      [[ "$raw" == *=* ]] || { echo "$raw"; continue; }

      key="$(ahr_theme_trim "${raw%%=*}")"

      if [[ -v "overrides[$key]" ]]; then
        printf '%s = %s\n' "$key" "$(ahr_font_toml_quote "${overrides[$key]}")"
        unset "overrides[$key]"
      else
        # Try reading current value from existing config
        local current_val
        current_val="$(ahr_font_read "$key" 2>/dev/null || true)"
        if [[ -n "$current_val" ]]; then
          printf '%s = %s\n' "$key" "$(ahr_font_toml_quote "$current_val")"
        else
          echo "$raw"
        fi
      fi
    done < <(ahr_font_defaults)

    # Write any overrides that weren't in defaults
    for key in "${!overrides[@]}"; do
      printf '%s = %s\n' "$key" "$(ahr_font_toml_quote "${overrides[$key]}")"
    done
  } > "$AHR_FONT_CONFIG_FILE.tmp"

  mv "$AHR_FONT_CONFIG_FILE.tmp" "$AHR_FONT_CONFIG_FILE"
}

# Validate a font value for use in TOML and fontconfig.
# Rejects characters that cannot be safely represented in a basic TOML
# double-quoted string: newlines, tabs, double quotes, backslashes.
# Call this BEFORE writing or using the value anywhere.
ahr_font_validate_value() {
  local value="$1"
  local label="${2:-value}"

  if [[ -z "$value" ]]; then
    ahr_fail "$label cannot be empty"
  fi
  if [[ "$value" == *$'\n'* || "$value" == *$'\t'* ]]; then
    ahr_fail "$label contains disallowed characters (newline/tab): $value"
  fi
  if [[ "$value" == *'"'* ]]; then
    ahr_fail "$label contains double-quote character, which is not allowed: $value"
  fi
  if [[ "$value" == *'\\'* ]]; then
    ahr_fail "$label contains backslash character, which is not allowed: $value"
  fi
}

# Validate a font size value (--size / --ui-size).
# Must be a positive integer or decimal number.
ahr_font_validate_size() {
  local value="$1"
  local label="${2:-size}"

  if [[ -z "$value" ]]; then
    ahr_fail "$label cannot be empty"
  fi
  if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    ahr_fail "$label must be a positive number (got: $value)"
  fi
  # Compare numerically without rounding (printf '%.0f' rounds, letting
  # 0.9 slip past -lt 1 and 200.5 slip past -gt 200).
  if ! awk -v v="$value" 'BEGIN { exit (v >= 1 && v <= 200 ? 0 : 1) }' 2>/dev/null; then
    ahr_fail "$label must be between 1 and 200 (got: $value)"
  fi
}

# Validate a font style name (--style).
# Font styles are rendered unquoted in configs, so only safe identifiers
# matching typical OpenType style names are accepted.
ahr_font_validate_style() {
  local value="$1"
  local label="${2:-style}"

  if [[ -z "$value" ]]; then
    ahr_fail "$label cannot be empty"
  fi
  if [[ ! "$value" =~ ^[A-Za-z][A-Za-z0-9._\ -]*$ ]]; then
    ahr_fail "$label contains invalid characters (got: $value)"
  fi
  # Reject sequences that would break config syntax
  if [[ "$value" == *";"* || "$value" == *"#"* || "$value" == *"="* ]]; then
    ahr_fail "$label contains config-significant characters (got: $value)"
  fi
}

# TOML-safe quote-and-escape a value for use inside double-quoted strings.
# Assumes the value has already been validated by ahr_font_validate_value
# and therefore contains no ", \, newlines, or tabs, making simple quoting safe.
ahr_font_toml_quote() {
  local value="$1"
  printf '"%s"' "$value"
}

# Print the current font family name (for monospace/terminal use).
ahr_font_current_family() {
  ahr_font_read font_family 2>/dev/null || printf 'JetBrainsMono Nerd Font\n'
}

# Print the current font size.
ahr_font_current_size() {
  ahr_font_read font_size 2>/dev/null || printf '10\n'
}

# Print the current UI font family (for interface use).
ahr_font_current_ui_family() {
  ahr_font_read ui_font_family 2>/dev/null || printf 'Liberation Sans\n'
}

# Print the current UI font size.
ahr_font_current_ui_size() {
  ahr_font_read ui_font_size 2>/dev/null || printf '12\n'
}

# List available monospace fonts on the system using fc-list.
# Returns raw family names, one per line, sorted, unique.
ahr_font_list_raw() {
  if ! ahr_has_cmd fc-list; then
    ahr_fail "fc-list not available (fontconfig is required)"
  fi

  # Use fontconfig to list monospace fonts (spacing=100 is mono).
  # Fall back to listing all fonts if spacing filter isn't supported.
  local -a fonts=()
  local font

  while IFS= read -r font; do
    [[ -n "$font" ]] || continue
    fonts+=("$font")
  done < <(fc-list --format='%{family[0]}\n' 2>/dev/null | sort -u)

  if (( ${#fonts[@]} == 0 )); then
    return 1
  fi

  printf '%s\n' "${fonts[@]}"
}

# Pretty-print available fonts (same as raw for now, but pipeable to column).
ahr_font_list_pretty() {
  local font
  while IFS= read -r font; do
    [[ -n "$font" ]] || continue
    printf '%s\n' "$font"
  done < <(ahr_font_list_raw)
}

# Apply the current font settings by re-rendering templates and deploying.
# This is called after font config changes.
ahr_font_apply() {
  local theme_name

  theme_name="$(ahr_theme_current_raw 2>/dev/null || true)"
  if [[ -z "$theme_name" ]]; then
    ahr_theme_warn "No theme is set; font configuration saved but not applied."
    return 0
  fi

  # Re-render templates by running a theme refresh (picks up new font vars)
  ahr_theme_refresh

  # Deploy generated fontconfig to match the current font settings
  ahr_theme_deploy_fontconfig
}

# Show current font state as a human-readable report.
ahr_font_status() {
  local font_family font_size ui_font_family ui_font_size

  font_family="$(ahr_font_current_family)"
  font_size="$(ahr_font_current_size)"
  ui_font_family="$(ahr_font_current_ui_family)"
  ui_font_size="$(ahr_font_current_ui_size)"

  printf 'Font: %s (size %s)\n' "$font_family" "$font_size"
  printf 'UI font: %s (size %s)\n' "$ui_font_family" "$ui_font_size"
  printf 'Config: %s\n' "$AHR_FONT_CONFIG_FILE"

  if ahr_has_cmd fc-list; then
    local available
    available="$(ahr_font_list_raw 2>/dev/null | wc -l | tr -d ' ')"
    printf 'System fonts available: %s\n' "$available"
  fi
}
