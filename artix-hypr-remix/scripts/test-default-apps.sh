#!/usr/bin/env bash
# Focused isolated tests for the Phase 2 default-application / MIME matrix.
#
# Covers: MIME/default matrix, default preservation (no handler, valid
# user-selected, unsupported handler, stale entry, missing entry, multiple
# candidates), desktop-entry discovery (user + Flatpak), idempotency
# (repeated setup), optional components (SwayOSD / OnlyOffice absence),
# package consistency (apps present in manifests), and diagnostics
# (validation does not mutate defaults).
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-default-apps-matrix.sh"
PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

[[ -f "$MATRIX" ]] || { echo "matrix library missing: $MATRIX" >&2; exit 1; }

# Build a scenario; prints the scenario root.
make_scenario() {
  local root
  root="$(mktemp -d /tmp/ahr-defapp-XXXXXXXX)"
  mkdir -p \
    "$root/home/.local/share/applications" \
    "$root/home/.local/share/flatpak/exports/share/applications" \
    "$root/usr/share/applications" \
    "$root/usr/local/share/applications" \
    "$root/var/lib/flatpak/exports/share/applications" \
    "$root/stub"
  : > "$root/mimeapps"
  : > "$root/mimeapps.mutations"
  cat > "$root/stub/xdg-mime" <<'STUB'
#!/usr/bin/env bash
STATE="${AHR_TEST_MIME_STATE:-}"
case "$1" in
  query)
    mime="$3"
    val="$(grep -s "^${mime}=" "$STATE" 2>/dev/null | head -1 | sed "s|^${mime}=||")"
    printf '%s\n' "${val:-}"
    ;;
  default)
    desktop="$2"; mime="$3"
    grep -v "^${mime}=" "$STATE" > "$STATE.tmp" 2>/dev/null || true
    mv "$STATE.tmp" "$STATE"
    printf '%s\n' "${mime}=${desktop}" >> "$STATE"
    printf 'default\n' >> "$STATE.mutations"
    ;;
  *) : ;;
esac
STUB
  chmod +x "$root/stub/xdg-mime"
  for c in xdg-settings xdg-open; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$root/stub/$c"
    chmod +x "$root/stub/$c"
  done
  printf '%s' "$root"
}

# Create a fake desktop entry in one of: user, user-flatpak, system, local, sys-flatpak
mk_entry() {
  local root="$1" where="$2" name="$3" target
  case "$where" in
    user) target="$root/home/.local/share/applications/$name" ;;
    user-flatpak) target="$root/home/.local/share/flatpak/exports/share/applications/$name" ;;
    system) target="$root/usr/share/applications/$name" ;;
    local) target="$root/usr/local/share/applications/$name" ;;
    sys-flatpak) target="$root/var/lib/flatpak/exports/share/applications/$name" ;;
  esac
  printf '[Desktop Entry]\nName=%s\n' "${name%.desktop}" > "$target"
}

# Run a block with the scenario environment.
enter_scenario() {
  local root="$1"
  export HOME="$root/home"
  export XDG_DATA_HOME="$root/home/.local/share"
  export AHR_TEST_MIME_STATE="$root/mimeapps"
  export PATH="$root/stub:$PATH"
  # shellcheck source=/dev/null
  source "$MATRIX"
}

count_mutations() { wc -l < "$1/mimeapps.mutations" | tr -d ' '; }

# ── 1. MIME / default matrix ───────────────────────────────────────────────
echo "MIME/default matrix coverage"
for mime in \
  x-scheme-handler/http x-scheme-handler/https text/html \
  inode/directory text/plain text/markdown text/x-markdown \
  application/pdf image/png image/jpeg image/gif image/webp image/bmp image/tiff \
  video/mp4 video/x-matroska video/webm video/x-msvideo video/ogg video/quicktime \
  audio/mpeg audio/flac audio/x-flac audio/x-wav audio/ogg audio/x-vorbis \
  application/zip application/x-tar application/x-bzip application/x-bzip2 \
  application/gzip application/x-7z-compressed application/x-rar-compressed; do
  if ( AHR_DUMMY=1; source "$MATRIX"; [[ -n "$(ahr_matrix_category_for_mime "$mime")" ]]; ); then
    pass "matrix maps $mime"
  else
    fail "matrix missing $mime"
  fi
done

# ── 2. Desktop-entry discovery ─────────────────────────────────────────────
echo "Desktop-entry discovery"
root="$(make_scenario)"
enter_scenario "$root"
mk_entry "$root" user imv.desktop
if ahr_matrix_desktop_entry_exists imv.desktop; then pass "discovers user application entry"; else fail "user entry not discovered"; fi
mk_entry "$root" user-flatpak org.gnome.Calculator.desktop
if ahr_matrix_desktop_entry_exists org.gnome.Calculator.desktop; then pass "discovers Flatpak user entry"; else fail "flatpak user entry not discovered"; fi
if ahr_matrix_desktop_entry_exists does-not-exist.desktop; then fail "false positive on missing entry"; else pass "rejects missing entry"; fi
if ahr_matrix_desktop_entry_exists "../../escape.desktop"; then fail "path traversal accepted"; else pass "rejects non-filename (traversal) input"; fi
if ahr_matrix_desktop_entry_exists "x.desktop"; then :; fi
rm -rf "$root"

