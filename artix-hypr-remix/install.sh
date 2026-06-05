#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
SERVICES_DIR="$SCRIPT_DIR/services"
CONFIG_DIR="$SCRIPT_DIR/config"
LIB_DIR="$SCRIPT_DIR/lib"
DOCKER_PROFILE_PACKAGES_FILE="$SCRIPT_DIR/profiles/docker/packages.txt"
PRINTING_PROFILE_PACKAGES_FILE="$PACKAGES_DIR/profile-printing.txt"
PRINTING_PROFILE_SERVICES_FILE="$SERVICES_DIR/openrc-printing.txt"

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
source "$LIB_DIR/dev_baseline.sh"
source "$LIB_DIR/state.sh"

TARGET_PHASE=7
FROM_PHASE=1
FROM_PHASE_EXPLICIT=false
ASSUME_YES=false
DRY_RUN=false
BACKUP_ONLY=false
SKIP_AUR=false
SKIP_FLATPAK=false
STARTUP_MODE="tty"
GREETD_MODE="greeter"
HARDWARE_MODE="recommend"
DOCKER_PROFILE="off"
PRINTING_PROFILE="off"
FLATPAK_PROFILE="default"
DEV_BASELINE_MODE="off"
TARGET_USER="${SUDO_USER:-}"
TARGET_HOME=""
HOST_POLICY="${AHR_HOST_POLICY:-artix}"
INSTALL_LOG_FILE="${AHR_INSTALL_LOG_FILE:-/var/log/artix-hypr-remix-install.log}"
INSTALL_STATE_DIR="${AHR_INSTALL_STATE_DIR:-/var/lib/artix-hypr-remix/install-state}"
ACTIVE_INSTALL_LOG_FILE=""
AHR_CREATED_BACKUPS=()

install_error_trap() {
	local line_no="${1:-unknown}"
	local command_text="${2:-<unknown>}"
	local exit_status="$?"

	if [[ -n "$ACTIVE_INSTALL_LOG_FILE" ]]; then
		printf '[%s] Installer error at line %s (exit %s): %s\n' \
			"$(date '+%Y-%m-%d %H:%M:%S')" "$line_no" "$exit_status" "$command_text" >> "$ACTIVE_INSTALL_LOG_FILE"
	fi

	warn "Installer failed at line $line_no (exit $exit_status). Review $ACTIVE_INSTALL_LOG_FILE for details."
}

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
	8. Optional Git/GPG/SSH baseline defaults for target user

Options:
	--phase N     Run phases up to N (1-8). Default: 7
	--from-phase N Start from phase N (1-8). Default: 1
	--user NAME   Target non-root desktop user for phases 4-8
	--startup-mode MODE  Startup mode for phase 5: tty (default) or greetd
	--greetd-mode MODE   greetd session policy: autologin or greeter (default)
	--hardware-mode MODE Hardware package mode for phase 2: recommend (default), auto, or off
	--docker-profile MODE Optional docker profile for phase 2/3: off (default) or on
	--printing-profile MODE Optional printing profile for phase 2/3: off (default) or on
	--flatpak-profile MODE Flatpak app profile for phase 6: default (default), optional, all, or none
	--dev-baseline MODE Optional phase 8 baseline: off (default) or on
	--host-policy MODE Host policy for preflight: artix (default), vm, or any
	--skip-aur    Skip phase 6 AUR install even when phase includes it
	--skip-flatpak Skip Flatpak profile install in phase 6
	--dry-run     Print planned actions without changing the system
	--backup-only Run only Phase 4 backups, then exit (no config replacement)
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

validate_docker_profile() {
	local mode="$1"

	case "$mode" in
		off|on) return 0 ;;
		*) error "Invalid docker profile '$mode'. Use off or on." ;;
	esac
}

validate_printing_profile() {
	local mode="$1"

	case "$mode" in
		off|on) return 0 ;;
		*) error "Invalid printing profile '$mode'. Use off or on." ;;
	esac
}

validate_host_policy() {
	local mode="$1"

	case "$mode" in
		artix|vm|any) return 0 ;;
		*) error "Invalid host policy '$mode'. Use artix, vm, or any." ;;
	esac
}

validate_dev_baseline_mode() {
	local mode="$1"

	case "$mode" in
		off|on) return 0 ;;
		*) error "Invalid dev baseline mode '$mode'. Use off or on." ;;
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

collect_core_aur_package_files() {
	find "$PACKAGES_DIR" -maxdepth 1 -type f -name '90-*.txt' | sort
}

collect_optional_aur_package_files() {
	find "$PACKAGES_DIR" -maxdepth 1 -type f -name '9[1-9]-*.txt' | sort
}

