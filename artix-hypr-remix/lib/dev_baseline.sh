#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

dev_baseline_run_as_user() {
  local target_user="$1"
  shift

  if command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$target_user" "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- "$@"
    return
  fi

  error "Neither sudo nor runuser is available to run commands as '$target_user'"
}

dev_baseline_ensure_directory() {
  local dir_path="$1"
  local mode="$2"
  local owner="$3"
  local dry_run="${4:-false}"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would ensure directory $dir_path (mode $mode, owner $owner)"
    return 0
  fi

  install -d -m "$mode" "$dir_path"
  chown "$owner" "$dir_path"
}

dev_baseline_backup_once_if_exists() {
  local file_path="$1"
  local dry_run="${2:-false}"
  local backup_path

  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  backup_path="${file_path}.ahr-dev-baseline.bak"
  if [[ -f "$backup_path" ]]; then
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would back up $file_path -> $backup_path"
    return 0
  fi

  cp -a "$file_path" "$backup_path"
  info "Created one-time backup: $backup_path"
}

dev_baseline_set_git_default_if_unset() {
  local target_user="$1"
  local target_home="$2"
  local git_key="$3"
  local git_value="$4"
  local dry_run="${5:-false}"
  local current_value=""

  current_value="$(dev_baseline_run_as_user "$target_user" env HOME="$target_home" git config --global --get "$git_key" 2>/dev/null || true)"

  if [[ -n "$current_value" ]]; then
    info "Git setting '$git_key' already set; keeping existing value"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would set git config --global $git_key $git_value"
    return 0
  fi

  dev_baseline_run_as_user "$target_user" env HOME="$target_home" git config --global "$git_key" "$git_value"
  info "Applied git default: $git_key=$git_value"
}

dev_baseline_update_managed_block() {
  local file_path="$1"
  local file_mode="$2"
  local owner="$3"
  local block_start="$4"
  local block_end="$5"
  local block_body="$6"
  local dry_run="${7:-false}"

  local tmp_file
  tmp_file="$(mktemp)"

  if [[ -f "$file_path" ]]; then
    awk -v start="$block_start" -v end="$block_end" '
      $0 == start { skipping=1; next }
      $0 == end { skipping=0; next }
      skipping == 0 { print }
    ' "$file_path" > "$tmp_file"
  else
    : > "$tmp_file"
  fi

  if [[ -s "$tmp_file" ]]; then
    printf '\n' >> "$tmp_file"
  fi

  printf '%s\n' "$block_start" >> "$tmp_file"
  printf '%s\n' "$block_body" >> "$tmp_file"
  printf '%s\n' "$block_end" >> "$tmp_file"

  if [[ -f "$file_path" ]] && cmp -s "$file_path" "$tmp_file"; then
    info "Managed baseline block is already current in $file_path"
    rm -f "$tmp_file"
    return 0
  fi

  dev_baseline_backup_once_if_exists "$file_path" "$dry_run"

  if [[ "$dry_run" == "true" ]]; then
    info "Dry-run: would update managed baseline block in $file_path"
    rm -f "$tmp_file"
    return 0
  fi

  mv "$tmp_file" "$file_path"
  chmod "$file_mode" "$file_path"
  chown "$owner" "$file_path"
  info "Updated managed baseline block in $file_path"
}

dev_baseline_apply_git_defaults() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  if ! command -v git >/dev/null 2>&1; then
    warn "git is not installed; skipping Git baseline defaults"
    return 0
  fi

  while IFS='=' read -r git_key git_value; do
    [[ -z "$git_key" ]] && continue
    dev_baseline_set_git_default_if_unset "$target_user" "$target_home" "$git_key" "$git_value" "$dry_run"
  done <<'EOF'
init.defaultBranch=main
fetch.prune=true
pull.rebase=false
rebase.autoStash=true
push.autoSetupRemote=true
EOF
}

dev_baseline_apply_ssh_defaults() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local ssh_dir ssh_config owner
  local block_start block_end block_body

  ssh_dir="$target_home/.ssh"
  ssh_config="$ssh_dir/config"
  owner="$target_user:$target_user"

  block_start="# >>> artix-hypr-remix managed ssh baseline >>>"
  block_end="# <<< artix-hypr-remix managed ssh baseline <<<"
  block_body=$'Host *\n  AddKeysToAgent yes\n  HashKnownHosts yes\n  ServerAliveInterval 60\n  ServerAliveCountMax 3'

  dev_baseline_ensure_directory "$ssh_dir" "0700" "$owner" "$dry_run"
  dev_baseline_update_managed_block "$ssh_config" "0600" "$owner" "$block_start" "$block_end" "$block_body" "$dry_run"
}

dev_baseline_apply_gpg_defaults() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"
  local gnupg_dir gpg_config gpg_agent_config owner
  local gpg_block_start gpg_block_end gpg_block_body
  local agent_block_start agent_block_end agent_block_body

  gnupg_dir="$target_home/.gnupg"
  gpg_config="$gnupg_dir/gpg.conf"
  gpg_agent_config="$gnupg_dir/gpg-agent.conf"
  owner="$target_user:$target_user"

  gpg_block_start="# >>> artix-hypr-remix managed gpg baseline >>>"
  gpg_block_end="# <<< artix-hypr-remix managed gpg baseline <<<"
  gpg_block_body=$'use-agent\nkeyid-format 0xlong\nwith-fingerprint\nno-emit-version'

  agent_block_start="# >>> artix-hypr-remix managed gpg-agent baseline >>>"
  agent_block_end="# <<< artix-hypr-remix managed gpg-agent baseline <<<"
  agent_block_body=$'default-cache-ttl 900\nmax-cache-ttl 7200\npinentry-program /usr/bin/pinentry-tty'

  dev_baseline_ensure_directory "$gnupg_dir" "0700" "$owner" "$dry_run"
  dev_baseline_update_managed_block "$gpg_config" "0600" "$owner" "$gpg_block_start" "$gpg_block_end" "$gpg_block_body" "$dry_run"

  if [[ -x /usr/bin/pinentry-tty || "$dry_run" == "true" ]]; then
    dev_baseline_update_managed_block "$gpg_agent_config" "0600" "$owner" "$agent_block_start" "$agent_block_end" "$agent_block_body" "$dry_run"
  else
    warn "pinentry-tty is not installed; skipping gpg-agent pinentry baseline"
  fi
}

apply_dev_baseline() {
  local target_user="$1"
  local target_home="$2"
  local dry_run="${3:-false}"

  info "Applying optional Git/GPG/SSH baseline for user '$target_user'"

  dev_baseline_apply_git_defaults "$target_user" "$target_home" "$dry_run"
  dev_baseline_apply_ssh_defaults "$target_user" "$target_home" "$dry_run"
  dev_baseline_apply_gpg_defaults "$target_user" "$target_home" "$dry_run"

  info "Git/GPG/SSH baseline phase completed"
}
