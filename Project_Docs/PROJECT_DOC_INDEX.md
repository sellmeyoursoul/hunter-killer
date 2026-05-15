# Project documentation index

> **Purpose:** Single place to **find** markdown under `Project_Docs/` and see a **proposed tier** (see [PD_INDEXING_AND_ORGANIZATION.md](PD_INDEXING_AND_ORGANIZATION.md)). Tiers: **I** = implementation/ephemeral, **II** = draft feature, **III** = definitive contract, **A** = archived (`Completed_Features/`), **meta** = templates and repo policy.  
>
> **Status:** Initial inventory from repo scan; **tier column is provisional** until maintainers complete the review in `PD_INDEXING_AND_ORGANIZATION.md`.

---

## Top-level `Project_Docs/*.md`

| File | Proposed tier | Notes |
|------|----------------|-------|
| [AI_INT_CONVERSATION_SCOPE_PLAN.md](AI_INT_CONVERSATION_SCOPE_PLAN.md) | II | AI / conversation scope draft. |
| [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) | II | Long-horizon design. |
| [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) | II → III? | Creature fields / schema; promote to definitive as code converges. |
| [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) | II / meta | Backlog / enhancement tracking. |
| [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) | II → III? | Env + passibility; **§6** = **2D layer/mask** (hunger **`solid_shrub`** / **`open_shrub`**); **§7** acceptance checklist. |
| [FEATURE_PLAN_TEMPLATE.md](FEATURE_PLAN_TEMPLATE.md) | meta | Template for new plans. |
| [FORK_HUNTER_KILLER.md](FORK_HUNTER_KILLER.md) | meta | Fork / process notes. |
| [MOB_AVOIDANCE_PLAN.md](MOB_AVOIDANCE_PLAN.md) | II | **Review:** also `Completed_Features/MOB_AVOIDANCE_PLAN.md` — clarify which is current. |
| [PD_INDEXING_AND_ORGANIZATION.md](PD_INDEXING_AND_ORGANIZATION.md) | meta | Doc taxonomy / folder strategy task. |
| [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) | II | Ecology draft. |
| [PLANTS_PLAN.md](PLANTS_PLAN.md) | II | Plants / food index; **`res://assets/plants/solid_shrub/`**, **`open_shrub/`**; implementation + spec in [Completed_Features/HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md). |
| [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) | meta | This index. |
| [REPO_LAYOUT_PLAN.md](REPO_LAYOUT_PLAN.md) | II | Repository layout planning. |
| [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md) | II | Shared stat design. |
| [VISION_WORLD_BUILDER_PLAN.md](VISION_WORLD_BUILDER_PLAN.md) | II | World builder vision. |

---

## `Project_Docs/Completed_Features/` (archived)

**Per [AGENTS.md](../.cursor/rules/AGENTS.md):** not default authority for new implementation unless explicitly cited.

| File | Tier | Notes |
|------|------|-------|
| [Completed_Features/AI_INSTRUCTIONS_PLAN.md](Completed_Features/AI_INSTRUCTIONS_PLAN.md) | A | Archived. |
| [Completed_Features/ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) | A | Asset pipeline; background for `.cursor/rules/focus/asset_management.md`. |
| [Completed_Features/DtC_AI_INT_PLAN.md](Completed_Features/DtC_AI_INT_PLAN.md) | A | Archived. |
| [Completed_Features/FORK_HUNTER_KILLER.md](Completed_Features/FORK_HUNTER_KILLER.md) | A | **Review:** overlap with top-level `FORK_HUNTER_KILLER.md`. |
| [Completed_Features/HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md) | A | Hunger + bushes POC — **implemented** (`player`/`main`/`hud`/`mob`, `assets/plants/`). |
| [Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md](Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md) | A | Field / perception archive. |
| [Completed_Features/LOGGING_PLAN.md](Completed_Features/LOGGING_PLAN.md) | A | Policy supplanted by `.cursor/rules/focus/logging_instr.md`. |
| [Completed_Features/MOB_AVOIDANCE_PLAN.md](Completed_Features/MOB_AVOIDANCE_PLAN.md) | A | **Compare** to top-level `MOB_AVOIDANCE_PLAN.md`. |
| [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) | A | Object avoidance / grid; common historical reference. |

---

## Related (outside `Project_Docs/`)

| Location | Role |
|----------|------|
| [.cursor/rules/AGENTS.md](../.cursor/rules/AGENTS.md) | Agent scope; `Completed_Features` rule; doc precedence. |
| [.cursor/rules/focus/](../.cursor/rules/focus/) | Narrow **policy** extracts (logging, assets, agents, etc.). |

---

## Maintenance

When adding or removing a `*.md` under `Project_Docs/`, update **this file** in the same change (or immediately after). Use [PD_INDEXING_AND_ORGANIZATION.md](PD_INDEXING_AND_ORGANIZATION.md) when **re-tiering** or **moving** docs.
