#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

command_exists() { command -v "$1" >/dev/null 2>&1; }

require_command() {
	local cmd="$1"
	if command_exists "$cmd"; then
		return 0
	fi

	case "$cmd" in
		pacman)
			remediate "Required command '$cmd' not found" \
				"Run this phase on an Artix base system with pacman available."
			;;
		rc-update|rc-service)
			remediate "Required command '$cmd' not found" \
				"Run this phase on Artix OpenRC with the OpenRC service tools installed."
			;;
		id)
			remediate "Required command '$cmd' not found" \
				"Install or repair coreutils, then re-run the installer."
			;;
		getent)
			remediate "Required command '$cmd' not found" \
				"Install or repair the package that provides getent, then re-run the installer."
			;;
		bash)
			remediate "Required command '$cmd' not found" \
				"Install bash, then re-run the installer."
			;;
		*)
			remediate "Required command '$cmd' not found" \
				"Install the package that provides '$cmd', then re-run the installer."
			;;
	esac
}
