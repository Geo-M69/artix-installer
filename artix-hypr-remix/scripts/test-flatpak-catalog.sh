#!/usr/bin/env bash
# Offline regression tests for the Phase 3a Flatpak catalog foundation.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_ROOT/config/artix-hypr-remix/default/flatpak/catalog.json"
CATALOG_LIB="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-flatpak-catalog-lib.sh"
FLATPAK_LIB="$REPO_ROOT/lib/flatpak.sh"
DEFAULT_FIXTURE="$REPO_ROOT/flatpaks/default.txt"
OPTIONAL_FIXTURE="$REPO_ROOT/flatpaks/optional.txt"

PASS=0
FAIL=0
TEST_TMP="$(mktemp -d /tmp/ahr-flatpak-catalog-test-XXXXXXXX)"
trap 'rm -rf "$TEST_TMP"' EXIT

pass() { printf 'PASS: %s\n' "$1"; ((PASS+=1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; ((FAIL+=1)); }

source "$CATALOG_LIB"

fixture_refs() {
  awk '
    {
      sub(/#.*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if (length > 0) print $1
    }
  ' "$1"
}

assert_invalid_filter() {
  local label="$1" filter="$2" fixture="$TEST_TMP/invalid.json"
  jq "$filter" "$CATALOG" > "$fixture"
  if ahr_flatpak_catalog_validate "$fixture" >/dev/null 2>&1; then
    fail "$label"
  else
    pass "$label"
  fi
}

if ahr_flatpak_catalog_validate "$CATALOG"; then
  pass "canonical catalog validates"
else
  fail "canonical catalog validates"
fi

catalog_count="$(jq '.applications | length' "$CATALOG")"
[[ "$catalog_count" == "13" ]] && pass "catalog contains 13 applications" || fail "catalog contains 13 applications"

default_expected="$(fixture_refs "$DEFAULT_FIXTURE")"
default_actual="$(ahr_flatpak_catalog_profile_refs "$CATALOG" default)"
[[ "$default_actual" == "$default_expected" ]] && pass "default profile exactly matches legacy fixture" || fail "default profile exactly matches legacy fixture"

optional_expected="$(fixture_refs "$OPTIONAL_FIXTURE")"
optional_actual="$(ahr_flatpak_catalog_profile_refs "$CATALOG" optional)"
[[ "$optional_actual" == "$optional_expected" ]] && pass "optional profile exactly matches legacy fixture" || fail "optional profile exactly matches legacy fixture"

all_expected="$(printf '%s\n%s\n' "$default_expected" "$optional_expected")"
all_actual="$(ahr_flatpak_catalog_profile_refs "$CATALOG" all)"
[[ "$all_actual" == "$all_expected" ]] && pass "all preserves default-then-optional order" || fail "all preserves default-then-optional order"

none_actual="$(ahr_flatpak_catalog_profile_refs "$CATALOG" none)"
[[ -z "$none_actual" ]] && pass "none resolves to no applications" || fail "none resolves to no applications"

if ahr_flatpak_catalog_profile_refs "$CATALOG" invalid >/dev/null 2>&1; then
  fail "invalid profile mode is rejected"
else
  pass "invalid profile mode is rejected"
fi

assert_invalid_filter "wrong schema version is rejected" '.schema_version = 2'
assert_invalid_filter "missing schema version is rejected" 'del(.schema_version)'
assert_invalid_filter "duplicate slug is rejected" '.applications[1].slug = .applications[0].slug'
assert_invalid_filter "duplicate Flatpak ID is rejected" '.applications[1].flatpak_id = .applications[0].flatpak_id'
assert_invalid_filter "unsafe Flatpak ID is rejected" '.applications[0].flatpak_id = "../../unsafe"'
assert_invalid_filter "invalid category is rejected" '.applications[0].category = "browser"'
assert_invalid_filter "invalid profile membership is rejected" '.applications[0].profile = "all"'
assert_invalid_filter "invalid support status is rejected" '.applications[0].support = "supported"'
assert_invalid_filter "invalid slug is rejected" '.applications[0].slug = "Zen Browser"'
assert_invalid_filter "invalid desktop entry is rejected" '.applications[0].desktop_entry = "../../unsafe.desktop"'
assert_invalid_filter "non-boolean proprietary flag is rejected" '.applications[0].proprietary = "false"'
assert_invalid_filter "non-boolean unofficial flag is rejected" '.applications[0].unofficial = 0'

for required_field in slug name flatpak_id category profile support proprietary unofficial desktop_entry; do
  invalid_required="$TEST_TMP/missing-$required_field.json"
  jq --arg field "$required_field" 'del(.applications[0][$field])' "$CATALOG" > "$invalid_required"
  if ahr_flatpak_catalog_validate "$invalid_required" >/dev/null 2>&1; then
    fail "missing required field is rejected: $required_field"
  else
    pass "missing required field is rejected: $required_field"
  fi
done

for category in communication office-writing media creative development gaming system-utilities; do
  allowed="$TEST_TMP/category-$category.json"
  jq --arg value "$category" '.applications[0].category = $value' "$CATALOG" > "$allowed"
  if ahr_flatpak_catalog_validate "$allowed" >/dev/null 2>&1; then
    pass "allowed category validates: $category"
  else
    fail "allowed category validates: $category"
  fi
done

for support in default recommended optional experimental; do
  allowed="$TEST_TMP/support-$support.json"
  jq --arg value "$support" '.applications[0].support = $value' "$CATALOG" > "$allowed"
  if ahr_flatpak_catalog_validate "$allowed" >/dev/null 2>&1; then
    pass "allowed support status validates: $support"
  else
    fail "allowed support status validates: $support"
  fi
done

# Source the installer adapter only after library-only validation tests.
source "$FLATPAK_LIB"

dry_run_output="$(install_flatpak_profile "$CATALOG" default true)"
if grep -q 'would install Flatpak refs (4)' <<< "$dry_run_output" \
  && grep -q 'would_install=4' <<< "$dry_run_output" \
  && [[ "$(grep -c '^  - ' <<< "$dry_run_output")" == "4" ]]; then
  pass "default dry-run output preserves count and item format"
else
  fail "default dry-run output preserves count and item format"
fi

# Invalid data must fail before the Flatpak executable is touched.
stub_dir="$TEST_TMP/stub"
stub_log="$TEST_TMP/flatpak.log"
mkdir -p "$stub_dir"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$AHR_TEST_FLATPAK_LOG"\nexit 0\n' > "$stub_dir/flatpak"
chmod +x "$stub_dir/flatpak"
invalid_catalog="$TEST_TMP/install-invalid.json"
jq '.schema_version = 2' "$CATALOG" > "$invalid_catalog"
invalid_install_status=0
(
  export PATH="$stub_dir:$PATH"
  export AHR_TEST_FLATPAK_LOG="$stub_log"
  install_flatpak_profile "$invalid_catalog" default false
) >/dev/null 2>&1 || invalid_install_status=$?
if (( invalid_install_status != 0 )) && [[ ! -e "$stub_log" ]]; then
  pass "invalid catalog fails before any Flatpak operation"
else
  fail "invalid catalog fails before any Flatpak operation"
fi

# The installer adapter now shares runtime primitives with `ahr flatpak`; keep
# the established profile idempotency behavior pinned during that refactor.
: > "$stub_log"
profile_output="$(
  export PATH="$stub_dir:$PATH"
  export AHR_TEST_FLATPAK_LOG="$stub_log"
  install_flatpak_profile "$CATALOG" default false
)"
if [[ "$profile_output" == *'installed=0 already_present=4 failed=0'* ]] \
  && [[ "$(grep -c '^info --system ' "$stub_log")" == 4 ]] \
  && ! grep -q '^install --system ' "$stub_log"; then
  pass "profile installer remains idempotent with shared runtime helpers"
else
  fail "profile installer remains idempotent with shared runtime helpers"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
