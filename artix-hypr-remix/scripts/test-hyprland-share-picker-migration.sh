#!/usr/bin/env bash
# Focused regression coverage for delivery of OBS/portal picker placement
# rules to existing user Hyprland configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATION="$REPO_ROOT/config/artix-hypr-remix/migrations/20260906-hyprland-share-picker.sh"

PASS=0
FAIL=0
test_root="$(mktemp -d /tmp/ahr-share-picker-migration.XXXXXXXX)"
trap 'rm -rf "$test_root"' EXIT

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

float_rule='windowrule = match:class ^(hyprland-share-picker)$, float on'
center_rule='windowrule = match:class ^(hyprland-share-picker)$, center on'

[[ -x "$MIGRATION" ]] && pass "migration is executable" || fail "migration is not executable"

config_root="$test_root/config"
config_file="$config_root/hypr/hyprland.conf"
mkdir -p "$(dirname "$config_file")"
cat > "$config_file" <<'EOF'
# User-owned Hyprland configuration
$mod = SUPER
bind = $mod, Return, exec, foot
EOF
cp "$config_file" "$test_root/original.conf"

XDG_CONFIG_HOME="$config_root" HOME="$test_root/home" bash "$MIGRATION" >/dev/null
if grep -Fqx -- "$float_rule" "$config_file" && grep -Fqx -- "$center_rule" "$config_file" && grep -Fqx '# >>> AHR managed: hyprland-share-picker' "$config_file" && grep -Fqx '# <<< AHR managed: hyprland-share-picker' "$config_file" && grep -Fqx 'bind = $mod, Return, exec, foot' "$config_file"; then
  pass "migration adds both rules without replacing user configuration"
else
  fail "migration did not add the expected managed rules"
fi

backup_files=("$config_file".bak.*)
if [[ "${#backup_files[@]}" == 1 ]] && cmp -s "$test_root/original.conf" "${backup_files[0]}"; then
  pass "migration creates an exact pre-edit backup"
else
  fail "migration backup is missing or differs from the original"
fi

first_digest="$(sha256sum "$config_file" | awk '{print $1}')"
XDG_CONFIG_HOME="$config_root" HOME="$test_root/home" bash "$MIGRATION" >/dev/null
second_digest="$(sha256sum "$config_file" | awk '{print $1}')"
backup_files=("$config_file".bak.*)
if [[ "$first_digest" == "$second_digest" && "${#backup_files[@]}" == 1 ]] && [[ "$(grep -Fxc -- "$float_rule" "$config_file")" == 1 ]] && [[ "$(grep -Fxc -- "$center_rule" "$config_file")" == 1 ]]; then
  pass "migration is idempotent and does not create another backup"
else
  fail "migration is not idempotent"
fi

existing_root="$test_root/existing"
existing_file="$existing_root/hypr/hyprland.conf"
mkdir -p "$(dirname "$existing_file")"
printf '%s\n%s\n' "$float_rule" "$center_rule" > "$existing_file"
existing_digest="$(sha256sum "$existing_file" | awk '{print $1}')"
XDG_CONFIG_HOME="$existing_root" HOME="$test_root/home" bash "$MIGRATION" >/dev/null
if [[ "$(sha256sum "$existing_file" | awk '{print $1}')" == "$existing_digest" ]] && ! compgen -G "$existing_file.bak.*" >/dev/null; then
  pass "existing accepted rules remain untouched"
else
  fail "existing accepted rules were changed"
fi

missing_root="$test_root/missing"
XDG_CONFIG_HOME="$missing_root" HOME="$test_root/home" bash "$MIGRATION" >/dev/null
if [[ ! -e "$missing_root/hypr/hyprland.conf" ]]; then
  pass "missing user configuration is not created or replaced"
else
  fail "migration created missing user configuration"
fi

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
