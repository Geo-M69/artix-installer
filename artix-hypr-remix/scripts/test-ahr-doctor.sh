#!/usr/bin/env bash
# Focused isolated tests for ahr-doctor network, theme, MIME, and severity rules.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCTOR="$REPO_ROOT/config/artix-hypr-remix/bin/ahr-doctor"
PASS=0
FAIL=0
tmp_root="$(mktemp -d /tmp/ahr-doctor-test-XXXXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

make_fixture() {
  local dir="$1"
  local home="$dir/home" root="$dir/framework" stub="$dir/stub"
  mkdir -p "$home/.local/bin" "$home/.local/share/applications" "$root/bin" \
    "$root/current/theme/backgrounds" "$root/themes/tokyo-night/backgrounds" \
    "$dir/init.d" "$dir/runlevels/default" "$dir/runlevels/sysinit" "$stub"
  printf 'tokyo-night\n' > "$root/current/theme.name"
  printf 'background = "#000000"\n' > "$root/themes/tokyo-night/colors.toml"
  printf '[Icon Theme]\nName=Tokyo\n' > "$root/themes/tokyo-night/icons.theme"
  cp "$root/themes/tokyo-night/colors.toml" "$root/current/theme/colors.toml"
  cp "$root/themes/tokyo-night/icons.theme" "$root/current/theme/icons.theme"
  : > "$root/themes/tokyo-night/backgrounds/wall.jpg"
  ln -s "$root/themes/tokyo-night/backgrounds/wall.jpg" "$root/current/background"
  printf '{"version":"0.1.0","channel":"stable"}\n' > "$root/framework.json"
  printf '[Desktop Entry]\nName=Valid\n' > "$home/.local/share/applications/valid.desktop"

  local service cmd
  for service in dbus elogind bluetoothd NetworkManager connmand; do
    : > "$dir/init.d/$service"
    chmod +x "$dir/init.d/$service"
  done
  for cmd in ahr ahr-menu ahr-menu-keybindings ahr-launch-terminal ahr-launch-apps \
    ahr-launch-browser ahr-launch-files ahr-default-browser ahr-default-terminal \
    ahr-default-editor ahr-repair ahr-system-lock ahr-toggle ahr-toggle-idle \
    ahr-restore-idle ahr-restore-nightlight ahr-launch-wallpaper-session \
    ahr-capture-screenshot ahr-capture-picker ahr-theme ahr-status ahr-doctor \
    ahr-update ahr-update-available ahr-update-framework ahr-restore-component \
    ahr-migrate namespace-install.sh migrate.sh ahr-validate-managed-paths.sh; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$root/bin/$cmd"
    chmod +x "$root/bin/$cmd"
  done
  for cmd in ahr-lib.sh ahr-version.sh ahr-cache.sh ahr-backup-helper.sh \
    ahr-managed-paths.sh ahr-theme-lib.sh ahr-toggle-lib.sh ahr-font-lib.sh; do
    printf '#!/usr/bin/env bash\n# sourced test library\n' > "$root/bin/$cmd"
    chmod 0644 "$root/bin/$cmd"
  done
  for service in dbus elogind bluetoothd; do
    : > "$dir/runlevels/default/$service"
  done
  for cmd in ahr ahr-update ahr-update-framework ahr-update-available ahr-restore-component ahr-doctor; do
    ln -s "$root/bin/$cmd" "$home/.local/bin/$cmd"
  done

  cat > "$stub/rc-service" <<'EOF'
#!/usr/bin/env bash
case " ${AHR_TEST_ACTIVE_SERVICES:-} " in *" $1 "*) exit 0;; *) exit 1;; esac
EOF
  cat > "$stub/ip" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-o" ]]; then
  [[ "${AHR_TEST_HAS_ADDRESS:-1}" == 1 ]] && printf '2: eth0    inet 192.0.2.10/24 scope global eth0\n'
elif [[ "$1" == "route" ]]; then
  [[ "${AHR_TEST_HAS_ROUTE:-1}" == 1 ]] && printf 'default via 192.0.2.1 dev eth0\n'
fi
EOF
  cat > "$stub/xdg-mime" <<'EOF'
#!/usr/bin/env bash
mime="${3:-}"
case "$mime" in
  video/mp4) printf '%s\n' "${AHR_TEST_VIDEO_DEFAULT:-}" ;;
  video/webm) printf '%s\n' "${AHR_TEST_WEBM_DEFAULT:-}" ;;
  *) printf 'valid.desktop\n' ;;
esac
EOF
  chmod +x "$stub/rc-service" "$stub/ip" "$stub/xdg-mime"
  for cmd in pacman grim hyprctl rc-update xdg-settings xdg-open wl-paste cliphist wofi; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/$cmd"
    chmod +x "$stub/$cmd"
  done
}