phase_window_overlaps() {
	local start_phase="$1"
	local end_phase="$2"

	! (( TARGET_PHASE < start_phase || FROM_PHASE > end_phase ))
}

collect_docker_profile_packages() {
	if [[ "$DOCKER_PROFILE" != "on" ]]; then
		return 0
	fi

	if [[ ! -f "$DOCKER_PROFILE_PACKAGES_FILE" ]]; then
		return 0
	fi

	parse_list_file "$DOCKER_PROFILE_PACKAGES_FILE"
}

collect_printing_profile_packages() {
	if [[ "$PRINTING_PROFILE" != "on" ]]; then
		return 0
	fi

	if [[ ! -f "$PRINTING_PROFILE_PACKAGES_FILE" ]]; then
		return 0
	fi

	parse_list_file "$PRINTING_PROFILE_PACKAGES_FILE"
}

collect_printing_profile_services() {
	if [[ "$PRINTING_PROFILE" != "on" ]]; then
		return 0
	fi

	if [[ ! -f "$PRINTING_PROFILE_SERVICES_FILE" ]]; then
		return 0
	fi

	parse_list_file "$PRINTING_PROFILE_SERVICES_FILE"
}

collect_packages() {
	local file pkg
	while IFS= read -r file; do
		while IFS= read -r pkg; do
			[[ -n "$pkg" ]] && printf '%s\n' "$pkg"
		done < <(parse_list_file "$file")
	done < <(collect_package_files) | awk '!seen[$0]++'
}

collect_core_aur_packages() {
	local file pkg
	while IFS= read -r file; do
		while IFS= read -r pkg; do
			[[ -z "$pkg" ]] && continue
			[[ "$pkg" == "paru" ]] && continue
			printf '%s\n' "$pkg"
		done < <(parse_list_file "$file")
	done < <(collect_core_aur_package_files) | awk '!seen[$0]++'
}

collect_optional_aur_packages() {
	local file pkg
	while IFS= read -r file; do
		while IFS= read -r pkg; do
			[[ -z "$pkg" ]] && continue
			[[ "$pkg" == "paru" ]] && continue
			printf '%s\n' "$pkg"
		done < <(parse_list_file "$file")
	done < <(collect_optional_aur_package_files) | awk '!seen[$0]++'
}

collect_services() {
	parse_list_file "$SERVICES_DIR/openrc-default.txt"
}

is_required_openrc_service() {
	local service="$1"

	case "$service" in
		dbus|elogind|NetworkManager)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

required_openrc_services() {
	printf '%s\n' "dbus" "elogind" "NetworkManager"
}

required_printing_profile_packages() {
	printf '%s\n' "cups" "avahi" "cups-openrc" "avahi-openrc"
}

required_printing_services() {
	printf '%s\n' "cupsd" "avahi-daemon"
}

validate_required_printing_profile_packages_declared() {
	local -a packages=("$@")
	local required_package pkg found

	while IFS= read -r required_package; do
		[[ -z "$required_package" ]] && continue
		found="false"

		for pkg in "${packages[@]}"; do
			if [[ "$pkg" == "$required_package" ]]; then
				found="true"
				break
			fi
		done

		if [[ "$found" != "true" ]]; then
			error "Required printing package '$required_package' is missing from $PRINTING_PROFILE_PACKAGES_FILE"
		fi
	done < <(required_printing_profile_packages)
}

validate_required_openrc_services_declared() {
	local -a services=("$@")
	local required_service service found

	while IFS= read -r required_service; do
		[[ -z "$required_service" ]] && continue
		found="false"

		for service in "${services[@]}"; do
			if [[ "$service" == "$required_service" ]]; then
				found="true"
				break
			fi
		done

		if [[ "$found" != "true" ]]; then
			error "Required OpenRC service '$required_service' is missing from $SERVICES_DIR/openrc-default.txt"
		fi
	done < <(required_openrc_services)
}

validate_required_printing_services_declared() {
	local -a services=("$@")
	local required_service service found

	while IFS= read -r required_service; do
		[[ -z "$required_service" ]] && continue
		found="false"

		for service in "${services[@]}"; do
			if [[ "$service" == "$required_service" ]]; then
				found="true"
				break
			fi
		done

		if [[ "$found" != "true" ]]; then
			error "Required printing OpenRC service '$required_service' is missing from $PRINTING_PROFILE_SERVICES_FILE"
		fi
	done < <(required_printing_services)
}

is_required_printing_service() {
	local service="$1"

	if [[ "$PRINTING_PROFILE" != "on" ]]; then
		return 1
	fi

	case "$service" in
		cupsd|avahi-daemon)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

