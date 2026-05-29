#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
SERVICES_DIR="$SCRIPT_DIR/services"
CONFIG_DIR="$SCRIPT_DIR/config"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/checks.sh"
source "$LIB_DIR/pacman.sh"
source "$LIB_DIR/aur.sh"
source "$LIB_DIR/openrc.sh"
source "$LIB_DIR/dotfiles.sh"
source "$LIB_DIR/tty.sh"
source "$LIB_DIR/post_install.sh"

TARGET_PHASE=7
ASSUME_YES=false
DRY_RUN=false
SKIP_AUR=false
TARGET_USER="${SUDO_USER:-}"
TARGET_HOME=""

usage() {
	cat <<EOF
Usage: ./install.sh [options]

Phases:
	1. Preflight checks (Artix/OpenRC + required commands)
	2. Install packages from packages/[0-8]0-*.txt
	3. Enable safe OpenRC services from services/openrc-default.txt
	4. Deploy repo config/ into target user's ~/.config (copy + backup)
	5. Configure tty1 login to start Hyprland for target user
	6. Install AUR packages from packages/90-*.txt with safe paru bootstrap
	7. Prepare first-run + post-install framework for target user session

Options:
	--phase N     Run phases up to N (1-7). Default: 7
	--user NAME   Target non-root desktop user for phases 4-7
	--skip-aur    Skip phase 6 AUR install even when phase includes it
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

collect_aur_package_files() {
	find "$PACKAGES_DIR" -maxdepth 1 -type f -name '9[0-9]-*.txt' | sort
}

collect_packages() {
	local file pkg
	while IFS= read -r file; do
		while IFS= read -r pkg; do
			[[ -n "$pkg" ]] && printf '%s\n' "$pkg"
		done < <(parse_list_file "$file")
	done < <(collect_package_files) | awk '!seen[$0]++'
}

collect_aur_packages() {
	local file pkg
	while IFS= read -r file; do
		while IFS= read -r pkg; do
			[[ -z "$pkg" ]] && continue
			[[ "$pkg" == "paru" ]] && continue
			printf '%s\n' "$pkg"
		done < <(parse_list_file "$file")
	done < <(collect_aur_package_files) | awk '!seen[$0]++'
}

collect_services() {
	parse_list_file "$SERVICES_DIR/openrc-default.txt"
}

run_preflight() {
	info "[Phase 1/7] Running preflight checks"

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
	require_command id
	require_command getent

	info "Preflight checks passed"
}

run_package_phase() {
	local -a packages=()
	mapfile -t packages < <(collect_packages)

	info "[Phase 2/7] Installing packages"

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

	info "[Phase 3/7] Enabling safe OpenRC services"

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

run_aur_phase() {
	local -a packages=()

	if [[ "$SKIP_AUR" == true ]]; then
		info "[Phase 6/7] Skipping AUR phase due to --skip-aur"
		return 0
	fi

	mapfile -t packages < <(collect_aur_packages)

	info "[Phase 6/7] Installing AUR packages"

	if [[ "${#packages[@]}" -eq 0 ]]; then
		warn "No AUR packages found under $PACKAGES_DIR/90-*.txt"
		return 0
	fi

	resolve_target_user
	ensure_paru_bootstrap "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
	install_aur_packages "$TARGET_USER" "$DRY_RUN" "${packages[@]}"
}

resolve_target_user() {
	if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
		if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
			TARGET_USER="$SUDO_USER"
		fi
	fi

	if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
		error "Phases 4-7 require a non-root desktop user. Re-run with --user <name>."
	fi

	if ! id "$TARGET_USER" >/dev/null 2>&1; then
		error "Target user '$TARGET_USER' does not exist"
	fi

	TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
	if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
		error "Could not resolve home directory for user '$TARGET_USER'"
	fi
}

run_dotfiles_phase() {
	info "[Phase 4/7] Deploying dotfiles to target user"
	resolve_target_user
	deploy_config_tree "$CONFIG_DIR" "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
	initialize_xdg_user_dirs "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
}

run_tty_phase() {
	info "[Phase 5/7] Configuring tty1 Hyprland startup"
	resolve_target_user
	configure_tty_hyprland_autostart "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
}

run_post_install_phase() {
	info "[Phase 7/7] Preparing first-run + post-install framework"
	resolve_target_user
	prepare_post_install_framework "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--phase)
			shift
			[[ "$#" -gt 0 ]] || error "--phase requires a value (1-7)"
			[[ "$1" =~ ^[1-7]$ ]] || error "Invalid phase '$1'. Use 1, 2, 3, 4, 5, 6, or 7."
			TARGET_PHASE="$1"
			;;
		--skip-aur)
			SKIP_AUR=true
			;;
		--user)
			shift
			[[ "$#" -gt 0 ]] || error "--user requires a username"
			TARGET_USER="$1"
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
	if (( TARGET_PHASE >= 4 )); then
		info "Target desktop user for phases 4-7: ${TARGET_USER:-<unset>}"
	fi
	if (( TARGET_PHASE >= 6 )) && [[ "$SKIP_AUR" == true ]]; then
		info "AUR phase will be skipped (--skip-aur)"
	fi
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
if (( TARGET_PHASE >= 4 )); then
	run_dotfiles_phase
fi
if (( TARGET_PHASE >= 5 )); then
	run_tty_phase
fi
if (( TARGET_PHASE >= 6 )); then
	run_aur_phase
fi
if (( TARGET_PHASE >= 7 )); then
	run_post_install_phase
fi

info "Completed requested phases (1..$TARGET_PHASE)"
info "Installer phase run finished"
