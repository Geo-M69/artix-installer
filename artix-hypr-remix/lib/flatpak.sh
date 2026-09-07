#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

FLATPAK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLATPAK_CATALOG_LIB="${AHR_FLATPAK_CATALOG_LIB:-$FLATPAK_LIB_DIR/../config/artix-hypr-remix/bin/ahr-flatpak-catalog-lib.sh}"
FLATPAK_RUNTIME_LIB="${AHR_FLATPAK_RUNTIME_LIB_PATH:-$FLATPAK_LIB_DIR/../config/artix-hypr-remix/bin/ahr-flatpak-runtime-lib.sh}"

if [[ ! -r "$FLATPAK_CATALOG_LIB" ]]; then
	error "Flatpak catalog library not found: $FLATPAK_CATALOG_LIB"
fi
# shellcheck source=../config/artix-hypr-remix/bin/ahr-flatpak-catalog-lib.sh
source "$FLATPAK_CATALOG_LIB"
if [[ ! -r "$FLATPAK_RUNTIME_LIB" ]]; then
	error "Flatpak runtime library not found: $FLATPAK_RUNTIME_LIB"
fi
# shellcheck source=../config/artix-hypr-remix/bin/ahr-flatpak-runtime-lib.sh
source "$FLATPAK_RUNTIME_LIB"

flatpak_collect_profile_refs() {
	local catalog_path="$1"
	local profile_mode="$2"

	if ! ahr_flatpak_catalog_profile_refs "$catalog_path" "$profile_mode"; then
		error "Flatpak catalog validation or profile resolution failed: $catalog_path"
	fi
}

flatpak_require_command() {
	if ! ahr_flatpak_require_command; then
		error "flatpak command not found. Ensure packages/00-core.txt installs flatpak before phase 6."
	fi
}

flatpak_ensure_flathub_remote() {
	local dry_run="${1:-false}"

	if [[ "$dry_run" == "true" ]]; then
		info "Dry-run: would ensure Flathub remote exists for system scope"
		return 0
	fi

	if ahr_flatpak_system_flathub_configured; then
		info "Flathub remote already configured (system scope)"
		return 0
	fi

	info "Adding Flathub remote (system scope)"
	ahr_flatpak_system_add_flathub
}

flatpak_ref_installed() {
	local ref="$1"

	ahr_flatpak_system_ref_installed "$ref"
}

install_flatpak_profile() {
	local catalog_path="$1"
	local profile_mode="$2"
	local dry_run="${3:-false}"
	local -a refs=()
	local refs_output=""
	local ref
	local installed_count=0
	local present_count=0
	local failed_count=0

	print_summary() {
		info "Flatpak profile summary ($profile_mode): installed=$installed_count already_present=$present_count failed=$failed_count"
	}

	# Resolve synchronously. Bash does not propagate process-substitution
	# failures to mapfile, so capture the result before any Flatpak operation.
	if ! refs_output="$(flatpak_collect_profile_refs "$catalog_path" "$profile_mode")"; then
		error "Flatpak catalog validation or profile resolution failed: $catalog_path"
	fi
	if [[ -n "$refs_output" ]]; then
		mapfile -t refs <<< "$refs_output"
	fi

	if [[ "${#refs[@]}" -eq 0 ]]; then
		warn "No Flatpak refs found for profile mode '$profile_mode' in $catalog_path"
		return 0
	fi

	if [[ "$dry_run" == "true" ]]; then
		info "Dry-run: would install Flatpak refs (${#refs[@]}) for profile '$profile_mode'"
		printf '  - %s\n' "${refs[@]}"
		info "Flatpak profile summary ($profile_mode): installed=0 already_present=0 failed=0 would_install=${#refs[@]}"
		return 0
	fi

	flatpak_require_command
	flatpak_ensure_flathub_remote "$dry_run"

	for ref in "${refs[@]}"; do
		if flatpak_ref_installed "$ref"; then
			present_count=$((present_count + 1))
			info "Flatpak already installed: $ref"
		else
			if ahr_flatpak_system_install "$ref"; then
				installed_count=$((installed_count + 1))
			else
				failed_count=$((failed_count + 1))
				print_summary
				error "Flatpak install failed for ref: $ref"
			fi
		fi
	done

	print_summary
}
