#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

command_exists() { command -v "$1" >/dev/null 2>&1; }
require_command() { command_exists "$1" || error "Required command '$1' not found"; }
