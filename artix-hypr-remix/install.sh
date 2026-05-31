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
source "$LIB_DIR/hardware.sh"
source "$LIB_DIR/flatpak.sh"
source "$LIB_DIR/post_install.sh"

TARGET_PHASE=7
ASSUME_YES=false
DRY_RUN=false
SKIP_AUR=false
SKIP_FLATPAK=false
STARTUP_MODE="tty"
GREETD_MODE="greeter"
HARDWARE_MODE="recommend"
FLATPAK_PROFILE="default"
TARGET_USER="${SUDO_USER:-}"
TARGET_HOME=""
HOST_POLICY="${AHR_HOST_POLICY:-artix}"
INSTALL_LOG_FILE="${AHR_INSTALL_LOG_FILE:-/var/log/artix-hypr-remix-install.log}"
ACTIVE_INSTALL_LOG_FILE=""

usage() {
	cat <<EOF
Usage: ./install.sh [options]

Phases:
	1. Preflight checks (host policy + OpenRC command requirements)
	2. Install packages from packages/[0-8]0-*.txt
	3. Enable safe OpenRC services from services/openrc-default.txt
	4. Deploy repo config/ into target user's ~/.config (copy + backup)
	5. Configure startup mode for Hyprland (tty or greetd)
	6. Install AUR packages and Flatpak app profiles
	7. Prepare first-run + post-install framework and migration state

Options:
	--phase N     Run phases up to N (1-7). Default: 7
	--user NAME   Target non-root desktop user for phases 4-7
	--startup-mode MODE  Startup mode for phase 5: tty (default) or greetd
	--greetd-mode MODE   greetd session policy: autologin or greeter (default)
	--hardware-mode MODE Hardware package mode for phase 2: recommend (default), auto, or off
	--flatpak-profile MODE Flatpak app profile for phase 6: default (default), optional, all, or none
	--host-policy MODE Host policy for preflight: artix (default), vm, or any
	--skip-aur    Skip phase 6 AUR install even when phase includes it
	--skip-flatpak Skip Flatpak profile install in phase 6
	--dry-run     Print planned actions without changing the system
	-y, --yes     Do not ask for confirmation
	-h, --help    Show this help
EOF
}

validate_startup_mode() {
	local mode="$1"

	case "$mode" in
		tty|greetd) return 0 ;;
		*) error "Invalid startup mode '$mode'. Use tty or greetd." ;;
	esac
}

validate_greetd_mode() {
	local mode="$1"

	case "$mode" in
		autologin|greeter) return 0 ;;
		*) error "Invalid greetd mode '$mode'. Use autologin or greeter." ;;
	esac
}

validate_hardware_mode() {
	local mode="$1"

	case "$mode" in
		recommend|auto|off) return 0 ;;
		*) error "Invalid hardware mode '$mode'. Use recommend, auto, or off." ;;
	esac
}

validate_flatpak_profile() {
	local mode="$1"

	case "$mode" in
		default|optional|all|none) return 0 ;;
		*) error "Invalid Flatpak profile '$mode'. Use default, optional, all, or none." ;;
	esac
}

validate_host_policy() {
	local mode="$1"

	case "$mode" in
		artix|vm|any) return 0 ;;
		*) error "Invalid host policy '$mode'. Use artix, vm, or any." ;;
	esac
}

