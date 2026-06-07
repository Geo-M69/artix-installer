#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# These patterns should not appear in Artix/OpenRC runtime paths.
declare -a RULE_PATTERNS=(
  '(^|[^[:alnum:]_])systemctl([^[:alnum:]_]|$)'
  '(^|[^[:alnum:]_])loginctl([^[:alnum:]_]|$)'
  '(^|[^[:alnum:]_])journalctl([^[:alnum:]_]|$)'
  '(^|[^[:alnum:]_])systemd-run([^[:alnum:]_]|$)'
  '/run/systemd'
)

declare -a RULE_MESSAGES=(
  "systemctl is not supported in OpenRC runtime paths"
  "loginctl is not supported in OpenRC runtime paths"
  "journalctl is not supported in OpenRC runtime paths"
  "systemd-run is not supported in OpenRC runtime paths"
  "/run/systemd paths are not supported in OpenRC runtime paths"
)

# Exceptions for guarded elogind loginctl in power-management paths.
# Policy: loginctl (part of elogind, not systemd) is accepted for suspend,
# hibernate, and lid-close actions when guarded with command detection
# (ahr_has_cmd / command -v) and paired with OpenRC fallbacks.
# Each exception is exact: specific file path + specific line regex.
declare -a EXCEPTION_PATH_FRAGMENTS=(
  "config/artix-hypr-remix/bin/ahr-system-suspend"
  "config/artix-hypr-remix/bin/ahr-system-hibernate"
  "config/hardware/laptop/openrc-module.sh"
  "config/hardware/laptop/packages.txt"
)
declare -a EXCEPTION_LINE_REGEXES=(
  '^(# elogind is always installed.*try loginctl first.*|if ahr_has_cmd loginctl && loginctl suspend 2>/dev/null; then)$'
  '^(# elogind is always installed.*try loginctl first.*|[[:space:]]*# loginctl hibernate was already attempted.*|[[:space:]]*if ahr_has_cmd loginctl && loginctl hibernate 2>/dev/null; then|[[:space:]]*if ahr_has_cmd loginctl; then)$'
  '^(# Uses loginctl.*falls back to pm-suspend.*|if command -v loginctl >/dev/null 2>&1 && loginctl suspend 2>/dev/null; then)$'
  '^# elogind'\''s loginctl suspend is unavailable\.$'
)
declare -a EXCEPTION_REASONS=(
  "Guarded elogind loginctl suspend with OpenRC fallbacks"
  "Guarded elogind loginctl hibernate with OpenRC fallbacks"
  "Guarded elogind loginctl lid-close with pm-suspend fallback"
  "elogind loginctl policy comment in laptop packages"
)

should_ignore_hit() {
  local rule_idx="$1"
  local hit="$2"

  local path line_text idx path_fragment line_regex

  path="${hit%%:*}"
  line_text="${hit#*:*:}"

  # Only apply loginctl exceptions to the loginctl rule (index 1).
  if [[ "$rule_idx" -ne 1 ]]; then
    return 1
  fi

  for idx in "${!EXCEPTION_PATH_FRAGMENTS[@]}"; do
    path_fragment="${EXCEPTION_PATH_FRAGMENTS[$idx]}"
    line_regex="${EXCEPTION_LINE_REGEXES[$idx]}"

    if [[ "$path" == *"$path_fragment" ]] && [[ "$line_text" =~ $line_regex ]]; then
      return 0
    fi
  done

  return 1
}

scan_rule() {
  local pattern="$1"
  local message="$2"
  local rule_idx="$3"
  local found=0

  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    if should_ignore_hit "$rule_idx" "$hit"; then
      continue
    fi
    found=1
    echo "VIOLATION: $message"
    echo "  $hit"
  done < <(
    grep -RInE "$pattern" \
      "$REPO_ROOT/install.sh" \
      "$REPO_ROOT/lib" \
      "$REPO_ROOT/config/artix-hypr-remix" \
      "$REPO_ROOT/config/hardware" \
      "$REPO_ROOT/scripts" \
      --include='*' \
      --include='*.sh' \
      --include='*.lua' \
      --include='*.conf' \
      --include='*.toml' \
      --include='*.jsonc' \
      --exclude='check-openrc-portability.sh' \
      || true
  )

  if [[ "$found" -eq 1 ]]; then
    return 0
  fi

  return 1
}

echo "Checking OpenRC portability in Artix runtime paths"

violations=0
for idx in "${!RULE_PATTERNS[@]}"; do
  pattern="${RULE_PATTERNS[$idx]}"
  message="${RULE_MESSAGES[$idx]}"
  if scan_rule "$pattern" "$message" "$idx"; then
    violations=1
  fi
done

if [[ "$violations" -ne 0 ]]; then
  echo
  echo "OpenRC portability check failed."
  exit 1
fi

echo "OpenRC portability check passed."
