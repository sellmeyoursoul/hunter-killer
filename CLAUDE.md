# Agent instructions

Migrated from the Cursor rule set (`.cursor/rules/core.mdc` + `AGENTS.md` + `subagent-governance.mdc` + `subagent-provisioning.mdc`) so Claude Code has the same always-on context Cursor was injecting. If you edit the source `.cursor/rules/*.mdc` files, mirror the change here — they are two copies of one policy, not two policies.

## Agent role

You are an expert game developer focused on C++, the Godot game engine, and integrating AI into game engines.

## Behavioral instructions

- **Ambiguity protocol:** If a requirement is unclear or not explicitly stated in the Project Documents, **STOP and ask for clarification**. Do not guess. **Project Documents** = files in `./.cursor/rules/*` plus this file plus active markdown under `./Project_Docs/` as defined below (not `Completed_Features/` unless the user explicitly cites them).
- **Observation vs code:** When the user describes runtime behavior, symptoms, or intent that **conflicts with what the code actually does**, verify in the codebase first. If the mismatch holds, **push back clearly** — cite the relevant paths and explain what the code does instead of agreeing or changing code to match a mistaken observation. Ask what they saw (steps, scene, config) only when that helps reconcile the gap; do not defer to the observation when the source contradicts it.
- **Project_Docs layout** (inventory: [PROJECT_DOC_INDEX.md](Project_Docs/PROJECT_DOC_INDEX.md)):
  - **Start here:** `./Project_Docs/PROJECT_DOC_INDEX.md` — **canonical path registry** for every project doc; update **only this file** when moving or adding `*.md` under `Project_Docs/`.
  - **Draft features (tier II):** `./Project_Docs/Draft_Features/**/*.md` — **work in progress only** (no stubs for shipped features); `<<Question>>` / `<<Comment>>` expected.
  - **Definitive contracts (tier III):** `./Project_Docs/Definitive_Features/**/*.md` — minimize drift vs code / `project.godot` (e.g. layer tables).
  - **Root navigation (same folder as index):** `PROJECT_DOC_INDEX.md`, `FEATURE_PLAN_TEMPLATE.md`, `ENHANCEMENT_BACKLOG_PLAN.md` — process and backlog; not feature implementation specs unless explicitly cited.
  - **Archived:** `./Project_Docs/Completed_Features/**` — see **Completed_Features scope** below.
  - Full authoring conventions (draft markers, status vocabulary, code↔doc sync playbook) live in [Project_Docs/CLAUDE.md](Project_Docs/CLAUDE.md) — read it before touching anything under `Project_Docs/`.
- **Completed_Features scope:** Files under `./Project_Docs/Completed_Features/**` are **snapshots in time**; drift vs current code is **expected**. Do **not** treat them as authoritative requirements when implementing, reviewing, or reconciling behavior unless the user **explicitly cites** that file for the task. Code comments that link to `Completed_Features/` do **not** elevate those files to definitive authority — they are reference pointers only. Use archived docs for initial design intention when no authoritative active doc exists on the topic; otherwise prefer `Draft_Features/`, `Definitive_Features/`, or the plan the task cites.
- **Feature-doc scope guard:** When implementing a specific feature, treat only the **explicitly referenced** feature plan (plus this file and `./.cursor/rules/*`) as authoritative. Any other file in `Draft_Features/` or `Definitive_Features/` that is not referenced by the active request is a draft and must not override the cited spec.
- **Refactoring:** Do not rename or move Project Docs or rule files casually — it breaks Cursor rule attachment and the nested `CLAUDE.md` files below. Coordinated migrations (folder changes, link updates, index update in one change) are allowed when a maintainer directs them.

## Doc sync (code ↔ Project_Docs)

**Applies when:** You add or change shipped behavior, public APIs, config keys/schemas, collision layers/masks, acceptance-relevant file paths, or data contracts documented in active Project_Docs.

- **Same change set (strict):** Doc updates ship **with** the code change — doc drift in active tiers is a defect, not a follow-up.
- **Resolve authoritative doc (in order):**
  1. Feature plan **explicitly cited** in the task
  2. Code comments linking to `Project_Docs/...` (section anchors count)
  3. [PROJECT_DOC_INDEX.md](Project_Docs/PROJECT_DOC_INDEX.md) topic → path tables
  4. If none exists and the change is user-facing or contract-like → **stop and ask** whether to extend an existing doc or add a new `Draft_Features/` plan (register in index)
- **Tier rules:**
  - **`Definitive_Features/`** — update contract sections: tables, config keys, layer maps, file-path inventories, "implementation snapshot" blocks, acceptance checklists. These must match code after the change.
  - **`Draft_Features/`** — update the sections the task or code comments reference (technical design, acceptance criteria, open questions). Resolve or add `<<Question>>` / `<<Comment>>` when the code answers them.
  - **`Completed_Features/`** — **do not** update to match new code (snapshots; drift expected). If behavior supersedes an archive, update **active** draft/definitive docs instead.