is_required_service() {
	local service="$1"

	if is_required_openrc_service "$service"; then
		return 0
	fi

	is_required_printing_service "$service"
}

validate_openrc_service_init_scripts() {
	local -a services=("$@")
	local -a missing_required=()
	local -a missing_optional=()
	local service

	for service in "${services[@]}"; do
		if service_exists "$service"; then
			continue
		fi

		if is_required_service "$service"; then
			missing_required+=("$service")
			continue
		fi

		missing_optional+=("$service")
	done

	if [[ "${#missing_optional[@]}" -gt 0 ]]; then
		warn "OpenRC manifest contains optional services without init scripts under /etc/init.d (they will be skipped):"
		printf '  - %s\n' "${missing_optional[@]}" >&2
	fi

	if [[ "${#missing_required[@]}" -gt 0 ]]; then
		warn "Required OpenRC services are missing init scripts under /etc/init.d:"
		printf '  - %s\n' "${missing_required[@]}" >&2
		error "OpenRC required-service manifest validation failed. Verify service names in $SERVICES_DIR/openrc-default.txt and installed packages."
	fi
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

	if [[ "$HARDWARE_MODE" == "off" ]]; then
		info "Hardware profile package recommendations are disabled (--hardware-mode off)"
		return 0
	fi

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
	info "[Phase 1/8] Running preflight checks"
	local allow_non_vm="${AHR_ALLOW_NON_VM_TESTING:-0}"
	local effective_host_policy="$HOST_POLICY"

	if [[ "$EUID" -ne 0 ]]; then
		if [[ "$DRY_RUN" == true ]]; then
			warn "Dry-run without root: system-changing steps are not executed"
		else
			remediate "Please run as root (or with sudo)." \
				"Re-run with: sudo ./install.sh [options]"$'\n'"For phases 4-8, pass --user <username> if sudo cannot infer the desktop user."
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
				remediate "Host policy requires Artix (/etc/artix-release missing)." \
					"This installer targets Artix Linux with OpenRC."$'\n'"If this is a maintenance/test run, use --host-policy any only when you understand the risk."
			fi
			;;
		vm)
			if [[ ! -f /etc/artix-release ]]; then
				remediate "Host policy 'vm' requires Artix (/etc/artix-release missing)." \
					"Use --host-policy vm only on an Artix VM. For maintenance/testing outside Artix, use --host-policy any."
			fi

			hardware_probe
			if [[ "$HARDWARE_IS_VIRTUALIZED" != "true" ]]; then
				remediate "Host policy 'vm' requires virtualization." \
					"Use --host-policy artix for real hardware, or --host-policy any for maintenance/testing bypasses."
			fi
			;;
		*)
			remediate "Unknown effective host policy: $effective_host_policy" \
				"Valid host policies are: artix, vm, and any. Check --host-policy or AHR_HOST_POLICY."
			;;
	esac

	if phase_window_overlaps 2 2 || phase_window_overlaps 6 6 || { [[ "$STARTUP_MODE" == "greetd" ]] && phase_window_overlaps 5 5; }; then
		require_command pacman
	fi
	if phase_window_overlaps 3 3 || { [[ "$STARTUP_MODE" == "greetd" ]] && phase_window_overlaps 5 5; }; then
		require_command rc-update
		require_command rc-service
	fi
	require_command id
	require_command getent
	require_command bash

	if phase_window_overlaps 2 2; then
		[[ -d "$PACKAGES_DIR" ]] || remediate "Packages directory is missing: $PACKAGES_DIR" \
			"Run the installer from a complete artix-hypr-remix checkout. Expected: packages/ next to install.sh."
	fi

	if phase_window_overlaps 3 3; then
		[[ -f "$SERVICES_DIR/openrc-default.txt" ]] || remediate "Required OpenRC service manifest is missing: $SERVICES_DIR/openrc-default.txt" \
			"Restore services/openrc-default.txt or re-clone the repository."
	fi

	if phase_window_overlaps 4 8; then
		[[ -d "$CONFIG_DIR" ]] || remediate "Config source directory is missing: $CONFIG_DIR" \
			"Restore config/ or re-clone the repository."
		resolve_target_user

		if [[ "$TARGET_HOME" == "/" ]]; then
			remediate "Refusing to target home directory '/'. Re-run with a real desktop user via --user <name>." \
				"Specify a non-root desktop user: sudo ./install.sh --user <username>"
		fi

		if [[ ! -d "$TARGET_HOME" ]]; then
			remediate "Resolved target home is not a directory: $TARGET_HOME" \
				"Create or fix the desktop user home, then re-run with: sudo ./install.sh --user <username>"
		fi
	fi

	if phase_window_overlaps 5 8; then
		[[ -f "$CONFIG_DIR/artix-hypr-remix/bin/start-hyprland-session.sh" ]] || remediate "Shared Hyprland session launcher source is missing from repo config/" \
			"Restore config/artix-hypr-remix/bin/start-hyprland-session.sh or re-clone the repository."
	fi

	if phase_window_overlaps 7 8; then
		[[ -f "$SCRIPT_DIR/scripts/post-install-smoke.sh" ]] || remediate "Post-install validation script is missing: $SCRIPT_DIR/scripts/post-install-smoke.sh" \
			"Restore scripts/post-install-smoke.sh or re-clone the repository."
		[[ -f "$CONFIG_DIR/artix-hypr-remix/bin/first-run.sh" ]] || remediate "First-run framework source is missing from repo config/" \
			"Restore config/artix-hypr-remix/bin/first-run.sh or re-clone the repository."
	fi

	info "Preflight checks passed"
}

