#!/usr/bin/env bash
set -euo pipefail

waybar_config="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config.jsonc"
namespace_installer="$HOME/.config/artix-hypr-remix/bin/namespace-install.sh"
timestamp="$(date +%Y%m%d-%H%M%S)"

# Migration: add waybar-position-indicator to existing Waybar configs.
# Steps:
#   1. Add "custom/waybar-position-indicator" to the modules-center array.
#   2. Insert the indicator block after the nightlight-indicator block.
#   3. Reinstall the command namespace so ahr-toggle-waybar-position is on PATH.

if [[ ! -f "$waybar_config" ]]; then
  echo "Skipping: Waybar config not found at $waybar_config"
  exit 0
fi

patched=false
tried_array=false
tried_block=false

# --- Idempotency: check both array entry and block definition ---
current_center="$(sed -n '/"modules-center"[[:space:]]*:[[:space:]]*\[/,/\]/p' "$waybar_config" 2>/dev/null || true)"
current_block=false; current_array=false
grep -q '"custom/waybar-position-indicator"[[:space:]]*:' "$waybar_config" 2>/dev/null && current_block=true
[[ "$current_center" == *"custom/waybar-position-indicator"* ]] && current_array=true

if [[ "$current_block" == "true" && "$current_array" == "true" ]]; then
  echo "Config already fully patched: skipping config patch"
else
  echo "Patching Waybar config: $waybar_config"

  # Timestamped backup
  backup_file="${waybar_config}.bak.${timestamp}"
  cp "$waybar_config" "$backup_file"
  echo "Backup saved: $backup_file"

  # 1. Add to modules-center array if missing.
  #    Find the closing ] of the modules-center array (works for single-line,
  #    multi-line without trailing comma, and multi-line with trailing comma).
  #    Uses N to build a multi-line pattern space so we can do a two-pass
  #    substitution:
  #      a) multiline with trailing comma:  s/,[[:space:]]*\n[[:space:]]*\]/...
  #      b) single-line or multiline no-comma:  s/\]/, "new"]/
  if [[ "$current_array" == "false" ]]; then
    tried_array=true
    sed -i '/"modules-center"[[:space:]]*:/{
      :loop
      /\]/{
        # Multiline with trailing comma: "elem",\n  ]  →  "elem",\n    "new"\n  ]
        s/,[[:space:]]*\n[[:space:]]*\]/,\n    "custom\/waybar-position-indicator"\n  ]/
        t   # If the multiline pattern matched, skip the single-line fallback
        # Single-line or multiline without trailing comma:  ]  →  , "new"]
        s/\]/, "custom\/waybar-position-indicator"]/
        b
      }
      N
      b loop
    }' "$waybar_config"
  fi

  # 2. Insert the indicator block after a suitable anchor if missing.
  #    Try nightlight-indicator first, then notification-silencing-indicator
  #    as fallback. Escape / in the anchor name for the sed address.
  if [[ "$current_block" == "false" ]]; then
    anchor_found=false
    for anchor in "custom/nightlight-indicator" "custom/notification-silencing-indicator"; do
      anchor_escaped="${anchor//\//\\/}"
      anchor_end_line="$(sed -n '/"'"$anchor_escaped"'"[[:space:]]*:/,/^[[:space:]]*"interval":[[:space:]]*[0-9]\+$/{
        /^[[:space:]]*"interval":[[:space:]]*[0-9]\+$/{
          =
        }
      }' "$waybar_config" | tail -1 || true)"
      if [[ -n "$anchor_end_line" ]]; then
        anchor_found=true
        break
      fi
    done

    if [[ "$anchor_found" == "true" ]]; then
      tried_block=true
      insert_after=$((anchor_end_line + 1))

      # Ensure the anchor closing line ends with }, so the new block
      # is properly comma-separated from the anchor block.  If it
      # already ends with }, (the normal case) this is a no-op.
      sed -i "${insert_after}s/}[[:space:]]*$/},/" "$waybar_config"

      # Insert the block definition WITHOUT a trailing comma.  We'll
      # add the comma afterward only if a next top-level property
      # follows, to avoid an invalid trailing comma before the root }.
      block_file="$(mktemp)"
      cat > "$block_file" <<'BLOCK'

  "custom/waybar-position-indicator": {
    "exec": "bash ~/.config/artix-hypr-remix/bin/ahr-waybar-position-status",
    "return-type": "json",
    "on-click": "bash ~/.config/artix-hypr-remix/bin/ahr-toggle-waybar-position",
    "signal": 13,
    "interval": 30
  }
BLOCK
      sed -i "${insert_after}r $block_file" "$waybar_config"
      rm -f "$block_file"

      # The inserted block occupies lines (insert_after+1 .. insert_after+8).
      # If line (insert_after+9) is NOT the root closing }, the block needs
      # a trailing comma to separate it from the next top-level property.
      next_line=$((insert_after + 9))
      if ! sed -n "${next_line}p" "$waybar_config" 2>/dev/null | grep -q '^[[:space:]]*}[[:space:]]*$'; then
        close_line=$((insert_after + 8))
        sed -i "${close_line}s/}[[:space:]]*$/},/" "$waybar_config"
      fi
    else
      echo "Warning: Could not locate anchor block — restoring backup, config not modified" >&2
      cp "$backup_file" "$waybar_config"
      tried_array=false
      tried_block=false
    fi
  fi

  # --- Verification: only check what we attempted to change ---
  if [[ "$tried_array" == "true" ]]; then
    current_center="$(sed -n '/"modules-center"[[:space:]]*:[[:space:]]*\[/,/\]/p' "$waybar_config" 2>/dev/null || true)"
    if [[ "$current_center" != *"custom/waybar-position-indicator"* ]]; then
      echo "ERROR: Failed to add waybar-position-indicator to modules-center array" >&2
      echo "Restoring backup from $backup_file" >&2
      cp "$backup_file" "$waybar_config"
      exit 1
    fi
  fi
  if [[ "$tried_block" == "true" ]]; then
    if ! grep -q '"custom/waybar-position-indicator"[[:space:]]*:' "$waybar_config" 2>/dev/null; then
      echo "ERROR: Failed to insert waybar-position-indicator block definition" >&2
      echo "Restoring backup from $backup_file" >&2
      cp "$backup_file" "$waybar_config"
      exit 1
    fi
  fi

  if [[ "$tried_array" == "true" || "$tried_block" == "true" ]]; then
    patched=true
    echo "Waybar config patched with waybar-position-indicator"
  else
    echo "Config not modified (anchor not found)"
  fi
fi

# 3. Re-run namespace installer so ahr-toggle-waybar-position is on PATH.
#    Always runs, even when the config was already up to date, so that
#    a previously half-applied migration gets its namespace symlink.
if [[ -f "$namespace_installer" ]]; then
  bash "$namespace_installer" --quiet
  echo "Namespace re-installed"
fi

if [[ "$patched" == "false" ]]; then
  echo "Migration complete: config was already up to date, namespace refreshed"
else
  echo "Migration complete: waybar-position-indicator added"
fi
