# Migration Policy

Artix Hypr Remix migrations are small, ordered repair steps for framework state and known config transitions.

## Goals

- Keep existing installs moving forward without requiring a full reinstall.
- Make every migration idempotent.
- Prefer narrow changes over broad rewrites.
- Preserve user changes unless a migration is explicitly scoped to a managed block or state file.
- Make skipped or failed migrations visible and recoverable.

## Naming And Ordering

Migration files live in:

```text
~/.config/artix-hypr-remix/migrations
```

Names should use a sortable date prefix and a short action name:

```text
YYYYMMDD-short-description.sh
```

The migration runner sorts files by name before execution.

## State

Migration state lives in:

```text
~/.local/state/artix-hypr-remix/migrations
~/.local/state/artix-hypr-remix/migrations/skipped
~/.local/state/artix-hypr-remix/migrations/migrate.log
```

Applied migrations are marked by filename in the migration state directory. Skipped migrations are marked by filename under `skipped`.

## Safety Rules

- A migration must be safe to run more than once.
- A migration must check whether its target file/path exists before editing.
- A migration must avoid replacing whole user-edited files when a managed block or state file can solve the problem.
- If a migration must rewrite a user config file, it should create a timestamped backup first.
- A migration should skip gracefully when its target feature is not installed.
- A migration should fail loudly when continuing would leave the framework in an ambiguous state.

## Recovery

Useful commands:

```bash
ahr migrate --status
ahr migrate --dry-run
ahr migrate --retry-skipped
ahr repair --migrations
```

When a migration is skipped, review `migrate.log`, run a dry-run, then retry skipped migrations. Do not delete migration state markers unless the migration result has been manually verified.

## Future Config Format Changes

For future config changes:

- Prefer adding new files or managed blocks over editing user-controlled sections.
- Keep old config readable for at least one milestone when possible.
- Document any user-visible behavior change in the relevant milestone kickoff or release notes.
- Add post-install smoke or doctor checks when a migration is important for desktop health.
