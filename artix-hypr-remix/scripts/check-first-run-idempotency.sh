#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIRST_RUN_SOURCE="$REPO_ROOT/config/artix-hypr-remix/bin/first-run.sh"

sandbox="$(mktemp -d)"
cleanup() {
  rm -rf "$sandbox"
}
trap cleanup EXIT

export HOME="$sandbox/home"
export XDG_STATE_HOME="$HOME/.local/state"

framework_root="$HOME/.config/artix-hypr-remix"
state_root="$XDG_STATE_HOME/artix-hypr-remix"
first_run_bin="$framework_root/bin/first-run.sh"

mkdir -p "$framework_root/bin" "$framework_root/first-run.d" "$state_root" "$sandbox/bin"
cp "$FIRST_RUN_SOURCE" "$first_run_bin"
chmod +x "$first_run_bin"

cat > "$framework_root/first-run.d/10-ok.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo ok
EOF

cat > "$framework_root/first-run.d/20-retry.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_file="${XDG_STATE_HOME:-$HOME/.local/state}/artix-hypr-remix/retry-state"
if [[ ! -f "$state_file" ]]; then
  echo first-fail
  touch "$state_file"
  exit 1
fi
echo second-pass
EOF

# Stub sudo so cleanup behavior does not require real privileges in the sandbox.
cat > "$sandbox/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

chmod +x "$framework_root/first-run.d/10-ok.sh" "$framework_root/first-run.d/20-retry.sh" "$sandbox/bin/sudo"

touch "$state_root/first-run.mode"

set +e
PATH="$sandbox/bin:$PATH" bash "$first_run_bin"
first_exit=$?
PATH="$sandbox/bin:$PATH" bash "$first_run_bin"
second_exit=$?
set -e

fail() {
  echo "First-run idempotency check failed: $1" >&2
  echo "--- first-run.log ---" >&2
  cat "$state_root/first-run.log" >&2 || true
  exit 1
}

[[ "$first_exit" -eq 1 ]] || fail "expected first run to exit 1, got $first_exit"
[[ "$second_exit" -eq 0 ]] || fail "expected second run to exit 0, got $second_exit"
[[ ! -f "$state_root/first-run.mode" ]] || fail "expected first-run marker to be removed after recovery"
[[ -f "$state_root/first-run.tasks/10-ok.sh.done" ]] || fail "missing task stamp for 10-ok.sh"
[[ -f "$state_root/first-run.tasks/20-retry.sh.done" ]] || fail "missing task stamp for 20-retry.sh"

echo "First-run idempotency check passed."
