#!/usr/bin/env bash
# ahr-version.sh — Shared version validation and comparison.
#
# This library is sourced by ahr-update-framework and ahr-update-available
# to provide a single authoritative implementation of version handling.
#
# Supported format: MAJOR.MINOR.PATCH[-prerelease]
#   MAJOR, MINOR, PATCH: non-negative integers (no leading zeros except "0")
#   prerelease: dot-separated non-empty alphanumeric identifiers
#
# Rejects:
#   - leading zeros in core components (except literal "0")
#   - empty or malformed prerelease identifiers
#   - shell metacharacters
#   - missing components
#   - unsafely large numeric components (handled via string comparison)
#
# Public functions:
#   ahr_version_validate  <version>          → exit 0 if valid, 1 if not
#   ahr_version_compare   <a> <b>           → prints -1/0/1 to stdout
#   ahr_version_channel   <channel>         → exit 0 if supported, 1 if not
#   ahr_version_supported_channels           → prints supported channels

set -euo pipefail

# Supported release channels (strict allowlist)
AHR_SUPPORTED_CHANNELS="stable beta"

ahr_version_supported_channels() {
  echo "$AHR_SUPPORTED_CHANNELS"
}

# Validate a version string against the supported grammar.
ahr_version_validate() {
  local ver="${1:-}"
  [[ -n "$ver" ]] || return 1
  # Must match: digits.digits.digits[-ident[.ident...]]
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$ ]] || return 1
  # Reject shell metacharacters (belt-and-suspenders)
  case "$ver" in
    *['`$!();|&<>'"'"'{}[]*?~#@\\^']* ) return 1 ;;
  esac
  # Reject leading zeros in core components (except literal "0")
  local core="${ver%%-*}"
  local IFS='.'
  local -a parts
  read -ra parts <<< "$core"
  local p
  for p in "${parts[@]}"; do
    if [[ "${#p}" -gt 1 && "$p" == 0* ]]; then
      return 1
    fi
  done
  # Reject empty prerelease identifiers (e.g. "1.0.0-" or "1.0.0-alpha..1")
  if [[ "$ver" == *-* ]]; then
    local pre="${ver#*-}"
    [[ -n "$pre" ]] || return 1
    case "$pre" in
      ..*|*. |.*|*.) return 1 ;;
    esac
  fi
  return 0
}

# Validate a channel against the supported allowlist.
ahr_version_channel() {
  local ch="${1:-}"
  [[ -n "$ch" ]] || return 1
  local s
  for s in $AHR_SUPPORTED_CHANNELS; do
    [[ "$ch" == "$s" ]] && return 0
  done
  return 1
}

# Strip leading zeros from a numeric string for comparison.
# "007" -> "7", "0" -> "0", "010" -> "10".
_ahr_strip_zeros() {
  local s="$1"
  s="${s##0}"
  [[ -n "$s" ]] || s="0"
  echo "$s"
}

# Compare two numeric strings safely without bash arithmetic.
# Prints: positive if a > b, 0 if equal, negative if a < b.
_ahr_nscmp() {
  local a b
  a="$(_ahr_strip_zeros "$1")"
  b="$(_ahr_strip_zeros "$2")"
  if (( ${#a} > ${#b} )); then echo 1; return; fi
  if (( ${#a} < ${#b} )); then echo -1; return; fi
  if [[ "$a" > "$b" ]]; then echo 1; return; fi
  if [[ "$a" < "$b" ]]; then echo -1; return; fi
  echo 0
}

# Compare a single prerelease identifier pair.
# Numeric identifiers compare numerically.
# Numeric identifiers sort before non-numeric (SemVer convention).
_ahr_preid_cmp() {
  local a="$1" b="$2"
  if [[ "$a" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]]; then
    _ahr_nscmp "$a" "$b"; return
  fi
  if [[ "$a" =~ ^[0-9]+$ ]] && ! [[ "$b" =~ ^[0-9]+$ ]]; then echo -1; return; fi
  if ! [[ "$a" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]]; then echo 1; return; fi
  if [[ "$a" > "$b" ]]; then echo 1; return; fi
  if [[ "$a" < "$b" ]]; then echo -1; return; fi
  echo 0
}

# Compare two version strings.
# Returns: negative if a < b, 0 if equal, positive if a > b.
# On malformed input: returns 2 (distinct from 0/±1).
# Never evaluates untrusted strings as bash arithmetic.
# Never crashes with set -u.
ahr_version_compare() {
  local a="${1:-}" b="${2:-}"
  # Validate first — reject malformed cleanly
  ahr_version_validate "$a" || return 2
  ahr_version_validate "$b" || return 2

  # Pacman vercmp does not implement SemVer prerelease precedence. Use it only for core versions.
  if [[ "$a" != *-* && "$b" != *-* ]] && command -v vercmp >/dev/null 2>&1; then
    local r
    r="$(vercmp "$a" "$b" 2>/dev/null || true)"
    if [[ "$r" =~ ^-?[0-9]+$ ]]; then
      echo "$r"
      return 0
    fi
  fi

  # Split into core and tag
  local core_a tag_a core_b tag_b
  core_a="${a%%-*}"; tag_a="${a#*-}"
  core_b="${b%%-*}"; tag_b="${b#*-}"
  [[ "$tag_a" == "$a" ]] && tag_a=""
  [[ "$tag_b" == "$b" ]] && tag_b=""

  # Compare core numeric segments
  local IFS='.'
  local -a sa=() sb=()
  read -ra sa <<< "$core_a"
  read -ra sb <<< "$core_b"
  local i max_len=${#sa[@]}
  (( ${#sb[@]} > max_len )) && max_len=${#sb[@]}
  for (( i=0; i<max_len; i++ )); do
    local c
    c="$(_ahr_nscmp "${sa[$i]:-0}" "${sb[$i]:-0}")"
    if [[ "$c" != "0" ]]; then echo "$c"; return 0; fi
  done

  # Core equal — compare prerelease
  if [[ -z "$tag_a" && -z "$tag_b" ]]; then echo 0; return; fi
  if [[ -z "$tag_a" ]]; then echo 1; return; fi
  if [[ -z "$tag_b" ]]; then echo -1; return; fi

  local IFS='.'
  local -a pa=() pb=()
  read -ra pa <<< "$tag_a"
  read -ra pb <<< "$tag_b"
  local tmax=${#pa[@]}
  (( ${#pb[@]} > tmax )) && tmax=${#pb[@]}
  for (( i=0; i<tmax; i++ )); do
    local xa="${pa[$i]:-}" xb="${pb[$i]:-}"
    local c
    c="$(_ahr_preid_cmp "$xa" "$xb")"
    if [[ "$c" != "0" ]]; then echo "$c"; return 0; fi
  done
  echo 0
}
