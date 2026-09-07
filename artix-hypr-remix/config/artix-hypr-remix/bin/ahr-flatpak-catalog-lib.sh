#!/usr/bin/env bash
# ahr-flatpak-catalog-lib.sh — schema-v1 Flatpak catalog reader and validator.
#
# Catalog JSON is data, never shell input. Consumers must use these functions
# instead of reading its structure directly.

AHR_FLATPAK_CATALOG_SCHEMA_VERSION=1

ahr_flatpak_catalog_error() {
  printf 'Flatpak catalog error: %s\n' "$1" >&2
}

ahr_flatpak_catalog_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    ahr_flatpak_catalog_error "jq is required to read and validate the catalog"
    return 1
  fi
}

ahr_flatpak_catalog_validate() {
  local catalog_path="$1"

  ahr_flatpak_catalog_require_jq || return 1

  if [[ ! -f "$catalog_path" ]]; then
    ahr_flatpak_catalog_error "file not found: $catalog_path"
    return 1
  fi
  if [[ ! -r "$catalog_path" ]]; then
    ahr_flatpak_catalog_error "file is not readable: $catalog_path"
    return 1
  fi

  if ! jq -e --argjson schema "$AHR_FLATPAK_CATALOG_SCHEMA_VERSION" '
    def required_fields:
      ["slug", "name", "flatpak_id", "category", "profile", "support",
       "proprietary", "unofficial", "desktop_entry"];
    def allowed_category:
      . == "communication" or . == "office-writing" or . == "media" or
      . == "creative" or . == "development" or . == "gaming" or
      . == "system-utilities";
    def allowed_profile: . == "default" or . == "optional";
    def allowed_support:
      . == "default" or . == "recommended" or . == "optional" or
      . == "experimental";
    def safe_slug: test("^[a-z0-9]+(-[a-z0-9]+)*$");
    def safe_flatpak_id:
      test("^[A-Za-z][A-Za-z0-9_-]*(\\.[A-Za-z][A-Za-z0-9_-]*){2,}$");
    def safe_desktop_entry:
      test("^[A-Za-z0-9][A-Za-z0-9._-]*\\.desktop$");
    def valid_app:
      type == "object" and
      (required_fields - keys | length == 0) and
      (.slug | type == "string" and length > 0 and safe_slug) and
      (.name | type == "string" and length > 0) and
      (.flatpak_id | type == "string" and safe_flatpak_id) and
      (.category | type == "string" and allowed_category) and
      (.profile | type == "string" and allowed_profile) and
      (.support | type == "string" and allowed_support) and
      (.proprietary | type == "boolean") and
      (.unofficial | type == "boolean") and
      (.desktop_entry | type == "string" and safe_desktop_entry);

    type == "object" and
    .schema_version == $schema and
    (.applications | type == "array" and length > 0) and
    all(.applications[]; valid_app) and
    ([.applications[].slug] | length == (unique | length)) and
    ([.applications[].flatpak_id] | length == (unique | length))
  ' "$catalog_path" >/dev/null 2>&1; then
    ahr_flatpak_catalog_error "schema validation failed: $catalog_path"
    return 1
  fi
}

ahr_flatpak_catalog_profile_refs() {
  local catalog_path="$1"
  local profile_mode="$2"

  ahr_flatpak_catalog_validate "$catalog_path" || return 1

  case "$profile_mode" in
    default|optional)
      jq -r --arg profile "$profile_mode" \
        '.applications[] | select(.profile == $profile) | .flatpak_id' \
        "$catalog_path"
      ;;
    all)
      jq -r '.applications[].flatpak_id' "$catalog_path"
      ;;
    none)
      return 0
      ;;
    *)
      ahr_flatpak_catalog_error \
        "invalid profile mode '$profile_mode'; use default, optional, all, or none"
      return 1
      ;;
  esac
}

