# Project documentation index

> **Canonical path registry — update only this file when any `Project_Docs/**/*.md` is added, moved, or removed.** Other docs, code comments, and [AGENTS.md](../.cursor/rules/AGENTS.md) describe *policy*; **paths live here.**
>
> **Tiers:** **II** = draft (work in progress), **III** = definitive contract (`Definitive_Features/` only — no tier III at root), **A** = archived (`Completed_Features/`), **root** = navigation / backlog / templates. **Tier I** (implementation notes) stays **outside** `Project_Docs/` and is not listed here unless policy changes.
>
> **Layout (option B):** `Draft_Features/` (active drafts only), `Definitive_Features/`, `Completed_Features/`. Historical migration notes: [Completed_Features/PD_INDEXING_AND_ORGANIZATION.md](Completed_Features/PD_INDEXING_AND_ORGANIZATION.md).

---

## Folder layout

```
Project_Docs/
  PROJECT_DOC_INDEX.md          ← this file (inventory + policy)
  FEATURE_PLAN_TEMPLATE.md
  ENHANCEMENT_BACKLOG_PLAN.md
  Draft_Features/               ← tier II
  Definitive_Features/          ← tier III
  Completed_Features/           ← tier A (archived)
```

Do **not** add new feature plans at `Project_Docs/` root. No `Meta/` subfolder.

---

## Promotion (draft → definitive or archived)

| Target | When | Action |
|--------|------|--------|
| **`Definitive_Features/`** (tier III) | **Ongoing contract** — must stay aligned with code, `project.godot`, or shared schemas (e.g. physics layer table). Drift is a bug. | Move file; register below; remove any `Draft_Features/` copy; fix cross-links. |
| **`Completed_Features/`** (tier A) | Feature **shipped**, plan **superseded**, or content **extracted** elsewhere. **Snapshot** — drift vs code is **expected**. | Move file; register below; **delete** `Draft_Features/` copy; **no** redirect stubs. |

**Do not** promote to tier III merely because code exists. **Code comments** linking to `Completed_Features/` do **not** make those files authoritative — see [AGENTS.md](../.cursor/rules/AGENTS.md) **Completed_Features scope**.

**Tier III default:** `Definitive_Features/` only. Rare root exception → **exception** note in the Definitive table below with rationale.

---

## Root `Project_Docs/` (navigation & process)

| File | Tier | Role |
|------|------|------|
| [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) | root | **This file** — sole inventory + active doc policy. |
| [FEATURE_PLAN_TEMPLATE.md](FEATURE_PLAN_TEMPLATE.md) | root | Template for new feature plans. |
| [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) | root | Cross-feature parking lot; links draft plans where applicable. |

---

## `Project_Docs/Draft_Features/` (tier II — work in progress only)

**Do not** add redirect stubs or duplicate entries for shipped features — list the real path under `Completed_Features/` or `Definitive_Features/` below and remove the draft file when the work ships or is superseded.

