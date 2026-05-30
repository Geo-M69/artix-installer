#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/hardware.sh"

output_path="${1:-$(hardware_default_profile_path)}"

hardware_write_profile_json "$output_path"

info "Hardware profile written to $output_path"
info "Detection summary: $(hardware_summary_line)"
cat "$output_path"