# ── 3. Default preservation + setting (per category) ───────────────────────
echo "Default preservation and setting"

# 3a. no handler exists -> assign AHR default (evince for pdf)
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user org.gnome.Evince.desktop
if ahr_matrix_apply_category pdf; then pass "pdf: assigned AHR default when none existed"; else fail "pdf: failed to assign default"; fi
if [[ "$(grep '^application/pdf=' "$root/mimeapps")" == "application/pdf=org.gnome.Evince.desktop" ]]; then
  pass "pdf: mapped to org.gnome.Evince.desktop"
else
  fail "pdf: wrong mapping: $(grep '^application/pdf=' "$root/mimeapps" || echo none)"
fi
rm -rf "$root"

# 3b. valid user-selected handler exists -> preserved
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user myreader.desktop
printf 'application/pdf=myreader.desktop\n' >> "$root/mimeapps"
mk_entry "$root" user org.gnome.Evince.desktop
if ahr_matrix_apply_category pdf; then :; fi
if [[ "$(grep '^application/pdf=' "$root/mimeapps")" == "application/pdf=myreader.desktop" ]]; then
  pass "pdf: preserved user-selected handler"
else
  fail "pdf: overwrote user handler"
fi
rm -rf "$root"

# 3c. user-selected Flatpak handler preserved
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user-flatpak com.user.PdfViewer.desktop
printf 'application/pdf=com.user.PdfViewer.desktop\n' >> "$root/mimeapps"
if ahr_matrix_apply_category pdf; then :; fi
if [[ "$(grep '^application/pdf=' "$root/mimeapps")" == *com.user.PdfViewer.desktop* ]]; then
  pass "pdf: preserved user-selected Flatpak handler"
else
  fail "pdf: did not preserve Flatpak handler"
fi
rm -rf "$root"

# 3d. stale handler (points at missing entry) is detected; applying does not crash
root="$(make_scenario)"; enter_scenario "$root"
printf 'application/pdf=ghost.desktop\n' >> "$root/mimeapps"
if ahr_matrix_mime_handler_is_valid application/pdf; then
  fail "stale handler reported as valid"
else
  pass "stale handler detected as invalid"
fi
mk_entry "$root" user org.gnome.Evince.desktop
ahr_matrix_apply_category pdf >/dev/null 2>&1 || true
if [[ "$(grep '^application/pdf=' "$root/mimeapps")" == "application/pdf=org.gnome.Evince.desktop" ]]; then
  pass "stale handler repaired with AHR default"
else
  fail "stale handler not repaired"
fi
rm -rf "$root"

# 3e. missing entry name (empty) -> no handler, assigned
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user imv.desktop
ahr_matrix_apply_category image >/dev/null 2>&1 || true
if [[ -n "$(grep '^image/png=' "$root/mimeapps" || true)" ]]; then
  pass "image: assigned when no handler"
else
  fail "image: not assigned"
fi
rm -rf "$root"

# 3f. multiple candidates -> first available wins (nautilus before thunar)
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user thunar.desktop
mk_entry "$root" user nautilus.desktop
ahr_matrix_apply_category directory >/dev/null 2>&1 || true
if [[ "$(grep '^inode/directory=' "$root/mimeapps")" == "inode/directory=org.gnome.Nautilus.desktop" ]]; then
  pass "directory: first candidate (nautilus) wins over later (thunar)"
else
  fail "directory: wrong candidate: $(grep '^inode/directory=' "$root/mimeapps" || echo none)"
fi
rm -rf "$root"

# ── 4. Idempotency (repeated setup must not overwrite valid user choice) ────
echo "Idempotency"
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user myreader.desktop
printf 'application/pdf=myreader.desktop\n' >> "$root/mimeapps"
mk_entry "$root" user org.gnome.Evince.desktop
before=$(count_mutations "$root")
ahr_matrix_apply_category pdf >/dev/null 2>&1 || true
ahr_matrix_apply_category pdf >/dev/null 2>&1 || true
ahr_matrix_apply_category pdf >/dev/null 2>&1 || true
after=$(count_mutations "$root")
if [[ "$before" == "$after" ]]; then
  pass "pdf: repeated setup did not mutate an existing valid user choice"
else
  fail "pdf: repeated setup mutated state ($before -> $after)"
fi
rm -rf "$root"

# idempotency for a fresh assignment: second run adds no new default calls
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user org.gnome.Evince.desktop
ahr_matrix_apply_category pdf >/dev/null 2>&1 || true
before=$(count_mutations "$root")
ahr_matrix_apply_category pdf >/dev/null 2>&1 || true
after=$(count_mutations "$root")
if [[ "$before" == "$after" ]]; then
  pass "pdf: re-running after assignment adds no further xdg-mime writes"
else
  fail "pdf: re-run added writes ($before -> $after)"
fi
rm -rf "$root"

