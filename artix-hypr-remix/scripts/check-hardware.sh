#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/hardware.sh"

HOST_POLICY="${AHR_HOST_POLICY:-artix}"

require_supported_host() {
	local effective_host_policy="$HOST_POLICY"

	if [[ "${AHR_ALLOW_NON_VM_TESTING:-0}" == "1" ]]; then
		warn "AHR_ALLOW_NON_VM_TESTING=1 is set; forcing host policy to any"
		effective_host_policy="any"
	fi

	case "$effective_host_policy" in
		any)
			warn "Host checks bypassed (host policy: any)"
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
				error "Host policy 'vm' requires virtualization for hardware validation."
			fi
			;;
		*)
			error "Invalid AHR_HOST_POLICY '$effective_host_policy' (use artix, vm, or any)."
			;;
	esac
}

output_path="${1:-$(hardware_default_profile_path)}"

require_supported_host

hardware_write_profile_json "$output_path"

info "Hardware profile written to $output_path"
info "Detection summary: $(hardware_summary_line)"
cat "$output_path"
