#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$REPO_ROOT/packages"

INCLUDE_AUR=true

usage() {
  cat <<'EOF'
Usage: ./scripts/check-config-deps.sh [options]

Checks commands referenced by repo config files against package manifests.

Options:
  --no-aur   Ignore packages/9[0-9]-*.txt when validating dependencies
  -h, --help Show this help
EOF
}

trim_whitespace() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-aur)
      INCLUDE_AUR=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$PACKAGES_DIR" ]]; then
  echo "Packages directory not found: $PACKAGES_DIR" >&2
  exit 1
fi

declare -A pkg_sources=()
while IFS= read -r package_file; do
  base_name="$(basename "$package_file")"
  if [[ "$INCLUDE_AUR" == false ]] && [[ "$base_name" == 9[0-9]-* ]]; then
    continue
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%#*}"
    line="$(trim_whitespace "$line")"
    [[ -z "$line" ]] && continue

    package_name="${line%%[[:space:]]*}"
    [[ -n "$package_name" ]] && pkg_sources["$package_name"]="$base_name"
  done < "$package_file"
done < <(find "$PACKAGES_DIR" -maxdepth 1 -type f -name '*.txt' | sort)

declare -A cmd_package_map=(
  [brightnessctl]=brightnessctl
  [gnome-keyring-daemon]=gnome-keyring
  [hx]=helix
  [hyprctl]=hyprland
  [makoctl]=mako
  [playerctl]=playerctl
  [polkit-gnome-authentication-agent-1]=polkit-gnome
  [wl-paste]=wl-clipboard
  [wl-copy]=wl-clipboard
  [walker]=walker-bin
  [notify-send]=libnotify
)

declare -A commands_seen=()

normalize_first_token() {
  local command_line="$1"
  command_line="${command_line%%|*}"
  command_line="$(trim_whitespace "$command_line")"

  # Drop leading env assignment (e.g. FOO=bar cmd)
  while [[ "$command_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
    command_line="${command_line#*=}"
    command_line="$(trim_whitespace "$command_line")"
  done

  token="${command_line%%[[:space:]]*}"
  token="${token#\"}"
  token="${token%\"}"
  token="${token#\'}"
  token="${token%\'}"
  printf '%s' "$token"
}

track_command_line() {
  local command_line="$1"
  local token

  token="$(normalize_first_token "$command_line")"
  [[ -z "$token" ]] && return 0

  case "$token" in
    if|then|else|fi|for|while|do|done|case|esac|"[["|"true"|"false"|"return"|"export"|"source"|"alias"|"command"|"eval"|"builtin"|"activate"|"#"*)
      return 0
      ;;
  esac

  if [[ "$token" == */* ]]; then
    token="$(basename "$token")"
  fi

  [[ "$token" == '$'* ]] && return 0
  commands_seen["$token"]=1
}

# Hyprland autostart: plain command strings in array.
if [[ -f "$REPO_ROOT/config/hypr/autostart.lua" ]]; then
  while IFS= read -r line; do
    cmd="$(sed -E 's/^\s*"(.*)"\s*,?\s*$/\1/' <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E '^\s*".+"\s*,?\s*$' "$REPO_ROOT/config/hypr/autostart.lua" || true)
fi

# Runtime Hyprland config: exec-once and exec binds.
if [[ -f "$REPO_ROOT/config/hypr/hyprland.conf" ]]; then
  while IFS= read -r line; do
    cmd="$(sed -E 's/^\s*exec-once\s*=\s*(.*)\s*$/\1/' <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E '^\s*exec-once\s*=\s*.+$' "$REPO_ROOT/config/hypr/hyprland.conf" || true)

  while IFS= read -r line; do
    cmd="$(sed -E 's/^.*\bexec\s*,\s*(.*)\s*$/\1/' <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E '^\s*bind[a-z]*\s*=\s*.*\bexec\s*,\s*.+$' "$REPO_ROOT/config/hypr/hyprland.conf" || true)
fi

# Hyprland keybinds: command = "..."
if [[ -f "$REPO_ROOT/config/hypr/keybinds.lua" ]]; then
  while IFS= read -r line; do
    cmd="$(sed -E 's/^.*command\s*=\s*"(.*)"\s*\}?.*$/\1/' <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E 'command\s*=\s*".+"' "$REPO_ROOT/config/hypr/keybinds.lua" || true)
fi

# Waybar actions: on-click/on-click-right/on-click-middle/exec
if [[ -f "$REPO_ROOT/config/waybar/config.jsonc" ]]; then
  while IFS= read -r line; do
    cmd="$(sed -E 's/^\s*"(on-click|on-click-right|on-click-middle|exec)"\s*:\s*"(.*)"\s*,?\s*$/\2/' <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E '^\s*"(on-click|on-click-right|on-click-middle|exec)"\s*:\s*".+"' "$REPO_ROOT/config/waybar/config.jsonc" || true)
fi

# Yazi opener rules: run = '...'
if [[ -f "$REPO_ROOT/config/yazi/yazi.toml" ]]; then
  while IFS= read -r line; do
    cmd="$(sed -E "s/^.*run\s*=\s*'([^']+)'.*$/\1/" <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E "run\s*=\s*'[^']+'" "$REPO_ROOT/config/yazi/yazi.toml" || true)
fi

# zsh aliases: alias x='cmd ...'
if [[ -f "$REPO_ROOT/config/zsh/.zshrc" ]]; then
  while IFS= read -r line; do
    cmd="$(sed -E "s/^\s*alias\s+[A-Za-z0-9_]+=['\"]([^'\"]+)['\"].*$/\1/" <<< "$line")"
    track_command_line "$cmd"
  done < <(grep -E '^\s*alias\s+[A-Za-z0-9_]+=' "$REPO_ROOT/config/zsh/.zshrc" || true)
fi

if [[ "${#commands_seen[@]}" -eq 0 ]]; then
  echo "No commands found in known config sources."
  exit 0
fi

echo "Config command dependency check"
echo "Repository: $REPO_ROOT"
echo "Include AUR packages: $INCLUDE_AUR"
echo

declare -a resolved_lines=()
declare -a missing_lines=()

while IFS= read -r cmd; do
  package_name="${cmd_package_map[$cmd]:-$cmd}"
  package_source="${pkg_sources[$package_name]:-}"

  if [[ -n "$package_source" ]]; then
    resolved_lines+=("OK      $cmd -> $package_name ($package_source)")
  else
    missing_lines+=("MISSING $cmd -> $package_name")
  fi
done < <(printf '%s\n' "${!commands_seen[@]}" | sort)

for line in "${resolved_lines[@]}"; do
  echo "$line"
done

if [[ "${#missing_lines[@]}" -gt 0 ]]; then
  echo
  for line in "${missing_lines[@]}"; do
    echo "$line"
  done
  echo
  echo "Dependency check failed: add missing packages or update config commands."
  exit 1
fi

echo
echo "Dependency check passed."
