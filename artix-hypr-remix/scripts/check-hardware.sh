#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/hardware.sh"

require_vm_only_host() {
	if [[ "${AHR_ALLOW_NON_VM_TESTING:-0}" == "1" ]]; then
		warn "VM-only checks bypassed (AHR_ALLOW_NON_VM_TESTING=1)"
		return 0
	fi

	if [[ ! -f /etc/artix-release ]]; then
		error "VM-only policy: Artix host required (/etc/artix-release missing)."
	fi

	hardware_probe
	if [[ "$HARDWARE_IS_VIRTUALIZED" != "true" ]]; then
		error "VM-only policy: virtualization is required for hardware validation."
	fi
}

output_path="${1:-$(hardware_default_profile_path)}"

require_vm_only_host

hardware_write_profile_json "$output_path"

info "Hardware profile written to $output_path"
info "Detection summary: $(hardware_summary_line)"
cat "$output_path"
