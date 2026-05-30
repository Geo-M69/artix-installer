#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

HARDWARE_PROFILE_PROBED=false
HARDWARE_IS_LAPTOP=false
HARDWARE_IS_VIRTUALIZED=false
HARDWARE_GPU_VENDORS=()
HARDWARE_GPU_DEVICES=()
HARDWARE_GPU_MODULES=()
HARDWARE_WIFI_INTERFACES=()

hardware_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

hardware_trim_whitespace() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

hardware_add_unique() {
  local value="$1"
  shift
  local existing

  for existing in "$@"; do
    if [[ "$existing" == "$value" ]]; then
      return 1
    fi
  done

  return 0
}

hardware_probe() {
  local line iface

  if [[ "$HARDWARE_PROFILE_PROBED" == "true" ]]; then
    return 0
  fi

  if hardware_has_cmd lspci; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && HARDWARE_GPU_DEVICES+=("$line")
    done < <(lspci -nn | awk '/VGA|3D|Display/ { print }')
  fi

  for line in "${HARDWARE_GPU_DEVICES[@]}"; do
    shopt -s nocasematch
    if [[ "$line" =~ (10de|nvidia) ]]; then
      if hardware_add_unique "nvidia" "${HARDWARE_GPU_VENDORS[@]}"; then
        HARDWARE_GPU_VENDORS+=("nvidia")
      fi
    fi

    if [[ "$line" =~ (8086|intel) ]]; then
      if hardware_add_unique "intel" "${HARDWARE_GPU_VENDORS[@]}"; then
        HARDWARE_GPU_VENDORS+=("intel")
      fi
    fi

    if [[ "$line" =~ (1002|1022|amd|advanced micro devices|ati) ]]; then
      if hardware_add_unique "amd" "${HARDWARE_GPU_VENDORS[@]}"; then
        HARDWARE_GPU_VENDORS+=("amd")
      fi
    fi
    shopt -u nocasematch
  done

  if hardware_has_cmd lsmod; then
    while IFS= read -r line; do
      case "$line" in
        nvidia|nouveau|i915|amdgpu)
          if hardware_add_unique "$line" "${HARDWARE_GPU_MODULES[@]}"; then
            HARDWARE_GPU_MODULES+=("$line")
          fi
          ;;
      esac
    done < <(lsmod | awk 'NR>1 { print $1 }')
  fi

  if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    HARDWARE_IS_LAPTOP=true
  fi

  if hardware_has_cmd iw; then
    while IFS= read -r iface; do
      [[ -n "$iface" ]] || continue
      if hardware_add_unique "$iface" "${HARDWARE_WIFI_INTERFACES[@]}"; then
        HARDWARE_WIFI_INTERFACES+=("$iface")
      fi
    done < <(iw dev 2>/dev/null | awk '/Interface/ { print $2 }')
  fi

  if [[ "${#HARDWARE_WIFI_INTERFACES[@]}" -eq 0 ]]; then
    while IFS= read -r iface; do
      [[ -n "$iface" ]] || continue
      if [[ "$iface" =~ ^(wl|wlan|wlp) ]]; then
        if hardware_add_unique "$iface" "${HARDWARE_WIFI_INTERFACES[@]}"; then
          HARDWARE_WIFI_INTERFACES+=("$iface")
        fi
      fi
    done < <(ls /sys/class/net 2>/dev/null || true)
  fi

  if hardware_has_cmd systemd-detect-virt; then
    if systemd-detect-virt -q; then
      HARDWARE_IS_VIRTUALIZED=true
    fi
  elif grep -qi hypervisor /proc/cpuinfo 2>/dev/null; then
    HARDWARE_IS_VIRTUALIZED=true
  fi

  HARDWARE_PROFILE_PROBED=true
}

hardware_detect_profiles() {
  local vendor

  hardware_probe

  for vendor in "${HARDWARE_GPU_VENDORS[@]}"; do
    case "$vendor" in
      nvidia|intel|amd)
        printf '%s\n' "$vendor"
        ;;
    esac
  done

  if [[ "$HARDWARE_IS_LAPTOP" == "true" ]]; then
    printf '%s\n' "laptop"
  fi
}

hardware_parse_package_file() {
  local file_path="$1"
  local raw line token

  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%#*}"
    line="$(hardware_trim_whitespace "$line")"
    [[ -z "$line" ]] && continue

    token="${line%%[[:space:]]*}"
    [[ -n "$token" ]] && printf '%s\n' "$token"
  done < "$file_path"
}

hardware_collect_profile_packages() {
  local profile_root="$1"
  shift
  local profile package_file

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  for profile in "$@"; do
    package_file="$profile_root/$profile/packages.txt"
    hardware_parse_package_file "$package_file"
  done | awk '!seen[$0]++'
}

hardware_default_profile_path() {
  if [[ "$EUID" -eq 0 ]]; then
    printf '%s\n' "/var/lib/artix-hypr-remix/hardware-profile.json"
  else
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/hardware-profile.json"
  fi
}

hardware_json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

hardware_json_array() {
  local -n values_ref=$1
  local first=true
  local value

  printf '['
  for value in "${values_ref[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ','
    fi

    printf '"%s"' "$(hardware_json_escape "$value")"
  done
  printf ']'
}

hardware_write_profile_json() {
  local output_path="$1"
  local output_dir temp_file
  local timestamp

  hardware_probe

  output_dir="$(dirname "$output_path")"
  mkdir -p "$output_dir"

  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  temp_file="$(mktemp)"

  {
    printf '{\n'
    printf '  "version": 1,\n'
    printf '  "timestamp": "%s",\n' "$timestamp"
    printf '  "gpus": {\n'
    printf '    "vendors": '
    hardware_json_array HARDWARE_GPU_VENDORS
    printf ',\n'
    printf '    "devices": '
    hardware_json_array HARDWARE_GPU_DEVICES
    printf ',\n'
    printf '    "modules": '
    hardware_json_array HARDWARE_GPU_MODULES
    printf '\n'
    printf '  },\n'
    printf '  "is_laptop": %s,\n' "$HARDWARE_IS_LAPTOP"
    printf '  "is_virtualized": %s,\n' "$HARDWARE_IS_VIRTUALIZED"
    printf '  "wifi_interfaces": '
    hardware_json_array HARDWARE_WIFI_INTERFACES
    printf '\n'
    printf '}\n'
  } > "$temp_file"

  mv "$temp_file" "$output_path"
}

hardware_summary_line() {
  hardware_probe

  printf 'vendors=%s laptop=%s virtualized=%s wifi=%s' \
    "${HARDWARE_GPU_VENDORS[*]:-none}" \
    "$HARDWARE_IS_LAPTOP" \
    "$HARDWARE_IS_VIRTUALIZED" \
    "${HARDWARE_WIFI_INTERFACES[*]:-none}"
}
