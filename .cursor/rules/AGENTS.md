# Agent instructions

## Agent role

You are an expert game developer focused on C++, the Godot game engine, and integrating AI into game engines.

## Behavioral instructions

- **Ambiguity protocol:** If a requirement is unclear or not explicitly stated in the Project Documents, **STOP and ask for clarification**. Do not guess. **Project Documents** = files in `./.cursor/rules/*` plus active markdown under `./Project_Docs/` as defined below (not `Completed_Features/` unless the user explicitly cites them).
- **Project_Docs layout (inventory: [PROJECT_DOC_INDEX.md](../../Project_Docs/PROJECT_DOC_INDEX.md)):**
  - **Start here:** `./Project_Docs/PROJECT_DOC_INDEX.md` — **canonical path registry** for every project doc; update **only this file** when moving or adding `*.md` under `Project_Docs/`.
  - **Draft features (tier II):** `./Project_Docs/Draft_Features/**/*.md` — **work in progress only** (no stubs for shipped features); `<<Question>>` / `<<Comment>>` expected.
  - **Definitive contracts (tier III):** `./Project_Docs/Definitive_Features/**/*.md` — minimize drift vs code / `project.godot` (e.g. layer tables).
  - **Root navigation (same folder as index):** `./Project_Docs/PROJECT_DOC_INDEX.md`, `FEATURE_PLAN_TEMPLATE.md`, `ENHANCEMENT_BACKLOG_PLAN.md` — process and backlog; not feature implementation specs unless explicitly cited.
  - **Archived:** `./Project_Docs/Completed_Features/**` — see **Completed_Features scope** below.
- **Completed_Features scope:** Files under `./Project_Docs/Completed_Features/**` are **snapshots in time**; drift vs current code is **expected**. Do **not** treat them as authoritative requirements when implementing, reviewing, or reconciling behavior unless the user **explicitly cites** that file for the task. **Code comments** that link to `Completed_Features/` do **not** elevate those files to definitive authority — they are reference pointers only. Use archived docs for **initial design intention** when no authoritative active doc exists on the topic; otherwise prefer `Draft_Features/`, `Definitive_Features/`, or the plan the task cites. Active specs live in `Draft_Features/`, `Definitive_Features/`, root navigation files above, and `.cursor/rules`.
- **Feature-doc scope guard:** When implementing a specific feature, treat only the **explicitly referenced** feature plan (plus `./.cursor/rules/*`) as authoritative. Any other file in `Draft_Features/` or `Definitive_Features/` that is not referenced by the active request is a **feature draft** and must not override the cited spec.
- **Refactoring:** Do not rename or move Project Docs or rule files casually — it breaks Cursor rule attachment. **Coordinated migrations** (folder changes, link updates, `AGENTS.md` + [PROJECT_DOC_INDEX.md](../../Project_Docs/PROJECT_DOC_INDEX.md) in one change) are allowed when a maintainer directs them; see that index **Maintenance** section.

## Formatting

**Applies when:** You add or change formatted source code.

**Follow the project style guide** (workspace [`.editorconfig`](../../.editorconfig) is authoritative for indent):

- Use **2-space indentation** with **spaces only** — **never** insert tab characters (`\t`) in source. Godot GDScript **fails to parse** files that mix tabs and spaces in the same file.
- When editing an existing file, **match its current indent** (this repo’s `.gd` files use spaces). Do not reindent whole files unless the task requires it.
- Put the opening brace on the same line when the language's usual style allows it.
- Put spaces around operators.

**Editor / Cursor:** Use **Insert Spaces** (not tabs) for `.gd` and other project sources. Workspace [`.vscode/settings.json`](../../.vscode/settings.json) enforces this for VS Code / Cursor; Godot Editor has its own indent settings — keep them on spaces, size 2, for GDScript.

**After editing any `*.gd` file:** Run `python tools/check_gdscript_no_tabs.py` from the repo root (exit 0 required). See [gdscript_indent.md](./focus/gdscript_indent.md) for recovery if tabs were introduced.

## Documenting / comments

**Applies when:** You write or modify a function (or equivalent unit).

**Include:**

- What the function is for.
- What each parameter means.
- What it returns (or side effects), when that is not obvious from names alone.
- A short usage example when behavior is non-obvious or has non-trivial preconditions.

## Testing / unit tests

**Applies when:** You implement a new feature.

**Do:**

- Add unit tests that cover the important code paths and meaningful edge cases.
- Prefer a clear Arrange-Act-Assert (or equivalent) structure.
- Use test names that state intent.

## Project Docs interactions

### Agentic assisted design

**Applies when:** You write or revise design documents that an agentic developer is expected to implement from.

**Use these embedded markers** so the next review pass can find open design conversation:

- `<<Question: …>>` - Ask the agent for information or clarification the next time it reads this doc.
- `<<Comment: …>>` - Note an area that needs more thought, a reminder for the author, or something author and agent should resolve together.

### Debugging assistance (OLog)

**Applies when:** You create or refactor code where understanding control flow or failures matters.

**Use `OLog` roughly as follows** (full policy: [logging_instr.md](./focus/logging_instr.md)):

- `info()` - Major lifecycle or state events (e.g. thread or subsystem start/stop).
- `debug()` - Frequent path tracing when needed (e.g. a collision or decision branch), without flooding logs.
- `error()` - Likely failures, violated assumptions, or recoverable errors worth investigating.

## Focus areas (index)

Detailed rules live only in these files; add more pointers here as new focus areas appear (e.g. UI).

**Ignore inconsistencies in historical files:** Files under `./Project_Docs/Completed_Features` are archived; see **Completed_Features scope** under Behavioral instructions. Do not treat them as active requirements unless a maintainer explicitly asks. Cross-doc drift with those files is expected.

- **Project_Docs (start here):** [PROJECT_DOC_INDEX.md](../../Project_Docs/PROJECT_DOC_INDEX.md) — layout, tiers, promotion, and maintenance (`Draft_Features/`, `Definitive_Features/`, `Completed_Features/`)
- **Creature goal drivers (Tier-2 / traits / habitual replay semantics):** [CREATURE_GOAL_DRIVERS.md](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md) — canonical hub; implementation in [CREATURE_MOVEMENT_V2.md](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md) + persistence in [CREATURE_MEMORY.md](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)
- **GDScript indent (spaces only, no tabs):** [gdscript_indent.md](./focus/gdscript_indent.md)
- **Logging (policy, PII, volume):** [logging_instr.md](./focus/logging_instr.md)
- **Runtime / in-game AI agents (embedded LLM), not IDE assistants:** [agentic_coding.md](./focus/agentic_coding.md)
- **Assets (`res://assets/`, `pack_resources.json`, variants):** [asset_management.md](./focus/asset_management.md) — full design in archived [ASSET_MANAGEMENT_PLAN.md](../../Project_Docs/Completed_Features/ASSET_MANAGEMENT_PLAN.md)
