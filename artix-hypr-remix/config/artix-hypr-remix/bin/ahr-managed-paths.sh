#!/usr/bin/env bash
# ahr-managed-paths.sh — Machine-readable inventory of every AHR-generated or AHR-modified path.
#
# Format: one record per entry, fields separated by |.
# Records are read by other scripts; this file is not executed directly.
#
# Fields:
#   component|path|shape|writer|ownership|user_editable|backup_policy|restore_policy|required
#
# ownership: framework-owned | managed-derived | user-editable | external | unsupported
# shape: file | directory | symlink | fragment | structured-file
# backup_policy: snapshot | backup-before-edit | none
# restore_policy: full-replace | merge | manual | unsupported

# ── Theme state (fully managed, inside FRAMEWORK_ROOT) ─────────────

MANAGED_PATHS=(
  "theme-state|current/theme|directory|ahr-theme-lib.sh|framework-owned|false|snapshot|full-replace|true"
  "theme-state|current/theme.name|file|ahr-theme-lib.sh|framework-owned|false|snapshot|full-replace|true"
  "theme-state|current/background|symlink|ahr-theme-lib.sh|framework-owned|false|snapshot|full-replace|true"
  "theme-state|current/font.toml|file|ahr-theme-lib.sh|managed-derived|true|backup-before-edit|merge|false"
)

# ── Waybar theme output ────────────────────────────────────────────

MANAGED_PATHS+=(
  "waybar-theme|~/.config/waybar/style.css|file|ahr-theme-lib.sh|managed-derived|true|backup-before-edit|full-replace|false"
)

# ── Mako theme output ──────────────────────────────────────────────

MANAGED_PATHS+=(
  "mako-theme|~/.config/mako/config|file|ahr-theme-lib.sh|managed-derived|true|backup-before-edit|full-replace|false"
)

# ── Ghostty/terminal theme output ──────────────────────────────────

MANAGED_PATHS+=(
  "terminal-theme|~/.config/ghostty/config|file|ahr-theme-lib.sh|managed-derived|true|backup-before-edit|full-replace|false"
)

# ── Foot terminal theme ────────────────────────────────────────────

MANAGED_PATHS+=(
  "foot-theme|~/.config/foot/foot.ini|file|hooks/theme-set.d/10-foot-theme.sh|managed-derived|true|backup-before-edit|full-replace|false"
)

# ── Fontconfig output ──────────────────────────────────────────────

MANAGED_PATHS+=(
  "fontconfig|~/.config/fontconfig/fonts.conf|file|ahr-theme-lib.sh|managed-derived|true|backup-before-edit|full-replace|false"
)

# ── Chromium theme (structured file — partial ownership) ───────────

MANAGED_PATHS+=(
  "chromium-theme|~/.config/chromium/Default/Preferences|structured-file|hooks/theme-set.d/20-chromium-theme.sh|managed-derived|true|backup-before-edit|unsupported|false"
)

# ── VS Code theme (structured file — partial ownership) ────────────

MANAGED_PATHS+=(
  "vscode-theme|~/.config/Code/User/settings.json|structured-file|hooks/theme-set.d/30-vscode-theme.sh|managed-derived|true|backup-before-edit|unsupported|false"
)

# ── Cursor theme (structured file — partial ownership) ─────────────

MANAGED_PATHS+=(
  "cursor-theme|~/.config/Cursor/User/settings.json|structured-file|hooks/theme-set.d/30-vscode-theme.sh|managed-derived|true|backup-before-edit|unsupported|false"
)

# ── OpenCode theme (structured file — partial ownership) ───────────

MANAGED_PATHS+=(
  "opencode-theme|~/.config/opencode/opencode.jsonc|structured-file|hooks/theme-set.d/30-vscode-theme.sh|managed-derived|true|backup-before-edit|unsupported|false"
)

# ── Hyprland managed fragments (user-editable host file) ───────────

MANAGED_PATHS+=(
  "hyprland-managed|~/.config/hypr/hyprland.conf|file|multiple-migrations|user-editable|true|backup-before-edit|manual|false"
)

# ── Waybar config (migration edits) ────────────────────────────────

MANAGED_PATHS+=(
  "waybar-config|~/.config/waybar/config.jsonc|structured-file|migration-20260607|user-editable|true|backup-before-edit|manual|false"
)

# ── Background state symlink (inside FRAMEWORK_ROOT) ────────────────

MANAGED_PATHS+=(
  "background-state|current/background|symlink|ahr-theme-lib.sh|framework-owned|false|snapshot|full-replace|true"
)

# ── Active theme name (inside FRAMEWORK_ROOT) ──────────────────────

MANAGED_PATHS+=(
  "active-theme|current/theme.name|file|ahr-theme-lib.sh|framework-owned|false|snapshot|full-replace|true"
)

# ── Toggle state (runtime state — backup-only, no restore) ─────────

MANAGED_PATHS+=(
  "toggle-state|state/toggles|directory|ahr-toggle-lib.sh|framework-owned|false|snapshot|unsupported|false"
)

# ── Namespace symlinks (handled by namespace-links component) ───────

MANAGED_PATHS+=(
  "namespace-links|~/.local/bin/ahr-*|symlink|namespace-install.sh|framework-owned|false|snapshot|full-replace|false"
)

MANAGED_PATHS+=(
  "namespace-links|~/.local/bin/omarchy-*|symlink|namespace-install.sh|framework-owned|false|snapshot|full-replace|false"
)

# ── Editor default config ──────────────────────────────────────────

MANAGED_PATHS+=(
  "editor-config|~/.config/artix-hypr-remix/env|file|ahr-default-editor|user-editable|true|backup-before-edit|manual|false"
)

# ── Default terminal list ──────────────────────────────────────────

MANAGED_PATHS+=(
  "terminal-list|~/.config/xdg-terminals.list|file|ahr-default-terminal|user-editable|true|backup-before-edit|manual|false"
)

# ── Elephant plugins ───────────────────────────────────────────────

MANAGED_PATHS+=(
  "elephant-plugins|~/.local/share/elephant/plugins|directory|first-run.d/100|managed-derived|false|none|unsupported|false"
)

# ── Compatibility symlink ──────────────────────────────────────────

MANAGED_PATHS+=(
  "compat-symlink|~/.config/omarchy/current|symlink|ahr-theme-lib.sh|framework-owned|false|snapshot|full-replace|false"
)