run_package_phase() {
	local -a packages=()
	local -a hardware_packages=()
	local -a docker_profile_packages=()
	local -a printing_profile_packages=()
	local -a matched_profiles=()
	local profile_root
	mapfile -t packages < <(collect_packages)
	collect_hardware_recommended_packages hardware_packages
	mapfile -t docker_profile_packages < <(collect_docker_profile_packages)
	mapfile -t printing_profile_packages < <(collect_printing_profile_packages)
	mapfile -t matched_profiles < <(hardware_detect_profiles)
	profile_root="$CONFIG_DIR/hardware"

	if [[ "${#hardware_packages[@]}" -gt 0 ]]; then
		packages+=("${hardware_packages[@]}")
	fi

	if [[ "${#docker_profile_packages[@]}" -gt 0 ]]; then
		info "Docker profile enabled: adding ${#docker_profile_packages[@]} package(s)"
		packages+=("${docker_profile_packages[@]}")
	fi

	if [[ "${#printing_profile_packages[@]}" -gt 0 ]]; then
		info "Printing profile enabled: adding ${#printing_profile_packages[@]} package(s)"
		packages+=("${printing_profile_packages[@]}")
	fi

	mapfile -t packages < <(printf '%s\n' "${packages[@]}" | awk '!seen[$0]++')

	if [[ "$PRINTING_PROFILE" == "on" ]]; then
		validate_required_printing_profile_packages_declared "${printing_profile_packages[@]}"
	fi

	info "[Phase 2/8] Installing packages"

	if [[ "${#packages[@]}" -eq 0 ]]; then
		warn "No packages found under $PACKAGES_DIR"
		return 0
	fi

	validate_package_availability "phase 2 package set" "${packages[@]}"

	if [[ "$DRY_RUN" == true ]]; then
		info "Dry-run: would install ${#packages[@]} packages"
		printf '  - %s\n' "${packages[@]}"

		if [[ "$DOCKER_PROFILE" == "on" ]]; then
			if [[ "${#docker_profile_packages[@]}" -eq 0 ]]; then
				warn "Docker profile is enabled but no packages were found in $DOCKER_PROFILE_PACKAGES_FILE"
			fi
		else
			info "Docker profile is disabled (--docker-profile off)"
		fi

		if [[ "$PRINTING_PROFILE" == "on" ]]; then
			if [[ "${#printing_profile_packages[@]}" -eq 0 ]]; then
				warn "Printing profile is enabled but no packages were found in $PRINTING_PROFILE_PACKAGES_FILE"
			fi
		else
			info "Printing profile is disabled (--printing-profile off)"
		fi

		if [[ "$HARDWARE_MODE" == "off" ]]; then
			info "Hardware OpenRC modules are disabled (--hardware-mode off)"
		elif [[ "${#matched_profiles[@]}" -gt 0 ]]; then
			hardware_apply_profile_modules "$profile_root" "$DRY_RUN" "${matched_profiles[@]}"
		else
			info "No detected hardware profiles to apply OpenRC modules"
		fi
		return 0
	fi

	refresh_package_databases
	install_packages "${packages[@]}"

	if [[ "$HARDWARE_MODE" == "off" ]]; then
		info "Hardware OpenRC modules are disabled (--hardware-mode off)"
	else
		if [[ "${#matched_profiles[@]}" -eq 0 ]]; then
			info "No detected hardware profiles to apply OpenRC modules"
		else
			hardware_apply_profile_modules "$profile_root" "$DRY_RUN" "${matched_profiles[@]}"
		fi
	fi

	if [[ "$DOCKER_PROFILE" == "on" ]]; then
		if [[ "${#docker_profile_packages[@]}" -eq 0 ]]; then
			warn "Docker profile is enabled but no packages were found in $DOCKER_PROFILE_PACKAGES_FILE"
		else
			info "Docker profile package set applied"
		fi
	else
		info "Docker profile is disabled (--docker-profile off)"
	fi

	if [[ "$PRINTING_PROFILE" == "on" ]]; then
		if [[ "${#printing_profile_packages[@]}" -eq 0 ]]; then
			warn "Printing profile is enabled but no packages were found in $PRINTING_PROFILE_PACKAGES_FILE"
		else
			info "Printing profile package set applied"
		fi
	else
		info "Printing profile is disabled (--printing-profile off)"
	fi
}

