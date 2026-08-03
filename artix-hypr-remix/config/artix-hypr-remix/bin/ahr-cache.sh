#!/usr/bin/env bash
set -euo pipefail

# ahr-cache.sh — Centralized framework availability cache.
#
# Required cache keys: format_version, timestamp, source, channel, version, commit.
# All writes are atomic (temp file + rename), mode 600, with strict validation.
# On write failure, the previous valid cache remains intact.

CACHE_FORMAT_VERSION=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F ahr_version_validate >/dev/null 2>&1; then
  # shellcheck source=ahr-version.sh
  source "${AHR_VERSION_LIB_PATH:-$SCRIPT_DIR/ahr-version.sh}"
fi

# Required cache keys — parsed in order.
_CACHE_KEYS=(format_version timestamp source channel version commit)

_cache_value_has_control_or_space() {
  case "$1" in
    *[[:cntrl:]]*|*[[:space:]]*) return 0 ;;
  esac
  return 1
}

_cache_source_validate() {
  local source="${1:-}"
  [[ -n "$source" ]] || return 1
  _cache_value_has_control_or_space "$source" && return 1
  case "$source" in
    http://*|https://*|ssh://*|git://*|file:///*|/*|git@*:*) return 0 ;;
  esac
  return 1
}

# Parse a cache record into an associative array.
# Returns 0 if valid, 1 if malformed.
# Sets AHR_CACHE_PARSED_* variables for each required key.
_parse_cache_record() {
  local cache_file="$1"
  [[ -f "$cache_file" ]] || return 1

  local -A fields=()
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || return 1
    key="${line%%=*}"
    value="${line#*=}"
    # Reject duplicate keys
    [[ -n "${fields[$key]+x}" ]] && return 1
    # Reject multiline values
    [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]] && return 1
    fields["$key"]="$value"
  done < "$cache_file"

  # Require exactly one value for each required key
  local k
  for k in "${_CACHE_KEYS[@]}"; do
    [[ -n "${fields[$k]+x}" ]] || return 1
    [[ -n "${fields[$k]}" ]] || return 1
    _cache_value_has_control_or_space "${fields[$k]}" && return 1
  done

  # Validate format_version
  [[ "${fields[format_version]}" == "$CACHE_FORMAT_VERSION" ]] || return 1

  # Validate timestamp must be numeric
  [[ "${fields[timestamp]}" =~ ^[0-9]+$ ]] || return 1

  _cache_source_validate "${fields[source]}" || return 1
  ahr_version_channel "${fields[channel]}" || return 1
  ahr_version_validate "${fields[version]}" || return 1

  # Validate commit: must be a SHA (40-64 hex chars) or "pending"
  case "${fields[commit]}" in
    pending) ;;
    *)
      if [[ "${fields[commit]}" =~ ^[0-9a-fA-F]{40,64}$ ]]; then
        :
      else
        return 1
      fi
      ;;
  esac

  # Export parsed values as AHR_CACHE_PARSED_* for callers
  AHR_CACHE_PARSED_version="${fields[version]}"
  AHR_CACHE_PARSED_commit="${fields[commit]}"
  AHR_CACHE_PARSED_source="${fields[source]}"
  AHR_CACHE_PARSED_channel="${fields[channel]}"
  AHR_CACHE_PARSED_timestamp="${fields[timestamp]}"

  return 0
}

# Validate a cache record. Returns 0 if valid, 1 if malformed.
validate_cache_record() {
  _parse_cache_record "$1"
}

# Read a cache record. Prints "version<TAB>commit<TAB>source<TAB>channel<TAB>timestamp".
# Returns 1 if cache is invalid.
read_cache_record() {
  _parse_cache_record "$1" || return 1
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$AHR_CACHE_PARSED_version" \
    "$AHR_CACHE_PARSED_commit" \
    "$AHR_CACHE_PARSED_source" \
    "$AHR_CACHE_PARSED_channel" \
    "$AHR_CACHE_PARSED_timestamp"
}

# Write a cache record atomically. On failure, the previous valid cache
# remains intact.
write_cache_record() {
  local cache_file="$1"
  local version="$2"
  local source="$3"
  local channel="$4"
  local commit="$5"
  local timestamp="${6:-$(date +%s 2>/dev/null || echo 0)}"

  mkdir -p "$(dirname "$cache_file")"
  local tmp
  tmp="$(mktemp "${cache_file}.tmp.XXXXXX")" || return 1
  chmod 600 "$tmp"
  {
    echo "format_version=$CACHE_FORMAT_VERSION"
    echo "timestamp=$timestamp"
    echo "source=$source"
    echo "channel=$channel"
    echo "version=$version"
    echo "commit=$commit"
  } > "$tmp" && mv -f "$tmp" "$cache_file" || {
    rm -f "$tmp" 2>/dev/null || true
    return 1
  }
}

# Invalidate cache.
invalidate_cache() {
  rm -f "$1" 2>/dev/null || true
}

# Validate that a cache record matches expected source and channel.
# Returns 0 if consistent, 1 if mismatched or stale.
validate_cache_consistency() {
  local cache_file="$1"
  local expected_source="$2"
  local expected_channel="$3"
  local max_age="${4:-900}"

  validate_cache_record "$cache_file" || return 1

  local cache_record
  cache_record="$(read_cache_record "$cache_file")" || return 1

  local cache_ver cache_co cache_src cache_ch cache_ts
  cache_ver="$(printf '%s' "$cache_record" | cut -f1)"
  cache_co="$(printf '%s' "$cache_record" | cut -f2)"
  cache_src="$(printf '%s' "$cache_record" | cut -f3)"
  cache_ch="$(printf '%s' "$cache_record" | cut -f4)"
  cache_ts="$(printf '%s' "$cache_record" | cut -f5)"

  [[ "$cache_src" == "$expected_source" ]] || return 1
  [[ "$cache_ch" == "$expected_channel" ]] || return 1

  local now
  now="$(date +%s 2>/dev/null || echo 0)"
  [[ "$now" =~ ^[0-9]+$ ]] && [[ "$cache_ts" =~ ^[0-9]+$ ]] || return 1
  local age=$(( now - cache_ts ))
  (( age < max_age )) || return 1

  return 0
}
