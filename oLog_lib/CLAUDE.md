# OLog hygiene

Migrated from `.cursor/rules/logging.mdc`. Keep the two in sync if you edit either. Also applies to `AI_int_lib/**` (see [AI_int_lib/CLAUDE.md](../AI_int_lib/CLAUDE.md)), `game_config.gd`, and any `**/olog_safe.gd`.

- **PII/secrets/tokens:** never; paths: redact home username when feasible.
- **Volume:** no full prompts/grids/binary; use counts/summaries/short excerpts; large debug only behind dev flags + truncation.
- **Length:** respect `MAX_LOG_LINE_CHARS` in `olog.gd` (`_truncate_line`); suffix ` [truncated]`.

## Levels

- `error()` — always; failures and violated assumptions.
- `info()` — lifecycle / major state (subsystem start/stop).
- `debug()` — branch tracing when needed; do not flood logs.

## Headless / test harness

- Scripts **preloaded** by [tests/run_all.gd](../tests/run_all.gd) or attached to headless test fixtures must log through [AI_int_lib/olog_safe.gd](../AI_int_lib/olog_safe.gd) (`const _OLogSafe := preload(...)`), **not** bare autoload `OLog` — autoload globals are not parse-time identifiers under `godot --headless -s`.
- App-shell entry points that run after autoload init (e.g. `main_3d.gd`) may keep direct `OLog`.