run_service_phase() {
	local -a services=()
	local -a printing_profile_services=()
	local service

	mapfile -t services < <(collect_services)

	if [[ "$DOCKER_PROFILE" == "on" ]]; then
		services+=("docker")
	fi

	if [[ "$PRINTING_PROFILE" == "on" ]]; then
		mapfile -t printing_profile_services < <(collect_printing_profile_services)
		if [[ "${#printing_profile_services[@]}" -gt 0 ]]; then
			info "Printing profile enabled: adding ${#printing_profile_services[@]} OpenRC service(s)"
			services+=("${printing_profile_services[@]}")
		fi
	fi

	mapfile -t services < <(printf '%s\n' "${services[@]}" | awk '!seen[$0]++')

	info "[Phase 3/8] Enabling safe OpenRC services"

	if [[ "${#services[@]}" -eq 0 ]]; then
		warn "No services found in $SERVICES_DIR/openrc-default.txt"
		return 0
	fi

	validate_required_openrc_services_declared "${services[@]}"

	if [[ "$PRINTING_PROFILE" == "on" ]]; then
		validate_required_printing_services_declared "${services[@]}"
	fi

	if [[ "$DRY_RUN" == true ]]; then
		info "Dry-run: would enable/start ${#services[@]} services"
		for service in "${services[@]}"; do
			if is_required_service "$service"; then
				printf '  - %s (required)\n' "$service"
			else
				printf '  - %s\n' "$service"
			fi
		done
		return 0
	fi

	validate_openrc_service_init_scripts "${services[@]}"

	for service in "${services[@]}"; do
		if ! service_exists "$service"; then
			# Optional missing services were already reported by manifest validation.
			continue
		fi

		if is_required_service "$service"; then
			enable_service_required "$service" "default" "true"
			continue
		fi

		enable_service_optional "$service" "default" "true"
	done
}

run_aur_phase() {
	local -a core_packages=()
	local -a optional_packages=()

	if [[ "$SKIP_AUR" == true ]]; then
		info "[Phase 6/8] Skipping AUR phase due to --skip-aur"
		return 0
	fi

	mapfile -t core_packages < <(collect_core_aur_packages)
	mapfile -t optional_packages < <(collect_optional_aur_packages)

	info "[Phase 6/8] Installing AUR packages"

	if [[ "${#core_packages[@]}" -eq 0 && "${#optional_packages[@]}" -eq 0 ]]; then
		warn "No AUR packages found under $PACKAGES_DIR/9[0-9]-*.txt"
		return 0
	fi

	resolve_target_user
	ensure_paru_bootstrap "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"

	if [[ "${#core_packages[@]}" -gt 0 ]]; then
		if ! install_aur_packages "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN" "${core_packages[@]}"; then
			error "Core AUR package installation failed. Resolve the failing package(s) and re-run --phase 6."
		fi
	else
		info "No core AUR packages defined under $PACKAGES_DIR/90-*.txt"
	fi

	if [[ "${#optional_packages[@]}" -gt 0 ]]; then
		install_aur_packages_optional "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN" "${optional_packages[@]}"
	else
		info "No optional AUR packages defined under $PACKAGES_DIR/9[1-9]-*.txt"
	fi
}

run_flatpak_phase() {
	local profile_root="$SCRIPT_DIR/flatpaks"

	if [[ "$SKIP_FLATPAK" == true || "$FLATPAK_PROFILE" == "none" ]]; then
		info "[Phase 6/8] Skipping Flatpak profile install"
		return 0
	fi

	info "[Phase 6/8] Installing Flatpak profile '$FLATPAK_PROFILE'"
	install_flatpak_profile "$profile_root" "$FLATPAK_PROFILE" "$DRY_RUN"
}

resolve_target_user() {
	local current_user

	if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
		if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
			TARGET_USER="$SUDO_USER"
		fi
	fi

	if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
		current_user="$(id -un)"
		if [[ "$current_user" != "root" ]]; then
			TARGET_USER="$current_user"
		fi
	fi

	if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
		error "Phases 4-8 require a non-root desktop user. Re-run with --user <name>."
	fi

	if ! id "$TARGET_USER" >/dev/null 2>&1; then
		error "Target user '$TARGET_USER' does not exist"
	fi

	TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
	if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
		error "Could not resolve home directory for user '$TARGET_USER'"
	fi
}