setup_install_logging() {
	local requested_path log_dir fallback_path

	requested_path="$INSTALL_LOG_FILE"
	ACTIVE_INSTALL_LOG_FILE="$requested_path"
	log_dir="$(dirname "$requested_path")"

	if ! mkdir -p "$log_dir" >/dev/null 2>&1 || ! touch "$requested_path" >/dev/null 2>&1; then
		fallback_path="/tmp/artix-hypr-remix-install-$(date +%Y%m%d-%H%M%S)-$$.log"
		ACTIVE_INSTALL_LOG_FILE="$fallback_path"
		mkdir -p "$(dirname "$fallback_path")" >/dev/null 2>&1 || true
		touch "$fallback_path"
	fi

	chmod 0644 "$ACTIVE_INSTALL_LOG_FILE" >/dev/null 2>&1 || true
	exec > >(tee -a "$ACTIVE_INSTALL_LOG_FILE") 2>&1
	info "Installer log file: $ACTIVE_INSTALL_LOG_FILE"
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

filter_installable_packages() {
	local -n out_ref=$1
	shift
	local pkg

	out_ref=()

	if [[ "$DRY_RUN" == "true" ]]; then
		out_ref=("$@")
		return 0
	fi

	for pkg in "$@"; do
		if pacman -Si "$pkg" >/dev/null 2>&1; then
			out_ref+=("$pkg")
		else
			warn "Skipping unavailable package from hardware profile: $pkg" >&2
		fi
	done
}

validate_package_availability() {
	local phase_label="$1"
	shift
	local -a pkgs=("$@")
	local -a missing=()
	local pkg

	if [[ "${#pkgs[@]}" -eq 0 ]]; then
		return 0
	fi

	info "Validating package availability for $phase_label (${#pkgs[@]} packages)"

	for pkg in "${pkgs[@]}"; do
		if ! pacman -Si "$pkg" >/dev/null 2>&1; then
			missing+=("$pkg")
		fi
	done

	if [[ "${#missing[@]}" -gt 0 ]]; then
		warn "Missing packages detected for $phase_label:"
		printf '  - %s\n' "${missing[@]}" >&2
		error "Package availability check failed for $phase_label. Update package manifests or repository configuration and retry."
	fi

	info "Package availability check passed for $phase_label"
}

resolve_hardware_mode_choice() {
	local -a recommended_packages=("$@")
	local response

	case "$HARDWARE_MODE" in
		off)
			info "Hardware profile package recommendations are disabled (--hardware-mode off)"
			return 1
			;;
		auto)
			info "Applying hardware profile recommendations automatically (--hardware-mode auto)"
			return 0
			;;
		recommend)
			if [[ "$ASSUME_YES" == "true" ]]; then
				info "Applying hardware profile recommendations because --yes was provided"
				return 0
			fi

			if [[ ! -t 0 ]]; then
				warn "Non-interactive terminal: skipping hardware package recommendations"
				return 1
			fi

			info "Recommended hardware packages (${#recommended_packages[@]}): ${recommended_packages[*]}"
			if command -v gum >/dev/null 2>&1; then
				if gum confirm "Install recommended hardware package set now?"; then
					return 0
				fi
				return 1
			fi

			read -r -p "Install recommended hardware package set now? [y/N]: " response
			case "${response,,}" in
				y|yes) return 0 ;;
				*) return 1 ;;
			esac
			;;
		*)
			error "Unknown hardware mode: $HARDWARE_MODE"
			;;
	esac
}

persist_hardware_profile_snapshot() {
	local profile_path

	profile_path="$(hardware_default_profile_path)"

	if [[ "$DRY_RUN" == "true" ]]; then
		info "Dry-run: would write hardware profile snapshot to $profile_path"
		return 0
	fi

	hardware_write_profile_json "$profile_path"
	info "Hardware profile snapshot written to $profile_path"
}

collect_hardware_recommended_packages() {
	local -n out_ref=$1
	local -a profiles=()
	local -a candidate_packages=()
	local -a installable_packages=()
	local profile_root

	out_ref=()

	profile_root="$CONFIG_DIR/hardware"

	mapfile -t profiles < <(hardware_detect_profiles)
	if [[ "${#profiles[@]}" -eq 0 ]]; then
		info "Hardware detection: no matching profile packages"
		persist_hardware_profile_snapshot
		return 0
	fi

	info "Hardware detection summary: $(hardware_summary_line)"
	info "Matched hardware profiles: ${profiles[*]}"

	mapfile -t candidate_packages < <(hardware_collect_profile_packages "$profile_root" "${profiles[@]}")
	if [[ "${#candidate_packages[@]}" -eq 0 ]]; then
		warn "No package stubs found for detected hardware profiles under $profile_root"
		persist_hardware_profile_snapshot
		return 0
	fi

	filter_installable_packages installable_packages "${candidate_packages[@]}"
	if [[ "${#installable_packages[@]}" -eq 0 ]]; then
		warn "Hardware profile packages were detected but none are installable"
		persist_hardware_profile_snapshot
		return 0
	fi

	persist_hardware_profile_snapshot

	if resolve_hardware_mode_choice "${installable_packages[@]}"; then
		out_ref=("${installable_packages[@]}")
	fi
}

