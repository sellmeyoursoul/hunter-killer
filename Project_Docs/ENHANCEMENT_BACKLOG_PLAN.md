# Enhancement backlog

Informal parking lot for improvements **not** committed in phase design docs. Priority is rough (**Low** / **Medium** / **High**).

**Doc paths:** Register and resolve locations in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) (canonical). When an enhancement is driven by active design work, the table row links the **`Draft_Features/*.md`** plan explicitly (see **Draft plan** column below).

---

## oLog (logging library)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| Structured fields (`key=value` or JSON fragments in messages) | Medium | — | Easier grep and tooling than prose-only lines |
| Rate limiting per callsite / subsystem | Medium | — | Complements ring eviction; caps repetitive spam |
| Child loggers / fixed subsystem prefix | Medium | — | e.g. `OLog.child("AI")` prepends tag without passing each time |
| Deterministic `user://` root for automated tests (CI / headless) | Medium | — | Stable paths under Godot test harness |
| Editor-only or `logging_params.enabled` gate for shipped builds | Medium | — | Optional once shipping matters |
| Mirror selected levels to remote sink (HTTP, file rotation) | Medium | — | Out of scope for current file-only design |

---

## AI integration (Hunter Killer)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Perception: cap mob list in prompt** | Medium | [Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md](Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md) | When many mobs are **near** the player, serializing **all** `MOB` lines grows tokens and noise. Consider a **max count** (keep **distance-sorted** nearest *K*, drop or aggregate the rest) with a deterministic rule — tune *K* and “near” radius after POC. |

---

## Environment & scripted motor (OBJECT follow-ups)

**Source:** Deferred `<<Comment>>` threads from [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2.5 / §10. Environment semantics: [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) §10. **Shipped motor avoidance:** [Completed_Features/MOB_AVOIDANCE_PLAN.md](Completed_Features/MOB_AVOIDANCE_PLAN.md) (indexed in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)).

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`env_detour_patience_ticks`** separate from **`awareness_memory_ticks`** | Medium | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | v1 reuses one knob for mob ghost history and env detour patience; split if coupled tuning hurts either subsystem (§10). |
| **Skill-based human HUD / tutor nudge** (safer probing, corridor use) | Low | — | OBJECT §8.2.5: interior env motor nudges are **ENGINE**-only for that phase; optional **human** assist stays a **separate** UX feature. |
| **Optional headless `can_enter` probes** (learn passibility without bump) | Low | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | OBJECT §8.2.5 comment — faster belief updates in tests or sim; not required for cardinal v1. |
| **Optional `env_threat_radius`** gate for mob-threat scoring | Low | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | OBJECT §8.2 v1 uses existing snapshot only; add only if tuning asks for an extra spatial gate (§10). |
| **Motivation traits ↔ interior motor** (`explorer_builder`, etc.) | Low | [Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md), [Draft_Features/CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md) | OBJECT §8.2.5 / CREATURE_EVOLUTION deferred coupling. |

---

## Death / game-over differentiation

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Distinct player defeat causes** | Medium | — | **Today:** mob contact and (per [HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md)) **starvation** may both call **`Main.game_over()`** with the same player-facing outcome. **Future:** separate messaging, sounds, analytics, and **`AiDriver`** hooks for **violence** (mob hit), **starvation**, **environment** (e.g. freezing, falling, drowning), etc. |
| **Per-cause tutorial / meta** | Low | — | Optional HUD copy or post-death screen keyed by defeat enum |

---

## Creature / foraging (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Predator / prey calorie intake** (predators gain calories from prey, not bushes-only) | High | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §3 | **Prerequisite** before treating predator memory/foraging as correct; ties to diet archetype table (§2). |
| **Movement-based calorie costs** (locomotion burns `current_calories` beyond time drain) | High | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §3, [Draft_Features/PLANTS_PLAN.md](Draft_Features/PLANTS_PLAN.md) | **Prerequisite** per CREATURE_MEMORY — tune via `creature_motor` / vitals; pairs with foraging tradeoffs. |
| **Food-source memory** (precise coords + egocentric 8-way) | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) | After §3 prerequisites unless phase note defers; `ai_driver.gd` / `game_config_merge.gd`. |

---

## Perception & awareness (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|-------|
| **Line of sight / occlusion** — solids reduce or block effective **awareness** (cone/radius) | Medium | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md), [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) | Future: ray or grid checks vs props/tiles; pairs with **memory** (last known) and **squeeze** / `fit_size` hiding (ENVIRONMENT property catalog). |

---

## Plants & ecology (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Long-term ecology** (seeding, species, non-POC regrowth) | Low | [Draft_Features/PLANT_ECOLOGY_PLAN.md](Draft_Features/PLANT_ECOLOGY_PLAN.md), [Draft_Features/PLANTS_PLAN.md](Draft_Features/PLANTS_PLAN.md) | Shipped hunger POC: [Completed_Features/HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md). |

---

## Other

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`res://` repo layout migration** | Medium | [Draft_Features/REPO_LAYOUT_PLAN.md](Draft_Features/REPO_LAYOUT_PLAN.md) | Systems vs **`assets/`**, optional **`systems/`** rename, **`scenes/app/`**, **`config/`**; aligns with [ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) §4 / §9; **do not apply** until draft questions resolved |
| **Stat → point pool math** | Low | [Draft_Features/SHARED_STATTOPOINT_PLAN.md](Draft_Features/SHARED_STATTOPOINT_PLAN.md) | Feeds [Draft_Features/CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md). |
| **World-model feature umbrella** | Low | [Draft_Features/VISION_WORLD_BUILDER_PLAN.md](Draft_Features/VISION_WORLD_BUILDER_PLAN.md) | Index of domain plans; archive table: [Completed_Features/EARLY_SPEC_DOC](Completed_Features/EARLY_SPEC_DOC) |
