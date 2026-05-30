#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

flatpak_trim_whitespace() {
	local text="$1"
	text="${text#"${text%%[![:space:]]*}"}"
	text="${text%"${text##*[![:space:]]}"}"
	printf '%s' "$text"
}

flatpak_parse_profile_file() {
	local file_path="$1"
	local raw line ref

	while IFS= read -r raw || [[ -n "$raw" ]]; do
		line="${raw%%#*}"
		line="$(flatpak_trim_whitespace "$line")"
		[[ -z "$line" ]] && continue

		ref="${line%%[[:space:]]*}"
		[[ -n "$ref" ]] && printf '%s\n' "$ref"
	done < "$file_path"
}

flatpak_require_profile_file() {
	local file_path="$1"

	if [[ ! -f "$file_path" ]]; then
		error "Flatpak profile file not found: $file_path"
	fi
}

flatpak_collect_profile_refs() {
	local profile_root="$1"
	local profile_mode="$2"
	local -a profile_files=()
	local file_path

	case "$profile_mode" in
		default)
			profile_files+=("$profile_root/default.txt")
			;;
		optional)
			profile_files+=("$profile_root/optional.txt")
			;;
		all)
			profile_files+=("$profile_root/default.txt" "$profile_root/optional.txt")
			;;
		none)
			return 0
			;;
		*)
			error "Invalid Flatpak profile mode '$profile_mode'. Use default, optional, all, or none."
			;;
	esac

	for file_path in "${profile_files[@]}"; do
		flatpak_require_profile_file "$file_path"
		flatpak_parse_profile_file "$file_path"
	done | awk '!seen[$0]++'
}

flatpak_require_command() {
	if ! command -v flatpak >/dev/null 2>&1; then
		error "flatpak command not found. Ensure packages/00-core.txt installs flatpak before phase 6."
	fi
}

flatpak_ensure_flathub_remote() {
	local dry_run="${1:-false}"

	if [[ "$dry_run" == "true" ]]; then
		info "Dry-run: would ensure Flathub remote exists for system scope"
		return 0
	fi

	if flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq "flathub"; then
		info "Flathub remote already configured (system scope)"
		return 0
	fi

	info "Adding Flathub remote (system scope)"
	flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

flatpak_ref_installed() {
	local ref="$1"

	flatpak info --system "$ref" >/dev/null 2>&1
}

install_flatpak_profile() {
	local profile_root="$1"
	local profile_mode="$2"
	local dry_run="${3:-false}"
	local -a refs=()
	local ref
	local installed_count=0
	local present_count=0
	local failed_count=0

	print_summary() {
		info "Flatpak profile summary ($profile_mode): installed=$installed_count already_present=$present_count failed=$failed_count"
	}

	mapfile -t refs < <(flatpak_collect_profile_refs "$profile_root" "$profile_mode")

	if [[ "${#refs[@]}" -eq 0 ]]; then
		warn "No Flatpak refs found for profile mode '$profile_mode' in $profile_root"
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
			if flatpak install --system --noninteractive flathub "$ref"; then
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