confirm_dotfile_overwrite_window() {
	local -a existing_paths=()
	local response

	mapfile -t existing_paths < <(collect_existing_config_destinations "$CONFIG_DIR" "$TARGET_HOME")

	if [[ "${#existing_paths[@]}" -eq 0 ]]; then
		return 0
	fi

	warn "Phase 4 will back up and replace ${#existing_paths[@]} existing config path(s) under $TARGET_HOME/.config:"
	printf '  - %s\n' "${existing_paths[@]}"

	if [[ "$DRY_RUN" == "true" ]]; then
		info "Dry-run: overwrite confirmation skipped because no files will be changed"
		return 0
	fi

	if [[ "$ASSUME_YES" == "true" ]]; then
		info "Proceeding with backup-and-replace behavior because --yes was provided"
		return 0
	fi

	if [[ ! -t 0 ]]; then
		error "Phase 4 requires confirmation before replacing existing user config. Re-run interactively or pass --yes to accept backup-and-replace behavior."
	fi

	read -r -p "Back up and replace these existing config paths? [y/N]: " response
	case "${response,,}" in
		y|yes) ;;
		*) error "Phase 4 aborted before modifying existing user config." ;;
	esac
}

run_dotfiles_phase() {
	info "[Phase 4/8] Deploying dotfiles to target user"
	resolve_target_user
	confirm_dotfile_overwrite_window
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
	info "[Phase 5/8] Configuring startup mode '$STARTUP_MODE' for Hyprland"
	resolve_target_user
	ensure_startup_mode_packages
	startup_mode_preflight "$STARTUP_MODE" "$TARGET_HOME" "$DRY_RUN"
	configure_startup_mode "$STARTUP_MODE" "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN" "$GREETD_MODE"
}

run_post_install_validation() {
	if [[ "$DRY_RUN" == "true" ]]; then
		info "Dry-run: would run post-install validation for '$TARGET_USER'"
		return 0
	fi

	info "Running post-install validation checks"
	if ! bash "$SCRIPT_DIR/scripts/post-install-smoke.sh" --user "$TARGET_USER"; then
		error "Post-install validation failed. Review the reported checks above, fix the issue, then re-run the required phases."
	fi
}

run_post_install_phase() {
	info "[Phase 7/8] Preparing first-run + post-install framework"
	resolve_target_user
	prepare_post_install_framework "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
	run_post_install_validation
	finish_post_install "$TARGET_USER" "$DRY_RUN" "$ASSUME_YES"
}

run_dev_baseline_phase() {
	if [[ "$DEV_BASELINE_MODE" != "on" ]]; then
		info "[Phase 8/8] Skipping optional Git/GPG/SSH baseline (--dev-baseline off)"
		return 0
	fi

	info "[Phase 8/8] Applying optional Git/GPG/SSH baseline"
	resolve_target_user
	apply_dev_baseline "$TARGET_USER" "$TARGET_HOME" "$DRY_RUN"
}

run_backup_only() {
	info "=== Backup-only mode ==="
	info "Creating config backups without replacing existing files."
	resolve_target_user

	local -a existing_paths=()
	local destination
	mapfile -t existing_paths < <(collect_existing_config_destinations "$CONFIG_DIR" "$TARGET_HOME")

	if [[ "${#existing_paths[@]}" -eq 0 ]]; then
		info "No existing config paths found to back up. Nothing to do."
		return 0
	fi

	info "Backing up ${#existing_paths[@]} existing config path(s):"
	printf '  - %s\n' "${existing_paths[@]}"

	for destination in "${existing_paths[@]}"; do
		backup_path_if_exists "$destination" false
	done

	info ""
	if [[ "${#AHR_CREATED_BACKUPS[@]}" -gt 0 ]]; then
		info "Created backups:"
		printf '  - %s\n' "${AHR_CREATED_BACKUPS[@]}"
	fi
	info ""
	info "Your existing configs are preserved (nothing was replaced)."
	info "When ready, run the full installer with config deployment:"
	info "  sudo ./install.sh --phase 4 --user $TARGET_USER -y"
	info "=== Backup-only complete ==="
}