# ── 5. Optional components do not affect the matrix ────────────────────────
echo "Optional components"
root="$(make_scenario)"; enter_scenario "$root"
# SwayOSD / OnlyOffice absence must not block or alter default-app setup.
mk_entry "$root" user org.gnome.Evince.desktop
mk_entry "$root" user imv.desktop
mk_entry "$root" user mpv.desktop
mk_entry "$root" user org.gnome.FileRoller.desktop
for cat in pdf image video audio archive; do
  if ahr_matrix_apply_category "$cat" >/dev/null 2>&1; then
    pass "$cat: applied without SwayOSD/OnlyOffice present"
  else
    fail "$cat: failed without optional components"
  fi
done
rm -rf "$root"

# ── 6. Package consistency (matrix candidates exist in manifests) ──────────
echo "Package consistency"
declare -A CANDIDATE_PKG=(
  [org.gnome.Evince.desktop]=evince [evince.desktop]=evince
  [imv.desktop]=imv
  [mpv.desktop]=mpv
  [org.gnome.FileRoller.desktop]=file-roller [file-roller.desktop]=file-roller
  [org.gnome.Nautilus.desktop]=nautilus [nautilus.desktop]=nautilus
  [org.gnome.Calculator.desktop]=gnome-calculator [gnome-calculator.desktop]=gnome-calculator
)
all_manifests="$(cat "$REPO_ROOT"/packages/*.txt)"
for cand in "${!CANDIDATE_PKG[@]}"; do
  pkg="${CANDIDATE_PKG[$cand]}"
  if grep -qx "$pkg" "$REPO_ROOT"/packages/*.txt; then
    pass "candidate $cand -> package $pkg present in manifests"
  else
    fail "candidate $cand -> package $pkg MISSING from manifests"
  fi
done
# hyprpicker (core capture dep) and udisks2 (removable device chain) present
for pkg in hyprpicker udisks2; do
  if grep -qx "$pkg" "$REPO_ROOT"/packages/*.txt; then
    pass "support package $pkg present in manifests"
  else
    fail "support package $pkg MISSING from manifests"
  fi
done
# OnlyOffice must be opt-in (in optional flatpak profile), not the default profile
if grep -qx org.onlyoffice.desktopeditors "$REPO_ROOT/flatpaks/optional.txt"; then
  pass "OnlyOffice present in opt-in flatpak profile"
else
  fail "OnlyOffice not in opt-in flatpak profile"
fi
if grep -qx org.onlyoffice.desktopeditors "$REPO_ROOT/flatpaks/default.txt"; then
  fail "OnlyOffice must NOT be in the default flatpak profile"
else
  pass "OnlyOffice absent from default flatpak profile"
fi

# ── 7. Diagnostics: validation does not mutate defaults ───────────────────
echo "Diagnostics (no mutation)"
root="$(make_scenario)"; enter_scenario "$root"
mk_entry "$root" user org.gnome.Evince.desktop
printf 'application/pdf=org.gnome.Evince.desktop\n' >> "$root/mimeapps"
before=$(count_mutations "$root")
# Validation-only helpers must never call xdg-mime default.
ahr_matrix_current_handler application/pdf >/dev/null
ahr_matrix_mime_handler_is_valid application/pdf >/dev/null
ahr_matrix_desktop_entry_exists org.gnome.Evince.desktop >/dev/null
after=$(count_mutations "$root")
if [[ "$before" == "$after" ]]; then
  pass "validation helpers performed no xdg-mime default writes"
else
  fail "validation helpers mutated state ($before -> $after)"
fi
rm -rf "$root"

# ── 8. OnlyOffice removal safety (no user-document deletion) ───────────────
echo "OnlyOffice removal safety"
root="$(make_scenario)"
export HOME="$root/home"
mkdir -p "$root/home/Documents" "$root/home/.var/app/org.onlyoffice.desktopeditors"
printf 'user contract\n' > "$root/home/Documents/important.odt"
printf 'app data\n' > "$root/home/.var/app/org.onlyoffice.desktopeditors/settings"
# Fake flatpak stub: `flatpak info` reports installed; `flatpak uninstall` ok; `flatpak remotes` ok.
cat > "$root/stub/flatpak" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  info) exit 0 ;;
  remotes) printf 'flathub\n' ;;
  uninstall) exit 0 ;;
  run) exit 0 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$root/stub/flatpak"
export PATH="$root/stub:$PATH"
if bash "$REPO_ROOT/config/artix-hypr-remix/bin/ahr-onlyoffice" remove >/dev/null 2>&1; then
  pass "ahr onlyoffice remove executed"
else
  fail "ahr onlyoffice remove failed"
fi
if [[ -f "$root/home/Documents/important.odt" ]]; then
  pass "user document preserved after OnlyOffice removal"
else
  fail "user document deleted during OnlyOffice removal"
fi
if [[ -d "$root/home/.var/app/org.onlyoffice.desktopeditors" ]]; then
  pass "application data preserved without --purge"
else
  fail "application data deleted without --purge"
fi
rm -rf "$root"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
