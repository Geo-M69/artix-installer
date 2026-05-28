#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || true

link_dotfile() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  ln -sf "$src" "$dest"
  info "Linked $src -> $dest"
}