run_phase_by_number() {
	local phase="$1"

	state_mark_phase_started "$phase"

	case "$phase" in
		1)
			run_preflight
			;;
		2)
			run_package_phase
			;;
		3)
			run_service_phase
			;;
		4)
			run_dotfiles_phase
			;;
		5)
			run_startup_phase
			;;
		6)
			run_aur_phase
			run_flatpak_phase
			;;
		7)
			run_post_install_phase
			;;
		8)
			run_dev_baseline_phase
			;;
		*)
			error "Unsupported phase number: $phase"
			;;
	esac

	state_mark_phase_completed "$phase"
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--phase)
			shift
			[[ "$#" -gt 0 ]] || error "--phase requires a value (1-8)"
			[[ "$1" =~ ^[1-8]$ ]] || error "Invalid phase '$1'. Use 1, 2, 3, 4, 5, 6, 7, or 8."
			TARGET_PHASE="$1"
			;;
		--from-phase)
			shift
			[[ "$#" -gt 0 ]] || error "--from-phase requires a value (1-8)"
			[[ "$1" =~ ^[1-8]$ ]] || error "Invalid from-phase '$1'. Use 1, 2, 3, 4, 5, 6, 7, or 8."
			FROM_PHASE="$1"
			FROM_PHASE_EXPLICIT=true
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
		--docker-profile)
			shift
			[[ "$#" -gt 0 ]] || error "--docker-profile requires a value (off|on)"
			validate_docker_profile "$1"
			DOCKER_PROFILE="$1"
			;;
		--printing-profile)
			shift
			[[ "$#" -gt 0 ]] || error "--printing-profile requires a value (off|on)"
			validate_printing_profile "$1"
			PRINTING_PROFILE="$1"
			;;
		--flatpak-profile)
			shift
			[[ "$#" -gt 0 ]] || error "--flatpak-profile requires a value (default|optional|all|none)"
			validate_flatpak_profile "$1"
			FLATPAK_PROFILE="$1"
			;;
		--dev-baseline)
			shift
			[[ "$#" -gt 0 ]] || error "--dev-baseline requires a value (off|on)"
			validate_dev_baseline_mode "$1"
			DEV_BASELINE_MODE="$1"
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
		--backup-only)
			BACKUP_ONLY=true
			DRY_RUN=false
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

if (( FROM_PHASE > TARGET_PHASE )); then
	error "--from-phase ($FROM_PHASE) cannot be greater than --phase ($TARGET_PHASE)."
fi

setup_install_logging
trap 'install_error_trap "${LINENO}" "$BASH_COMMAND"' ERR
trap 'status=$?; printf "[%s] Installer exit status: %s\n" "$(date "+%Y-%m-%d %H:%M:%S")" "$status" >> "$ACTIVE_INSTALL_LOG_FILE"' EXIT
state_init "$INSTALL_STATE_DIR" "$DRY_RUN"

last_completed_phase="$(state_last_completed_phase 8)"
if [[ "$DRY_RUN" == "true" ]]; then
	info "Dry-run mode: installer state markers are read-only (source: $INSTALL_STATE_DIR)"
else
	info "Installer state directory: $INSTALL_STATE_DIR"
fi

if (( last_completed_phase > 0 )); then
	info "Last completed installer phase marker: $last_completed_phase"
	if [[ "$FROM_PHASE_EXPLICIT" == "false" ]] && (( TARGET_PHASE > last_completed_phase )); then
		info "Resume hint: use --from-phase $((last_completed_phase + 1)) to continue from prior progress"
	fi
fi

if [[ "$STARTUP_MODE" != "greetd" && "$GREETD_MODE" != "greeter" ]]; then
	warn "Ignoring --greetd-mode '$GREETD_MODE' because startup mode is '$STARTUP_MODE'"
fi

if [[ "$HOST_POLICY" != "artix" ]]; then
	info "Host policy override: $HOST_POLICY"
fi

if [[ "$BACKUP_ONLY" == true ]]; then
	FROM_PHASE=4
	TARGET_PHASE=4
	run_preflight
	run_backup_only
	exit 0
fi

