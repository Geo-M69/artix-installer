#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
SERVICES_DIR="$SCRIPT_DIR/services"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/checks.sh"
source "$LIB_DIR/pacman.sh"
source "$LIB_DIR/openrc.sh"

TARGET_PHASE=3
ASSUME_YES=false
DRY_RUN=false

usage() {
	cat <<EOF
Usage: ./install.sh [options]

Phases:
	1. Preflight checks (Artix/OpenRC + required commands)
	2. Install packages from packages/[0-8]0-*.txt
	3. Enable safe OpenRC services from services/openrc-default.txt

Options:
	--phase N     Run phases up to N (1-3). Default: 3
	--dry-run     Print planned actions without changing the system
	-y, --yes     Do not ask for confirmation
	-h, --help    Show this help
EOF
}

trim_whitespace() {
	local text="$1"
	text="${text#"${text%%[![:space:]]*}"}"
	text="${text%"${text##*[![:space:]]}"}"
	printf '%s' "$text"
}

parse_list_file() {
	local file_path="$1"
	local raw line first_token

	while IFS= read -r raw || [[ -n "$raw" ]]; do
		line="${raw%%#*}"
		line="$(trim_whitespace "$line")"
		[[ -z "$line" ]] && continue

		# Keep only the first token so annotation text is ignored.
		first_token="${line%%[[:space:]]*}"
		[[ -n "$first_token" ]] && printf '%s\n' "$first_token"
	done < "$file_path"
}

collect_package_files() {
	find "$PACKAGES_DIR" -maxdepth 1 -type f -name '[0-8][0-9]-*.txt' | sort
}

collect_packages() {
	local file pkg
	while IFS= read -r file; do
		while IFS= read -r pkg; do
			[[ -n "$pkg" ]] && printf '%s\n' "$pkg"
		done < <(parse_list_file "$file")
	done < <(collect_package_files) | awk '!seen[$0]++'
}

collect_services() {
	parse_list_file "$SERVICES_DIR/openrc-default.txt"
}

run_preflight() {
	info "[Phase 1/3] Running preflight checks"

	if [[ "$EUID" -ne 0 ]]; then
		if [[ "$DRY_RUN" == true ]]; then
			warn "Dry-run without root: system-changing steps are not executed"
		else
			error "Please run as root (or with sudo)."
		fi
	fi

	if [[ ! -f /etc/artix-release ]]; then
		warn "This does not look like Artix Linux (/etc/artix-release missing)."
	fi

	require_command pacman
	require_command rc-update
	require_command rc-service

	info "Preflight checks passed"
}

run_package_phase() {
	local -a packages=()
	mapfile -t packages < <(collect_packages)

	info "[Phase 2/3] Installing packages"

	if [[ "${#packages[@]}" -eq 0 ]]; then
		warn "No packages found under $PACKAGES_DIR"
		return 0
	fi

	if [[ "$DRY_RUN" == true ]]; then
		info "Dry-run: would install ${#packages[@]} packages"
		printf '  - %s\n' "${packages[@]}"
		return 0
	fi

	refresh_package_databases
	install_packages "${packages[@]}"
}

run_service_phase() {
	local -a services=()
	local service

	mapfile -t services < <(collect_services)

	info "[Phase 3/3] Enabling safe OpenRC services"

	if [[ "${#services[@]}" -eq 0 ]]; then
		warn "No services found in $SERVICES_DIR/openrc-default.txt"
		return 0
	fi

	if [[ "$DRY_RUN" == true ]]; then
		info "Dry-run: would enable/start ${#services[@]} services"
		printf '  - %s\n' "${services[@]}"
		return 0
	fi

	for service in "${services[@]}"; do
		enable_service "$service" "default" "true"
	done
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--phase)
			shift
			[[ "$#" -gt 0 ]] || error "--phase requires a value (1-3)"
			[[ "$1" =~ ^[1-3]$ ]] || error "Invalid phase '$1'. Use 1, 2, or 3."
			TARGET_PHASE="$1"
			;;
		--dry-run)
			DRY_RUN=true
			;;
		-y|--yes)
			ASSUME_YES=true
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			error "Unknown option: $1"
			;;
	esac
	shift
done

if [[ "$ASSUME_YES" == false ]]; then
	info "Installer will run up to phase $TARGET_PHASE"
	info "Dotfiles and Hyprland session bootstrap are intentionally out of scope for this run"
	read -r -p "Continue? [y/N]: " response
	case "${response,,}" in
		y|yes) ;;
		*) info "Aborted by user"; exit 0 ;;
	esac
fi

if (( TARGET_PHASE >= 1 )); then
	run_preflight
fi
if (( TARGET_PHASE >= 2 )); then
	run_package_phase
fi
if (( TARGET_PHASE >= 3 )); then
	run_service_phase
fi

info "Completed requested phases (1..$TARGET_PHASE)"
info "Next phases (dotfiles + Hyprland start from TTY) are intentionally left for manual development"
