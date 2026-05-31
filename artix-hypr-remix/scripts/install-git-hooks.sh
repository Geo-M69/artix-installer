#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hooks_dir="$repo_root/artix-hypr-remix/.githooks"
pre_push_hook="$hooks_dir/pre-push"

if [[ ! -f "$pre_push_hook" ]]; then
  echo "Expected pre-push hook not found: $pre_push_hook" >&2
  exit 1
fi

chmod +x "$pre_push_hook"
git -C "$repo_root" config core.hooksPath "$hooks_dir"

echo "Git hooks installed."
echo "core.hooksPath=$(git -C "$repo_root" config --get core.hooksPath)"