if [[ "$ASSUME_YES" == false ]]; then
	info "Installer will run up to phase $TARGET_PHASE"
	if (( FROM_PHASE > 1 )); then
		info "Installer start phase: $FROM_PHASE"
	fi
	if (( TARGET_PHASE >= 4 && FROM_PHASE <= 8 )); then
		info "Target desktop user for phases 4-8: ${TARGET_USER:-<unset>}"
	fi
	if (( TARGET_PHASE >= 6 && FROM_PHASE <= 6 )) && [[ "$SKIP_AUR" == true ]]; then
		info "AUR phase will be skipped (--skip-aur)"
	fi
	if (( TARGET_PHASE >= 6 && FROM_PHASE <= 6 )); then
		if [[ "$SKIP_FLATPAK" == true ]]; then
			info "Flatpak install will be skipped (--skip-flatpak)"
		else
			info "Flatpak profile mode for phase 6: $FLATPAK_PROFILE"
		fi
	fi
	if (( TARGET_PHASE >= 5 && FROM_PHASE <= 5 )); then
		info "Startup mode for phase 5: $STARTUP_MODE"
		if [[ "$STARTUP_MODE" == "greetd" ]]; then
			info "greetd session policy: $GREETD_MODE"
		fi
	fi
	if (( TARGET_PHASE >= 2 && FROM_PHASE <= 2 )); then
		info "Hardware package mode for phase 2: $HARDWARE_MODE"
		info "Docker profile mode for phase 2/3: $DOCKER_PROFILE"
		info "Printing profile mode for phase 2/3: $PRINTING_PROFILE"
	fi
	if (( TARGET_PHASE >= 8 && FROM_PHASE <= 8 )); then
		info "Optional dev baseline mode for phase 8: $DEV_BASELINE_MODE"
	fi
	info "Execution phase window: $FROM_PHASE..$TARGET_PHASE"
	read -r -p "Continue? [y/N]: " response
	case "${response,,}" in
		y|yes) ;;
		*) info "Aborted by user"; exit 0 ;;
	esac
fi

for (( phase=FROM_PHASE; phase<=TARGET_PHASE; phase++ )); do
	run_phase_by_number "$phase"
done

print_install_summary() {
	local -a completed_phases=()
	local label phase

	for (( phase=FROM_PHASE; phase<=TARGET_PHASE; phase++ )); do
		if state_phase_completed "$phase"; then
			completed_phases+=("$phase")
		fi
	done

	local phase_labels=(
		[1]="Preflight checks"
		[2]="Package installation"
		[3]="OpenRC services"
		[4]="Config deployment"
		[5]="Startup mode"
		[6]="AUR + Flatpak"
		[7]="Post-install framework"
		[8]="Dev baseline"
	)

	info ""
	info "=============================================="
	info "         Installer Complete"
	info "=============================================="
	info ""

	if [[ "${#completed_phases[@]}" -gt 0 ]]; then
		info "Completed phases:"
		for phase in "${completed_phases[@]}"; do
			label="${phase_labels[$phase]:-Phase $phase}"
			info "  [$phase/8] $label"
		done
		info ""
	fi

	info "Log file:       $ACTIVE_INSTALL_LOG_FILE"
	info "State dir:      $INSTALL_STATE_DIR"
	info "Target user:    ${TARGET_USER:-<not set>}"
	if [[ -n "$TARGET_HOME" ]]; then
		info "Target home:    $TARGET_HOME"
	fi
	info "Startup mode:   $STARTUP_MODE"
	if [[ "$DOCKER_PROFILE" == "on" ]]; then
		info "Docker profile: enabled"
	fi
	if [[ "$PRINTING_PROFILE" == "on" ]]; then
		info "Printing:       enabled"
	fi
	info ""

	info "Next steps:"
	if (( TARGET_PHASE >= 4 && FROM_PHASE <= 4 )); then
		if [[ "${#AHR_CREATED_BACKUPS[@]}" -gt 0 ]]; then
			info "  - Config backups created:"
			printf '      %s\n' "${AHR_CREATED_BACKUPS[@]}"
		else
			info "  - Config backups: none created for this run"
		fi
	fi
	if state_phase_completed 4; then
		info "  - Re-apply config (replaces with fresh backup):"
		info "      sudo ./install.sh --phase 4 --user ${TARGET_USER:-<username>} -y"
	fi
	if state_phase_completed 6; then
		info "  - Re-run AUR/Flatpak phase:"
		info "      sudo ./install.sh --phase 6 --user ${TARGET_USER:-<username>}"
	fi
	if state_phase_completed 7; then
		info "  - Re-run post-install framework repair:"
		info "      sudo ./install.sh --phase 7 --user ${TARGET_USER:-<username>}"
		info "  - After login, run: ahr repair"
	fi
	if state_phase_completed 5; then
		if [[ "$STARTUP_MODE" != "greetd" ]]; then
			info "  - Log out and log back in (or reboot) to start your Hyprland session."
		else
			info "  - Reboot to start greetd and launch Hyprland."
		fi
	elif [[ "$BACKUP_ONLY" != "true" ]]; then
		info "  - Continue with remaining phases to complete setup."
	fi
	info ""
	info "  - Check health:   ahr doctor"
	info "  - Check updates:  ahr update-available"
	info "  - View help:      ahr help"
	info ""
	if [[ "$ACTIVE_INSTALL_LOG_FILE" == /tmp/* ]]; then
		warn "Log file is under /tmp (fallback path). Copy or preserve it if needed:"
		warn "  sudo cp $ACTIVE_INSTALL_LOG_FILE /var/log/"
	fi
	info "=============================================="
}

print_install_summary