run_preflight() {
	info "[Phase 1/7] Running preflight checks"
	local allow_non_vm="${AHR_ALLOW_NON_VM_TESTING:-0}"
	local effective_host_policy="$HOST_POLICY"

	if [[ "$EUID" -ne 0 ]]; then
		if [[ "$DRY_RUN" == true ]]; then
			warn "Dry-run without root: system-changing steps are not executed"
		else
			error "Please run as root (or with sudo)."
		fi
	fi

	if [[ "$allow_non_vm" == "1" ]]; then
		warn "AHR_ALLOW_NON_VM_TESTING=1 is set; forcing host policy to 'any'"
		effective_host_policy="any"
	fi

	case "$effective_host_policy" in
		any)
			warn "Host checks are bypassed (host policy: any)"
			;;
		artix)
			if [[ ! -f /etc/artix-release ]]; then
				error "Host policy requires Artix (/etc/artix-release missing)."
			fi
			;;
		vm)
			if [[ ! -f /etc/artix-release ]]; then
				error "Host policy 'vm' requires Artix (/etc/artix-release missing)."
			fi

			hardware_probe
			if [[ "$HARDWARE_IS_VIRTUALIZED" != "true" ]]; then
				error "Host policy 'vm' requires virtualization."
			fi
			;;
		*)
			error "Unknown effective host policy: $effective_host_policy"
			;;
	esac

	require_command pacman
	require_command rc-update
	require_command rc-service
	require_command id
	require_command getent

	info "Preflight checks passed"
}

run_package_phase() {
	local -a packages=()
	local -a hardware_packages=()
	mapfile -t packages < <(collect_packages)
	collect_hardware_recommended_packages hardware_packages

	if [[ "${#hardware_packages[@]}" -gt 0 ]]; then
		packages+=("${hardware_packages[@]}")
		mapfile -t packages < <(printf '%s\n' "${packages[@]}" | awk '!seen[$0]++')
	fi

	info "[Phase 2/7] Installing packages"

	if [[ "${#packages[@]}" -eq 0 ]]; then
		warn "No packages found under $PACKAGES_DIR"
		return 0
	fi

	validate_package_availability "phase 2 package set" "${packages[@]}"

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
	install_aur_packages "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN" "${packages[@]}"
}