| File | Notes |
|------|-------|
| [Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md](Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md) | AI / conversation scope (in progress). |
| [Draft_Features/CREATURE_3D_ARCHITECTURE.md](Draft_Features/CREATURE_3D_ARCHITECTURE.md) | **3D creature stack:** [CreatureDefinition](res://creature/definition/creature_definition.gd), capabilities, templates, AI intent bridge. |
| [Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) | Evolution + motor genome. |
| [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) | **Canonical:** motivation tree Tier-1/2, **`CreatureDefinition`** traits (−100…+100), goal-kind rollup, habitual **`believed_goal_*`** modulation + strategy-class **`<<Question>>`** Actions **1–3**. Consumed by [CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) + [CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md). |
| [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) | **Creature memory** (working → definitive): goal-aligned beliefs (food, danger, mates, shelter); success-pattern backends + **§14** tuning; read **[CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md)** first for Tier-2 / traits / replay semantics. |
| [Draft_Features/CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md) | Creature fields / schema; memory → [CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md); Tier-2 trait narrative → [CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §3. |
| [Draft_Features/CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) | **Unified motor refactor:** `creature_motor` in `assets/creatures/*/pack_resources.json`, single **`SeekCandidate`** path, **`MotorContext`** integration; motivation tree + traits authoritative in **[CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md)**. |
| [Draft_Features/PLANT_ECOLOGY_PLAN.md](Draft_Features/PLANT_ECOLOGY_PLAN.md) | Long-term plant ecology. |
| [Draft_Features/PLANTS_PLAN.md](Draft_Features/PLANTS_PLAN.md) | Plants / food index (active design; shipped slice archived). |
| [Draft_Features/REPO_LAYOUT_PLAN.md](Draft_Features/REPO_LAYOUT_PLAN.md) | `res://` layout draft (not authoritative). |
| [Draft_Features/SHARED_STATTOPOINT_PLAN.md](Draft_Features/SHARED_STATTOPOINT_PLAN.md) | Stat → point pools. |
| [Draft_Features/VISION_WORLD_BUILDER_PLAN.md](Draft_Features/VISION_WORLD_BUILDER_PLAN.md) | World-builder umbrella. |

---

## `Project_Docs/Definitive_Features/` (tier III — current contract)

**Default location for tier III.** Exceptions (a spec at `Project_Docs/` root) require an explicit **exception** note in this table.

| File | Notes |
|------|-------|
| [Definitive_Features/CREATURE_MOVEMENT.md](Definitive_Features/CREATURE_MOVEMENT.md) | **2D creature movement inventory:** cardinal motor pipeline, config keys, AiDriver tools, carnivore vs herbivore forks (refactor anchor). |
| [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | Env catalog; **§6** = **2D layer/mask** (`project.godot`); **§7** acceptance checklist. |

---

## `Project_Docs/Completed_Features/` (archived — tier A)

**Per [AGENTS.md](../.cursor/rules/AGENTS.md):** snapshots in time; not default authority unless explicitly cited. Code comment links are reference only.

| File | Notes |
|------|-------|
| [Completed_Features/AI_INSTRUCTIONS_PLAN.md](Completed_Features/AI_INSTRUCTIONS_PLAN.md) | Archived rules refactor. |
| [Completed_Features/ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) | Asset pipeline; see `.cursor/rules/assets.mdc` (stub: `focus/asset_management.md`). |
| [Completed_Features/CREATURE_GOALS.md](Completed_Features/CREATURE_GOALS.md) | **Archived:** v1 Herbivore vs Carnivore duel (opposite spawns, dual HUD, N-creature AiDriver, manual playtest log). Snapshot — drift expected. |
| [Completed_Features/CREATURE_GOALS_PLAYTEST_LOG.md](Completed_Features/CREATURE_GOALS_PLAYTEST_LOG.md) | Manual win/cause rows for CREATURE_GOALS balance tuning (companion to archived spec). |
| [Completed_Features/DtC_AI_INT_PLAN.md](Completed_Features/DtC_AI_INT_PLAN.md) | Dodge-the-Creeps AI integration archive. |
| [Completed_Features/EARLY_SPEC_DOC](Completed_Features/EARLY_SPEC_DOC) | Pre-split World Builder scratch; extracted into child plans — **reference only**. |
| [Completed_Features/FORK_HUNTER_KILLER.md](Completed_Features/FORK_HUNTER_KILLER.md) | Fork / mirror workflow (historical policy). |
| [Completed_Features/HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md) | Hunger + bushes POC — **implemented**. |
| [Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md](Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md) | Field / perception archive. |
| [Completed_Features/LOGGING_PLAN.md](Completed_Features/LOGGING_PLAN.md) | Supplanted by `.cursor/rules/logging.mdc` (stub: `focus/logging_instr.md`). |
| [Completed_Features/MOB_AVOIDANCE_PLAN.md](Completed_Features/MOB_AVOIDANCE_PLAN.md) | Shipped motor avoidance (code may link here — **reference only** unless task cites this file). |
| [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) | Object / grid avoidance archive. |
| [Completed_Features/PD_INDEXING_AND_ORGANIZATION.md](Completed_Features/PD_INDEXING_AND_ORGANIZATION.md) | **Completed** Project_Docs reorg (option B) — historical; active policy is **this index** + `AGENTS.md`. |

---

## Related (outside `Project_Docs/`)

| Location | Role |
|----------|------|
| [.cursor/rules/core.mdc](../.cursor/rules/core.mdc) | Agent hub (`alwaysApply`); stub: [AGENTS.md](../.cursor/rules/AGENTS.md). |
| [.cursor/rules/*.mdc](../.cursor/rules/) | Scoped rules: `gdscript`, `logging`, `agentic-runtime-ai`, `assets`, `project-docs`. Stubs: [focus/](../.cursor/rules/focus/). |

---

## Maintenance

1. **Path changes:** Edit **only this file** for inventory moves; then fix broken relative links (grep the old basename).
2. **New draft:** Add a row under `Draft_Features/` when work starts; remove the row and delete the file when shipped (move to `Completed_Features/` or `Definitive_Features/` per **Promotion** above).
3. **No draft stubs** for completed features — register `Completed_Features/` (or `Definitive_Features/`) here instead.
4. **Enhancement backlog:** Link `Draft_Features/…` paths in [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) when tracking active work.
5. **Coordinated migrations:** Folder or glob changes → update [core.mdc](../.cursor/rules/core.mdc), affected `.mdc` rules, and [AGENTS.md](../.cursor/rules/AGENTS.md) stub in the **same** change set.
6. **Link hygiene:** Use **relative** links from each file’s directory (`../` when crossing folders).
7. **Duplication:** One canonical path per topic — e.g. mob avoidance: `Completed_Features/MOB_AVOIDANCE_PLAN.md` only, not a duplicate in `Draft_Features/`.
