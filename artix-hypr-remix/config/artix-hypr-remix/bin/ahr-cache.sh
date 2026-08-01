#!/usr/bin/env bash
set -euo pipefail

# ahr-cache.sh — Centralized framework availability cache.
#
# Required cache keys: format_version, timestamp, source, channel, version, commit.
# All writes are atomic (temp file + rename), mode 600, with strict validation.

CACHE_FORMAT_VERSION=1

# Validate a cache record. Returns 0 if valid, 1 if malformed.
validate_cache_record() {
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
    fields["$key"]="$value"
  done < "$cache_file"

  # All required fields must be present
  for key in format_version timestamp source channel version commit; do
    [[ -n "${fields[$key]+x}" ]] || return 1
  done

  # Format version must be 1
  [[ "${fields[format_version]}" == "1" ]] || return 1

  # Commit must look like a SHA (40-64 hex chars) or be "pending"
  case "${fields[commit]}" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
      ;;
    pending) ;;
    *) return 1 ;;
  esac

  return 0
}

# Read a cache record. Prints "version|commit|source|channel|timestamp".
# Returns 1 if cache is invalid.
read_cache_record() {
  local cache_file="$1"
  validate_cache_record "$cache_file" || return 1

  local version commit source channel timestamp
  version="$(grep -F 'version=' "$cache_file" | head -n1 | cut -d= -f2)"
  commit="$(grep -F 'commit=' "$cache_file" | head -n1 | cut -d= -f2)"
  source="$(grep -F 'source=' "$cache_file" | head -n1 | cut -d= -f2)"
  channel="$(grep -F 'channel=' "$cache_file" | head -n1 | cut -d= -f2)"
  timestamp="$(grep -F 'timestamp=' "$cache_file" | head -n1 | cut -d= -f2)"

  printf '%s\t%s\t%s\t%s\t%s\n' "$version" "$commit" "$source" "$channel" "$timestamp"
}

# Write a cache record atomically.
write_cache_record() {
  local cache_file="$1"
  local version="$2"
  local source="$3"
  local channel="$4"
  local commit="$5"
  local timestamp="${6:-$(date +%s 2>/dev/null || echo 0)}"

  mkdir -p "$(dirname "$cache_file")"
  local tmp
  tmp="$(mktemp "${cache_file}.tmp.XXXXXX")"
  chmod 600 "$tmp"
  {
    echo "format_version=$CACHE_FORMAT_VERSION"
    echo "timestamp=$timestamp"
    echo "source=$source"
    echo "channel=$channel"
    echo "version=$version"
    echo "commit=$commit"
  } > "$tmp"
  mv -f "$tmp" "$cache_file"
}

# Invalidate cache.
invalidate_cache() {
  rm -f "$1" 2>/dev/null || true
}
