#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# These patterns should not appear in Artix/OpenRC runtime paths.
declare -a RULES=(
  "systemctl --user|systemd user services are not supported in OpenRC runtime paths"
)

should_ignore_hit() {
  local pattern="$1"
  local hit="$2"
  # No runtime-path exceptions currently allowed.
  : "$pattern" "$hit"
  return 1
}

scan_rule() {
  local pattern="$1"
  local message="$2"
  local found=0

  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    if should_ignore_hit "$pattern" "$hit"; then
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
      "$REPO_ROOT/scripts" \
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
for rule in "${RULES[@]}"; do
  pattern="${rule%%|*}"
  message="${rule#*|}"
  if scan_rule "$pattern" "$message"; then
    violations=1
  fi
done

if [[ "$violations" -ne 0 ]]; then
  echo
  echo "OpenRC portability check failed."
  exit 1
fi

echo "OpenRC portability check passed."
