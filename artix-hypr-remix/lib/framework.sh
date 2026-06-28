#!/usr/bin/env bash
# framework.sh — Framework version metadata management for the installer.
# Sourced by install.sh.  Provides functions to read the repo's framework
# version and deploy it to the target user's ~/.config/artix-hypr-remix/.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

# ── Paths ──────────────────────────────────────────────────────────
# These are relative to the repo checkout (source), not the install target.
REPO_FRAMEWORK_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/artix-hypr-remix/framework.json"

# ── Helpers ────────────────────────────────────────────────────────

# Read a top-level string value from framework.json using jq (preferred)
# with a sed fallback.  Returns 1 if the value cannot be read.
framework_read_json_value() {
  local json_path="$1"
  local key="$2"

  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // ""' "$json_path" 2>/dev/null && return 0
  fi

  # Sed fallback for environments without jq.
  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$json_path" 2>/dev/null | head -n1
}

# Return the version string from the repo's framework.json.
# Prints nothing and returns 1 if the file is missing.
framework_source_version() {
  if [[ ! -f "$REPO_FRAMEWORK_JSON" ]]; then
    return 1
  fi
  framework_read_json_value "$REPO_FRAMEWORK_JSON" "version"
}

# Return the update_source URL from the repo's framework.json.
framework_source_url() {
  if [[ ! -f "$REPO_FRAMEWORK_JSON" ]]; then
    return 1
  fi
  framework_read_json_value "$REPO_FRAMEWORK_JSON" "update_source"
}

# Return the channel from the repo's framework.json.
framework_source_channel() {
  if [[ ! -f "$REPO_FRAMEWORK_JSON" ]]; then
    return 1
  fi
  framework_read_json_value "$REPO_FRAMEWORK_JSON" "channel"
}

# ── Deploy ─────────────────────────────────────────────────────────

# Deploy framework.json to the target user's framework root.
# Writes the repo version and sets updated_at to the current timestamp.
# Ownership is set to target_user.
framework_deploy_metadata() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  local framework_root="$target_home/.config/artix-hypr-remix"
  local dest="$framework_root/framework.json"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would deploy framework metadata to $dest"
    return 0
  fi

  install -d -m 0755 "$framework_root"

  local version
  version="$(framework_source_version)" || version="0.0.0"
  local channel
  channel="$(framework_source_channel)" || channel="stable"
  local update_source
  update_source="$(framework_source_url)" || update_source=""

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat > "$dest" <<EOF
{
  "version": "$version",
  "revision": null,
  "channel": "$channel",
  "update_source": "$update_source",
  "updated_at": "$now"
}
EOF

  chown "$target_user:$target_user" "$dest"
  info "Deployed framework metadata: $dest (version $version)"
}