run_flatpak_phase() {
	local profile_root="$SCRIPT_DIR/flatpaks"

	if [[ "$SKIP_FLATPAK" == true || "$FLATPAK_PROFILE" == "none" ]]; then
		info "[Phase 6/7] Skipping Flatpak profile install"
		return 0
	fi

	info "[Phase 6/7] Installing Flatpak profile '$FLATPAK_PROFILE'"
	install_flatpak_profile "$profile_root" "$FLATPAK_PROFILE" "$DRY_RUN"
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

detect_tuigreet_package() {
	local candidate

	if command -v tuigreet >/dev/null 2>&1; then
		printf '%s\n' ""
		return 0
	fi

	for candidate in greetd-tuigreet tuigreet; do
		if pacman -Si "$candidate" >/dev/null 2>&1; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

ensure_startup_mode_packages() {
	local -a startup_packages=()
	local tuigreet_pkg

	if [[ "$STARTUP_MODE" != "greetd" ]]; then
		return 0
	fi

	startup_packages+=(greetd greetd-openrc)

	if tuigreet_pkg="$(detect_tuigreet_package)"; then
		if [[ -n "$tuigreet_pkg" ]]; then
			startup_packages+=("$tuigreet_pkg")
		fi
	else
		warn "Could not resolve tuigreet package name from repositories (tried: greetd-tuigreet, tuigreet)."
	fi

	if [[ "$DRY_RUN" == true ]]; then
		info "Dry-run: would ensure startup packages for greetd mode"
		printf '  - %s\n' "${startup_packages[@]}"
		return 0
	fi

	refresh_package_databases
	install_packages "${startup_packages[@]}"
}

run_startup_phase() {
	info "[Phase 5/7] Configuring startup mode '$STARTUP_MODE' for Hyprland"
	resolve_target_user
	ensure_startup_mode_packages
	startup_mode_preflight "$STARTUP_MODE" "$TARGET_HOME" "$DRY_RUN"
	configure_startup_mode "$STARTUP_MODE" "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN" "$GREETD_MODE"
}

run_post_install_phase() {
	info "[Phase 7/7] Preparing first-run + post-install framework"
	resolve_target_user
	prepare_post_install_framework "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
	finish_post_install "$TARGET_USER" "$DRY_RUN" "$ASSUME_YES"
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
		--skip-flatpak)
			SKIP_FLATPAK=true
			;;
		--user)
			shift
			[[ "$#" -gt 0 ]] || error "--user requires a username"
			TARGET_USER="$1"
			;;
		--startup-mode)
			shift
			[[ "$#" -gt 0 ]] || error "--startup-mode requires a value (tty|greetd)"
			validate_startup_mode "$1"
			STARTUP_MODE="$1"
			;;
		--greetd-mode)
			shift
			[[ "$#" -gt 0 ]] || error "--greetd-mode requires a value (autologin|greeter)"
			validate_greetd_mode "$1"
			GREETD_MODE="$1"
			;;
		--hardware-mode)
			shift
			[[ "$#" -gt 0 ]] || error "--hardware-mode requires a value (recommend|auto|off)"
			validate_hardware_mode "$1"
			HARDWARE_MODE="$1"
			;;
		--flatpak-profile)
			shift
			[[ "$#" -gt 0 ]] || error "--flatpak-profile requires a value (default|optional|all|none)"
			validate_flatpak_profile "$1"
			FLATPAK_PROFILE="$1"
			;;
		--host-policy)
			shift
			[[ "$#" -gt 0 ]] || error "--host-policy requires a value (artix|vm|any)"
			validate_host_policy "$1"
			HOST_POLICY="$1"
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

setup_install_logging
trap 'status=$?; printf "[%s] Installer exit status: %s\n" "$(date "+%Y-%m-%d %H:%M:%S")" "$status" >> "$ACTIVE_INSTALL_LOG_FILE"' EXIT

if [[ "$STARTUP_MODE" != "greetd" && "$GREETD_MODE" != "greeter" ]]; then
	warn "Ignoring --greetd-mode '$GREETD_MODE' because startup mode is '$STARTUP_MODE'"
fi

if [[ "$HOST_POLICY" != "artix" ]]; then
	info "Host policy override: $HOST_POLICY"
fi

if [[ "$ASSUME_YES" == false ]]; then
	info "Installer will run up to phase $TARGET_PHASE"
	if (( TARGET_PHASE >= 4 )); then
		info "Target desktop user for phases 4-7: ${TARGET_USER:-<unset>}"
	fi
	if (( TARGET_PHASE >= 6 )) && [[ "$SKIP_AUR" == true ]]; then
		info "AUR phase will be skipped (--skip-aur)"
	fi
	if (( TARGET_PHASE >= 6 )); then
		if [[ "$SKIP_FLATPAK" == true ]]; then
			info "Flatpak install will be skipped (--skip-flatpak)"
		else
			info "Flatpak profile mode for phase 6: $FLATPAK_PROFILE"
		fi
	fi
	if (( TARGET_PHASE >= 5 )); then
		info "Startup mode for phase 5: $STARTUP_MODE"
		if [[ "$STARTUP_MODE" == "greetd" ]]; then
			info "greetd session policy: $GREETD_MODE"
		fi
	fi
	if (( TARGET_PHASE >= 2 )); then
		info "Hardware package mode for phase 2: $HARDWARE_MODE"
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
	run_startup_phase
fi
if (( TARGET_PHASE >= 6 )); then
	run_aur_phase
	run_flatpak_phase
fi
if (( TARGET_PHASE >= 7 )); then
	run_post_install_phase
fi

info "Completed requested phases (1..$TARGET_PHASE)"
info "Installer phase run finished"
