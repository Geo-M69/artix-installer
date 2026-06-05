#!/usr/bin/env bash
set -euo pipefail

info() { printf "\e[32m[INFO]\e[0m %s\n" "$*"; }
warn() { printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
error() { printf "\e[31m[ERROR]\e[0m %s\n" "$*"; exit 1; }

# Print an error with a remediation suggestion and exit.
remediate() {
	local err_msg="$1"
	local remedy_msg="$2"
	printf "\e[31m[ERROR]\e[0m %s\n" "$err_msg" >&2
	printf "\e[36m[REMEDY]\e[0m %s\n" "$remedy_msg" >&2
	exit 1
}