# Emit every catalog application as one tab-separated row, preserving catalog
# order. The row format is an internal library contract for read-only callers:
# slug, name, Flatpak ID, category, profile, support, proprietary, unofficial,
# expected desktop entry.
ahr_flatpak_catalog_rows() {
  local catalog_path="$1"

  ahr_flatpak_catalog_validate "$catalog_path" || return 1

  jq -r '
    .applications[] |
    [.slug, .name, .flatpak_id, .category, .profile, .support,
     .proprietary, .unofficial, .desktop_entry] | @tsv
  ' "$catalog_path"
}

# Validate a single category value against the schema-v1 allowed set.
ahr_flatpak_catalog_valid_category() {
  case "$1" in
    communication|office-writing|media|creative|development|gaming|system-utilities)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Emit catalog rows for one exact category, preserving catalog order.
ahr_flatpak_catalog_rows_by_category() {
  local catalog_path="$1"
  local category="$2"

  if ! ahr_flatpak_catalog_valid_category "$category"; then
    ahr_flatpak_catalog_error "invalid category: $category"
    return 1
  fi

  ahr_flatpak_catalog_validate "$catalog_path" || return 1

  jq -r --arg category "$category" '
    .applications[] | select(.category == $category) |
    [.slug, .name, .flatpak_id, .category, .profile, .support,
     .proprietary, .unofficial, .desktop_entry] | @tsv
  ' "$catalog_path"
}

# Search stable identity, display name, Flatpak ID, and category without
# changing catalog order. Search is intentionally local and offline.
ahr_flatpak_catalog_search_rows() {
  local catalog_path="$1"
  local query="$2"

  if [[ -z "$query" ]]; then
    ahr_flatpak_catalog_error "search query must not be empty"
    return 1
  fi

  ahr_flatpak_catalog_validate "$catalog_path" || return 1

  jq -r --arg query "$query" '
    ($query | ascii_downcase) as $needle |
    .applications[] |
    select(
      [.slug, .name, .flatpak_id, .category] |
      any(.[]; ascii_downcase | contains($needle))
    ) |
    [.slug, .name, .flatpak_id, .category, .profile, .support,
     .proprietary, .unofficial, .desktop_entry] | @tsv
  ' "$catalog_path"
}

# Look up one application by an exact, case-insensitive slug, display name, or
# Flatpak ID. Names are not schema-unique, so an ambiguous match is rejected.
ahr_flatpak_catalog_lookup_row() {
  local catalog_path="$1"
  local selector="$2"
  local match_count

  if [[ -z "$selector" ]]; then
    ahr_flatpak_catalog_error "application selector must not be empty"
    return 1
  fi

  ahr_flatpak_catalog_validate "$catalog_path" || return 1

  match_count="$(jq -r --arg selector "$selector" '
    ($selector | ascii_downcase) as $needle |
    [.applications[] |
      select(
        (.slug | ascii_downcase) == $needle or
        (.name | ascii_downcase) == $needle or
        (.flatpak_id | ascii_downcase) == $needle
      )] | length
  ' "$catalog_path")"

  case "$match_count" in
    1)
      jq -r --arg selector "$selector" '
        ($selector | ascii_downcase) as $needle |
        .applications[] |
        select(
          (.slug | ascii_downcase) == $needle or
          (.name | ascii_downcase) == $needle or
          (.flatpak_id | ascii_downcase) == $needle
        ) |
        [.slug, .name, .flatpak_id, .category, .profile, .support,
         .proprietary, .unofficial, .desktop_entry] | @tsv
      ' "$catalog_path"
      ;;
    0)
      ahr_flatpak_catalog_error "no application matches: $selector"
      return 1
      ;;
    *)
      ahr_flatpak_catalog_error "application selector is ambiguous: $selector"
      return 1
      ;;
  esac
}

# Note: local system-installation state is intentionally not queried here.
# Catalog interpretation stays in this library; every Flatpak execution,
# including the `flatpak info --system` state checks used by
# `ahr flatpak status`, belongs to the runtime library and is composed by the
# CLI from the read-only row functions above.