run_case() {
  local label="$1" expected="$2" pattern="$3" mode="$4"
  local dir="$tmp_root/${label//[^A-Za-z0-9]/_}"
  make_fixture "$dir"
  local home="$dir/home" root="$dir/framework" stub="$dir/stub"
  local active="connmand dbus elogind bluetoothd" video="" webm="" rc_cmd="rc-service" has_address=1
  case "$mode" in
    networkmanager) active="NetworkManager dbus elogind bluetoothd" ;;
    both) active="NetworkManager connmand dbus elogind bluetoothd" ;;
    noaddress) has_address=0 ;;
    none) active="dbus elogind bluetoothd" ;;
    unavailable-service) rc_cmd="missing-rc-service" ;;
    legacy) rm -rf "$root/current/theme"; ln -s "$root/themes/tokyo-night" "$root/current/theme" ;;
    missing-name) rm -f "$root/current/theme.name" ;;
    invalid-name) printf '../bad\n' > "$root/current/theme.name" ;;
    missing-source) printf 'missing\n' > "$root/current/theme.name" ;;
    missing-current) rm -rf "$root/current/theme" ;;
    escaping-link) rm -rf "$root/current/theme"; ln -s /tmp "$root/current/theme" ;;
    inconsistent) printf 'background = "#bad"\n' > "$root/current/theme/colors.toml" ;;
    valid-video) video="valid-video.desktop"; printf '[Desktop Entry]\nName=Video\nMimeType=video/mp4;\n' > "$home/.local/share/applications/valid-video.desktop" ;;
    missing-video) video="gone.desktop" ;;
    multiple-candidates) printf '[Desktop Entry]\nName=One\nMimeType=video/mp4;\n' > "$home/.local/share/applications/player-one.desktop"; printf '[Desktop Entry]\nName=Two\nMimeType=video/mp4;\n' > "$home/.local/share/applications/player-two.desktop" ;;
    webm-only) webm="browser.desktop"; printf '[Desktop Entry]\nName=Browser\nMimeType=video/webm;\n' > "$home/.local/share/applications/browser.desktop" ;;
    enabled-nm) : > "$dir/runlevels/default/NetworkManager" ;;
    executable-cache-lib) chmod 0755 "$root/bin/ahr-cache.sh" ;;
    missing-cache-lib) rm -f "$root/bin/ahr-cache.sh" ;;
    unreadable-cache-lib) chmod 000 "$root/bin/ahr-cache.sh" ;;
    nonexecutable-command) chmod 0644 "$root/bin/ahr-update" ;;
  esac
  local output rc=0
  output="$(PATH="$stub:$PATH" HOME="$home" AHR_FRAMEWORK_ROOT="$root" \
    AHR_INITD_DIR="$dir/init.d" AHR_RUNLEVELS_DIR="$dir/runlevels" \
    AHR_RC_SERVICE_CMD="$rc_cmd" AHR_IP_CMD=ip AHR_LOCAL_BIN="$home/.local/bin" \
    AHR_TEST_ACTIVE_SERVICES="$active" AHR_TEST_HAS_ADDRESS="$has_address" \
    AHR_TEST_VIDEO_DEFAULT="$video" AHR_TEST_WEBM_DEFAULT="$webm" bash "$DOCTOR" 2>&1)" || rc=$?
  if [[ "$rc" == "$expected" && "$output" == *"$pattern"* ]]; then
    pass "$label"
  else
    fail "$label (exit=$rc expected=$expected; expected output: $pattern)"
    printf '%s\n' "$output" >&2
  fi
}

run_case connman-active 0 'supported network manager active: connmand' base
run_case networkmanager-active 0 'supported network manager active: NetworkManager' networkmanager
run_case both-active 0 'multiple supported network managers are active' both
run_case connman-no-address 1 'no non-loopback address' noaddress
run_case no-supported-manager 1 'no supported network manager is active' none
run_case service-command-unavailable 1 'missing-rc-service unavailable' unavailable-service
run_case theme-directory 0 'current theme directory matches tokyo-night' base
run_case theme-legacy-symlink 0 'current theme legacy symlink' legacy
run_case theme-missing-name 1 'theme name missing or unreadable' missing-name
run_case theme-invalid-name 1 'theme name is empty or invalid' invalid-name
run_case theme-missing-source 1 'named source theme is missing' missing-source
run_case theme-missing-directory 1 'theme path missing or unsupported' missing-current
run_case theme-escaping-link 1 'symlink escapes allowed theme roots' escaping-link
run_case theme-inconsistent-directory 1 'directory does not match theme.name' inconsistent
run_case mime-valid-handler 0 'Default video player (video/mp4) → valid-video.desktop' valid-video
run_case mime-missing-handler-warning 0 'gone.desktop (desktop entry not found)' missing-video
run_case mime-no-default-warning 0 'Default video player (video/mp4) — no default handler set' base
run_case mime-several-candidates-warning 0 'Default video player (video/mp4) — no default handler set' multiple-candidates
run_case mime-webm-only-warning 0 'Default video player (video/mp4) — no default handler set' webm-only
run_case warnings-only 0 'All checks passed.' enabled-nm
run_case cache-library-0644 0 'OK: ahr-cache.sh (library)' base
run_case cache-library-0755 0 'OK: ahr-cache.sh (library)' executable-cache-lib
run_case cache-library-missing 1 'MISSING: ahr-cache.sh' missing-cache-lib
run_case cache-library-unreadable 1 'MISSING: ahr-cache.sh' unreadable-cache-lib
run_case command-nonexecutable 1 'MISSING: ahr-update' nonexecutable-command

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