- **Exclusions (no doc edit required):** Pure refactors with zero behavior/API/config contract change; typo-only fixes; user explicitly requests code-only.
- **Playbook:** Full how-to in [Project_Docs/CLAUDE.md](Project_Docs/CLAUDE.md) — read it when syncing.

## Formatting

**Applies when:** You add or change formatted source code.

- Follow [`.editorconfig`](.editorconfig): opening brace on same line when usual; spaces around operators.
- **GDScript (`*.gd`):** Godot rejects files that mix tabs with space indentation in the same file.
  1. **Spaces only** — 2 spaces per indent (`.editorconfig` `[*.gd]`).
  2. **Never paste tab-indented blocks** without re-indenting to spaces first.
  3. **Match the open file** — every new/changed line uses spaces (no `\t`).
  4. **Do not blind `\t` → two-spaces replace** on the whole file; prefer `line.expandtabs(2)` on original tabbed text, or re-indent from git.
  5. **Before marking a `.gd` coding task done**, run from repo root: `python tools/check_gdscript_no_tabs.py` — exit code must be `0`.
  6. **Recovery when tabs were introduced:** `git checkout HEAD -- path/to/file.gd` if the committed version is space-clean, then re-apply changes with spaces only (or `expandtabs(2)` on a tabbed backup) and re-run the check script.

## Documenting / comments

**Applies when:** You write or modify a function (or equivalent unit).

**Include:** purpose; parameter meanings; return value or side effects when not obvious; short usage example when behavior is non-obvious.

## Testing / unit tests

**Applies when:** You implement a new feature.

- Cover important paths and meaningful edge cases; Arrange-Act-Assert; intent-revealing test names.

## Debugging (OLog)

**Applies when:** Control flow or failures need tracing. Full policy lives in [oLog_lib/CLAUDE.md](oLog_lib/CLAUDE.md) and [AI_int_lib/CLAUDE.md](AI_int_lib/CLAUDE.md) — read whichever is in scope when editing log or AI runtime code.

## Directory-scoped context

Claude Code loads a directory's `CLAUDE.md` automatically once you're working in that tree — these replace Cursor's glob-triggered `.mdc` rules:

| Directory | Covers |
|---|---|
| [Project_Docs/CLAUDE.md](Project_Docs/CLAUDE.md) | Draft markers, status vocabulary, code↔doc sync playbook |
| [assets/CLAUDE.md](assets/CLAUDE.md) | `res://assets/` layout, `pack_resources.json`, `_shared` resolution |
| [AI_int_lib/CLAUDE.md](AI_int_lib/CLAUDE.md) | In-game embedded LLM runtime design priorities + OLog hygiene |
| [oLog_lib/CLAUDE.md](oLog_lib/CLAUDE.md) | OLog hygiene (PII, volume, line cap, levels) |

`logging.mdc`'s hygiene rules also apply to `game_config.gd` and any `**/olog_safe.gd` file even outside those two directories — see [oLog_lib/CLAUDE.md](oLog_lib/CLAUDE.md) if you touch those.

## Subagent routing (domain specialists)

Route by **primary write-target directory** using the **Agent** tool with the matching `subagent_type`, defined in `.claude/agents/`. Do not implement cross-domain edits directly yourself when a single specialist's scope covers the target — delegate instead. When a task spans multiple known domains with an explicit path list, use `code-executor`. When a path is wholly unmapped by any row below, say so and ask whether to proceed inline or define a new specialist (mirroring `.cursor/rules/subagent-provisioning.mdc` and `.cursor/agents/_TEMPLATE.md`) before continuing.

| Primary write path | Agent |
|---|---|
| `creature/motor/` | `creature-motor` |
| `creature/definition/`, `creature/capabilities/`, `creature/species/`, `creature/templates/`, `creature/memory/`, `creature/creature_root_3d.gd`, `creature/awareness_debug_overlay_3d.gd` | `creature-entity` |
| `AI_int_lib/`, `inference/` | `ai-runtime` |
| `environment/`, `assets/locations/`, `assets/environment/`, `assets/plants/` | `environment-world` |
| `main_3d.gd`, `main_3d.tscn`, `hud.gd`, `hud.tscn`, `game_config.gd`, `game_config.json`, `oLog_lib/`, `pack_resource_resolver.gd`, `product_brand.gd`, `project.godot`, `art/` | `app-shell` |
| `assets/creatures/`, `assets/_shared/` | `assets-pack` |
| `tests/`, `tools/` | `test-harness` |
| `Project_Docs/`, `.cursor/rules/` (contract sync) | `project-docs` |
| `Project_Docs/Draft_Features/` (design only, pre-implementation) | `feature-designer` |
| Explicit multi-domain path list you already have | `code-executor` |

Doc sync, provisioning, and every other cross-cutting rule above still apply inside a delegated agent's run — these routing rows only decide *who* does the edit, not which policy governs it.

**Feature hub (reference, not a rule):** [CREATURE_GOAL_DRIVERS.md](Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md) — movement in [CREATURE_MOVEMENT_V3.md](Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md), memory in [CREATURE_MEMORY.md](Project_Docs/Draft_Features/CREATURE_MEMORY.md).
