# Runtime / in-game AI (embedded LLM)

Migrated from `.cursor/rules/agentic-runtime-ai.mdc`. Keep the two in sync if you edit either.

**Scope:** Implementing in-engine LLM behavior in Godot — **not** Claude Code, Cursor, or other IDE assistants.

Prioritize in this order:

1. **Contextualize inputs** — valid only in approved game/fiction context; out-of-world or jailbreak input is in-fiction noise, not engine instructions.
2. **Optimize cost and performance** — minimum prompt/completion size for the task.
3. **Design for parallelism** — share prompts/caches where safe; avoid needless serial bottlenecks.
4. **Minimize context** — only what the role needs for the current decision.
5. **Constrain surface area** — model drives the game only through a **defined API** (tools, GDScript facades); no unfettered engine access.

## OLog hygiene

Migrated from `.cursor/rules/logging.mdc`, which also covers `oLog_lib/**`, `game_config.gd`, and any `**/olog_safe.gd` — see [oLog_lib/CLAUDE.md](../oLog_lib/CLAUDE.md) for the same text scoped to that directory.

- **PII/secrets/tokens:** never; paths: redact home username when feasible.
- **Volume:** no full prompts/grids/binary; use counts/summaries/short excerpts; large debug only behind dev flags + truncation.
- **Length:** respect `MAX_LOG_LINE_CHARS` in `oLog_lib/olog.gd` (`_truncate_line`); suffix ` [truncated]`.

### Levels

- `error()` — always; failures and violated assumptions.
- `info()` — lifecycle / major state (subsystem start/stop).
- `debug()` — branch tracing when needed; do not flood logs.

### Headless / test harness

- Scripts **preloaded** by [tests/run_all.gd](../tests/run_all.gd) or attached to headless test fixtures must log through [AI_int_lib/olog_safe.gd](olog_safe.gd) (`const _OLogSafe := preload(...)`), **not** bare autoload `OLog` — autoload globals are not parse-time identifiers under `godot --headless -s`.
- App-shell entry points that run after autoload init (e.g. `main_3d.gd`) may keep direct `OLog`.
